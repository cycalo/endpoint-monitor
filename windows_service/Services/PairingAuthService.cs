using System.Collections.Concurrent;
using System.Security.Cryptography;
using System.Text;
using EndpointMonitorService.Database;
using EndpointMonitorService.Options;
using Microsoft.Extensions.Options;

namespace EndpointMonitorService.Services;

public sealed class PairingAuthService(AppDatabase db, IOptions<AuthOptions> options)
{
    private sealed record PairingCodeState(string Code, DateTime ExpiresAtUtc, bool Consumed);

    private readonly ConcurrentDictionary<string, PairingCodeState> _activeCodes = new(StringComparer.Ordinal);
    private readonly AuthOptions _authOptions = options.Value;

    public (string Code, DateTime ExpiresAtUtc) CreatePairingCode(TimeSpan? ttl = null)
    {
        var pepperErr = PepperValidationError();
        if (pepperErr != null)
            throw new InvalidOperationException(pepperErr);

        var now = DateTime.UtcNow;
        var expiry = now.Add(ttl ?? TimeSpan.FromMinutes(5));
        var code = RandomNumberGenerator.GetInt32(0, 1_000_000).ToString("D6");
        _activeCodes[code] = new PairingCodeState(code, expiry, false);
        CleanupExpiredCodes(now);
        return (code, expiry);
    }

    public async Task<(bool Success, string? DeviceToken, string ErrorCode)> ExchangePairingCodeAsync(
        string code,
        string? deviceName,
        CancellationToken cancellationToken = default)
    {
        var pepperErr = PepperValidationError();
        if (pepperErr != null)
            return (false, null, "pepper_invalid");

        var trimmedCode = code.Trim();
        if (!_activeCodes.TryGetValue(trimmedCode, out var state))
            return (false, null, "pairing_code_not_found");

        if (state.Consumed)
            return (false, null, "pairing_code_used");

        if (state.ExpiresAtUtc <= DateTime.UtcNow)
        {
            _activeCodes.TryRemove(trimmedCode, out _);
            return (false, null, "pairing_code_expired");
        }

        _activeCodes[trimmedCode] = state with { Consumed = true };

        var token = GenerateDeviceToken();
        var tokenHash = HashToken(token);
        var id = Guid.NewGuid().ToString("N");
        var now = DateTime.UtcNow.ToString("O");
        await db.AddDeviceTokenAsync(new DeviceAuthTokenRow
        {
            Id = id,
            DeviceName = string.IsNullOrWhiteSpace(deviceName) ? "Unknown device" : deviceName.Trim(),
            TokenHash = tokenHash,
            CreatedAt = now,
            LastUsedAt = now,
            Revoked = false
        }, cancellationToken).ConfigureAwait(false);

        _activeCodes.TryRemove(trimmedCode, out _);
        return (true, token, "");
    }

    public async Task<bool> ValidateDeviceTokenAsync(string token, CancellationToken cancellationToken = default)
    {
        var hash = HashToken(token);
        var row = await db.FindActiveDeviceTokenByHashAsync(hash, cancellationToken).ConfigureAwait(false);
        if (row == null) return false;
        await db.TouchDeviceTokenAsync(row.Id, cancellationToken).ConfigureAwait(false);
        return true;
    }

    public async Task<IReadOnlyList<DeviceAuthTokenRow>> ListDeviceTokensAsync(CancellationToken cancellationToken = default)
    {
        return await db.ListDeviceTokensAsync(cancellationToken).ConfigureAwait(false);
    }

    public async Task RevokeDeviceTokenAsync(string id, CancellationToken cancellationToken = default)
    {
        await db.RevokeDeviceTokenAsync(id, cancellationToken).ConfigureAwait(false);
    }

    private static string GenerateDeviceToken()
    {
        Span<byte> bytes = stackalloc byte[32];
        RandomNumberGenerator.Fill(bytes);
        return Convert.ToHexString(bytes);
    }

    private string HashToken(string token)
    {
        var pepper = _authOptions.ResolvePepper();
        using var sha = SHA256.Create();
        var data = Encoding.UTF8.GetBytes($"{pepper}:{token}");
        var hash = sha.ComputeHash(data);
        return Convert.ToHexString(hash);
    }

    private string? PepperValidationError()
    {
        var p = _authOptions.ResolvePepper();
        if (string.IsNullOrWhiteSpace(p))
            return "DeviceTokenPepper (or legacy JwtSigningKey) must be set in configuration.";
        if (p.Length < 32)
            return "DeviceTokenPepper must be at least 32 characters.";
        return null;
    }

    private void CleanupExpiredCodes(DateTime nowUtc)
    {
        foreach (var kvp in _activeCodes)
        {
            if (kvp.Value.ExpiresAtUtc <= nowUtc || kvp.Value.Consumed)
                _activeCodes.TryRemove(kvp.Key, out _);
        }
    }
}
