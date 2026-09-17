using EndpointMonitorService.Database;
using EndpointMonitorService.Options;
using Microsoft.Extensions.Options;

namespace EndpointMonitorService.Services;

public sealed class FirewallIsolationService(
    ILogger<FirewallIsolationService> logger,
    INetshRunner netsh,
    AppDatabase database,
    IOptions<ServerOptions> serverOptions,
    WebSocketConnectionManager webSockets,
    TimeSpan? watchdogDelay = null)
{
    public static readonly TimeSpan WatchdogDelay = TimeSpan.FromSeconds(90);

    private readonly TimeSpan _watchdogDelay = watchdogDelay ?? WatchdogDelay;

    private readonly object _watchdogLock = new();
    private CancellationTokenSource? _watchdogCts;

    public async Task<IsolationOperationResult> IsolateAsync(
        string? clientIp,
        CancellationToken cancellationToken = default)
    {
        var exe = FirewallIsolationHelper.ResolveServiceExecutablePath();
        if (string.IsNullOrWhiteSpace(exe))
        {
            logger.LogWarning("Isolation refused: service executable path unavailable (dotnet dev host?)");
            return IsolationOperationResult.Fail("executable_unavailable");
        }

        var ports = FirewallIsolationHelper.FormatLocalPorts(serverOptions.Value);
        var escaped = FirewallIsolationHelper.EscapeProgramPath(exe);
        var existing = await database.GetIsolationStateAsync(cancellationToken).ConfigureAwait(false);
        var savedPolicies = new Dictionary<FirewallProfileKind, FirewallProfilePolicy>();

        try
        {
            DeleteLegacyRules();

            if (existing?.IsIsolated != true)
            {
                foreach (var profile in Enum.GetValues<FirewallProfileKind>())
                {
                    var current = ReadProfilePolicy(profile);
                    if (current == null)
                        return await RollbackAndFailAsync(savedPolicies, "read_policy_failed", cancellationToken)
                            .ConfigureAwait(false);
                    savedPolicies[profile] = current;
                }

                await database.SaveIsolationPoliciesAsync(
                    savedPolicies[FirewallProfileKind.Domain].ToNetshArgument(),
                    savedPolicies[FirewallProfileKind.Private].ToNetshArgument(),
                    savedPolicies[FirewallProfileKind.Public].ToNetshArgument(),
                    cancellationToken).ConfigureAwait(false);
            }

            if (!AddAllowRule(FirewallIsolationHelper.AllowInRule, "in", escaped, ports))
                return await RollbackAndFailAsync(savedPolicies, "allow_in_failed", cancellationToken)
                    .ConfigureAwait(false);

            if (!AddAllowRule(FirewallIsolationHelper.AllowOutRule, "out", escaped, ports))
                return await RollbackAndFailAsync(savedPolicies, "allow_out_failed", cancellationToken)
                    .ConfigureAwait(false);

            if (!VerifyAllowRulesExist())
                return await RollbackAndFailAsync(savedPolicies, "allow_verify_failed", cancellationToken)
                    .ConfigureAwait(false);

            var setAll = netsh.Run(
                "advfirewall set allprofiles firewallpolicy blockinbound,blockoutbound");
            if (!setAll.Success)
                return await RollbackAndFailAsync(savedPolicies, "set_policy_failed", cancellationToken)
                    .ConfigureAwait(false);

            if (!await IsLiveIsolatedAsync(cancellationToken).ConfigureAwait(false))
                return await RollbackAndFailAsync(savedPolicies, "policy_verify_failed", cancellationToken)
                    .ConfigureAwait(false);

            await database.SetIsolationAsync(true, cancellationToken).ConfigureAwait(false);
            await database.AppendAuditAsync("isolate_machine", "on", clientIp, cancellationToken)
                .ConfigureAwait(false);
            ArmWatchdog();
            logger.LogInformation("Machine isolated with default-policy containment");
            return IsolationOperationResult.Ok();
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "Isolation failed unexpectedly");
            return await RollbackAndFailAsync(savedPolicies, "unexpected_error", cancellationToken)
                .ConfigureAwait(false);
        }
    }

    public async Task<IsolationOperationResult> UnisolateAsync(
        string? clientIp,
        string reason,
        CancellationToken cancellationToken = default)
    {
        CancelWatchdog();
        try
        {
            await RestoreSavedPoliciesAsync(cancellationToken).ConfigureAwait(false);
            DeleteAllIsolationRules();
            await database.SetIsolationAsync(false, cancellationToken).ConfigureAwait(false);
            await database.ClearIsolationPoliciesAsync(cancellationToken).ConfigureAwait(false);
            await database.AppendAuditAsync(
                    "unisolate_machine",
                    reason,
                    clientIp,
                    cancellationToken)
                .ConfigureAwait(false);
            logger.LogInformation("Machine unisolated ({Reason})", reason);
            return IsolationOperationResult.Ok();
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "Unisolate failed");
            return IsolationOperationResult.Fail("unisolate_failed");
        }
    }

    public async Task<bool> IsLiveIsolatedAsync(CancellationToken cancellationToken = default)
    {
        _ = cancellationToken;
        foreach (var profile in Enum.GetValues<FirewallProfileKind>())
        {
            var policy = ReadProfilePolicy(profile);
            if (policy == null || !FirewallIsolationHelper.IsBlockBlockPolicy(policy))
                return false;
        }

        return VerifyAllowRulesExist();
    }

    public async Task ReconcileAsync(CancellationToken cancellationToken = default)
    {
        var live = await IsLiveIsolatedAsync(cancellationToken).ConfigureAwait(false);
        var db = await database.GetIsolationStateAsync(cancellationToken).ConfigureAwait(false);
        var dbIsolated = db?.IsIsolated ?? false;

        if (live && !dbIsolated)
        {
            await database.SetIsolationAsync(true, cancellationToken).ConfigureAwait(false);
            logger.LogWarning("Reconciled isolation state: live firewall isolated, DB was false");
            ArmWatchdog();
        }
        else if (!live && dbIsolated)
        {
            await database.SetIsolationAsync(false, cancellationToken).ConfigureAwait(false);
            await database.ClearIsolationPoliciesAsync(cancellationToken).ConfigureAwait(false);
            CancelWatchdog();
            logger.LogWarning("Reconciled isolation state: DB was isolated, live firewall is not");
        }
        else if (live && dbIsolated)
        {
            ArmWatchdog();
        }
    }

    public void ArmWatchdog()
    {
        lock (_watchdogLock)
        {
            _watchdogCts?.Cancel();
            _watchdogCts?.Dispose();
            _watchdogCts = new CancellationTokenSource();
            var token = _watchdogCts.Token;
            _ = RunWatchdogAsync(token);
        }
    }

    public void CancelWatchdog()
    {
        lock (_watchdogLock)
        {
            _watchdogCts?.Cancel();
            _watchdogCts?.Dispose();
            _watchdogCts = null;
        }
    }

    private async Task RunWatchdogAsync(CancellationToken token)
    {
        try
        {
            await Task.Delay(_watchdogDelay, token).ConfigureAwait(false);
        }
        catch (OperationCanceledException)
        {
            return;
        }

        if (token.IsCancellationRequested)
            return;

        if (webSockets.ClientCount > 0)
        {
            logger.LogInformation("Isolation watchdog: authenticated client still connected");
            return;
        }

        logger.LogWarning(
            "Isolation watchdog: no authenticated WebSocket clients after {Seconds}s — auto-unisolating",
            _watchdogDelay.TotalSeconds);
        await UnisolateAsync(null, "watchdog", CancellationToken.None).ConfigureAwait(false);
    }

    private async Task RestoreSavedPoliciesAsync(CancellationToken cancellationToken)
    {
        var row = await database.GetIsolationStateAsync(cancellationToken).ConfigureAwait(false);
        var domain = ParseSavedPolicy(row?.SavedDomainPolicy) ??
                     new FirewallProfilePolicy("BlockInbound", "AllowOutbound");
        var priv = ParseSavedPolicy(row?.SavedPrivatePolicy) ?? domain;
        var pub = ParseSavedPolicy(row?.SavedPublicPolicy) ?? domain;

        SetProfilePolicy(FirewallProfileKind.Domain, domain);
        SetProfilePolicy(FirewallProfileKind.Private, priv);
        SetProfilePolicy(FirewallProfileKind.Public, pub);
    }

    private static FirewallProfilePolicy? ParseSavedPolicy(string? saved)
    {
        if (string.IsNullOrWhiteSpace(saved))
            return null;
        var parts = saved.Split(',', 2, StringSplitOptions.TrimEntries);
        if (parts.Length != 2)
            return null;
        return new FirewallProfilePolicy(parts[0], parts[1]);
    }

    private FirewallProfilePolicy? ReadProfilePolicy(FirewallProfileKind profile)
    {
        var name = FirewallIsolationHelper.ProfileNetshName(profile);
        var result = netsh.Run($"advfirewall show {name}");
        if (!result.Success)
            return null;
        if (!FirewallIsolationHelper.TryParsePolicyLine(result.StdOut, out var inbound, out var outbound))
            return null;
        return new FirewallProfilePolicy(inbound, outbound);
    }

    private void SetProfilePolicy(FirewallProfileKind profile, FirewallProfilePolicy policy)
    {
        var name = FirewallIsolationHelper.ProfileNetshName(profile);
        netsh.Run($"advfirewall set {name} firewallpolicy {policy.ToNetshArgument()}");
    }

    private bool AddAllowRule(string ruleName, string direction, string escapedProgram, string ports)
    {
        DeleteRule(ruleName);
        var result = netsh.Run(
            $"advfirewall firewall add rule name=\"{ruleName}\" dir={direction} action=allow protocol=TCP localport={ports} program=\"{escapedProgram}\"");
        return result.Success;
    }

    private bool VerifyAllowRulesExist()
    {
        var inResult = netsh.Run($"advfirewall firewall show rule name=\"{FirewallIsolationHelper.AllowInRule}\"");
        var outResult = netsh.Run($"advfirewall firewall show rule name=\"{FirewallIsolationHelper.AllowOutRule}\"");
        return inResult.Success &&
               outResult.Success &&
               FirewallIsolationHelper.RuleOutputContainsName(inResult.StdOut, FirewallIsolationHelper.AllowInRule) &&
               FirewallIsolationHelper.RuleOutputContainsName(outResult.StdOut, FirewallIsolationHelper.AllowOutRule);
    }

    private void DeleteAllIsolationRules()
    {
        DeleteRule(FirewallIsolationHelper.AllowInRule);
        DeleteRule(FirewallIsolationHelper.AllowOutRule);
        DeleteLegacyRules();
    }

    private void DeleteLegacyRules()
    {
        foreach (var name in FirewallIsolationHelper.LegacyRuleNames)
            DeleteRule(name);
    }

    private void DeleteRule(string ruleName)
    {
        netsh.Run($"advfirewall firewall delete rule name=\"{ruleName}\"");
    }

    private async Task<IsolationOperationResult> RollbackAndFailAsync(
        Dictionary<FirewallProfileKind, FirewallProfilePolicy> savedPolicies,
        string code,
        CancellationToken cancellationToken)
    {
        logger.LogWarning("Isolation rollback due to {Code}", code);
        try
        {
            foreach (var (profile, policy) in savedPolicies)
                SetProfilePolicy(profile, policy);
            DeleteAllIsolationRules();
            await database.SetIsolationAsync(false, cancellationToken).ConfigureAwait(false);
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Isolation rollback itself failed");
        }

        return IsolationOperationResult.Fail(code);
    }
}

public sealed record IsolationOperationResult(bool Success, string Code)
{
    public static IsolationOperationResult Ok() => new(true, "ok");
    public static IsolationOperationResult Fail(string code) => new(false, code);
}
