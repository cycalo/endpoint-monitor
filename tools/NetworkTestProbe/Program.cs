using System.Diagnostics;
using System.Net;
using System.Net.Http;
using System.Net.Sockets;

// NetworkTestProbe — manual testing helper (network UI, Sysmon, firewall rules).

var argsList = args.ToList();

var useHttpPooling = TakeFlag(argsList, "--http-pooling");

/// One process, one outbound TCP target per cycle — no HTTPS/DNS/listener noise.
/// Requires --tcp-host and --tcp-port. Use a literal IPv4/IPv6 so the firewall rule matches exactly.
var simpleBlockTest = TakeFlag(argsList, "--simple-block-test");

var httpsUrl = GetArg(argsList, "--https-url") ?? "https://example.com/";
var dnsHost = GetArg(argsList, "--dns-host") ?? "example.com";
var tcpHost = GetArg(argsList, "--tcp-host");
var tcpPortStr = GetArg(argsList, "--tcp-port");
int? tcpPort = int.TryParse(tcpPortStr, out var tp) ? tp : null;

var connectTimeout = TimeSpan.FromSeconds(
    Math.Clamp(int.TryParse(GetArg(argsList, "--connect-timeout-seconds"), out var connectSec) ? connectSec : 8, 1, 120));
var interval = TimeSpan.FromSeconds(
    Math.Clamp(int.TryParse(GetArg(argsList, "--interval-seconds"), out var iv) ? iv : 5, 1, 3600));

if (simpleBlockTest)
{
    if (tcpHost is null || tcpPort is null)
    {
        Console.Error.WriteLine("--simple-block-test requires --tcp-host and --tcp-port (e.g. --tcp-host 203.0.113.50 --tcp-port 443).");
        Environment.Exit(2);
    }
}
else if (tcpHost is not null && tcpPort is null)
{
    Console.Error.WriteLine("If --tcp-host is set, --tcp-port is required.");
    Environment.Exit(2);
}

using var cts = new CancellationTokenSource();
Console.CancelKeyPress += (_, e) =>
{
    e.Cancel = true;
    cts.Cancel();
};

var pid = Environment.ProcessId;
var processName = Process.GetCurrentProcess().ProcessName;

Console.WriteLine("NetworkTestProbe");
Console.WriteLine($"  PID: {pid}");
Console.WriteLine($"  Process name: {processName}");
Console.WriteLine();

if (simpleBlockTest)
{
    var literal = IPAddress.TryParse(tcpHost!, out _);
    Console.WriteLine("══════════════════════════════════════════════════════════════");
    Console.WriteLine("  SIMPLE BLOCK TEST  —  one process, one TCP target");
    Console.WriteLine("══════════════════════════════════════════════════════════════");
    Console.WriteLine($"  Each cycle: new TCP connect to {tcpHost}:{tcpPort} (no HTTPS/DNS, no local listener).");
    Console.WriteLine($"  In Endpoint Monitor → Network: find this PID, open the row with remote {tcpHost}:{tcpPort},");
    Console.WriteLine("  Block IP — that rule must use the same remote IP.");
    if (!literal)
        Console.WriteLine("  Note: --tcp-host is not a literal IP; use IPv4/IPv6 text for a 1:1 match with the rule.");
    Console.WriteLine("══════════════════════════════════════════════════════════════");
    Console.WriteLine();
}
else
{
    Console.WriteLine("Targets (align your firewall / block rule with these):");
    Console.WriteLine($"  HTTPS: {httpsUrl}");
    Console.WriteLine($"  DNS:   {dnsHost}");
    if (tcpHost is not null && tcpPort is not null)
        Console.WriteLine($"  TCP:   {tcpHost}:{tcpPort}");
    Console.WriteLine($"  Connect timeout: {connectTimeout.TotalSeconds}s");
    Console.WriteLine();
    Console.WriteLine(
        useHttpPooling
            ? "  HTTPS: connection pooling ON (--http-pooling) — can mask outbound IP blocks"
            : "  HTTPS: connection pooling OFF (default) — each cycle uses a new connection (accurate block tests)");
    Console.WriteLine();
    Console.WriteLine("Interpreting results from this process only:");
    Console.WriteLine("  • OK = outbound reached the remote for that probe.");
    Console.WriteLine("  • NOT_REACHABLE = TCP/HTTP could not complete (timeout/refused/etc.).");
    Console.WriteLine("    If you see OK before adding a block rule and NOT_REACHABLE after,");
    Console.WriteLine("    the rule is very likely blocking this process's traffic to that target.");
    Console.WriteLine();
}

Console.WriteLine($"Loop every {interval.TotalSeconds}s until Ctrl+C.");
Console.WriteLine();

TcpListener? listener = null;
if (!simpleBlockTest)
{
    listener = new TcpListener(IPAddress.Loopback, 0);
    listener.Start();
    var listenPort = ((IPEndPoint)listener.LocalEndpoint).Port;
    Console.WriteLine($"Local TCP LISTEN 127.0.0.1:{listenPort} (unaffected by remote block rules)");
    Console.WriteLine();
}

HttpClient? http = null;
if (!simpleBlockTest)
{
    var handler = new SocketsHttpHandler
    {
        ConnectTimeout = connectTimeout,
        PooledConnectionLifetime = useHttpPooling ? TimeSpan.FromMinutes(2) : TimeSpan.Zero,
        PooledConnectionIdleTimeout = useHttpPooling ? TimeSpan.FromMinutes(2) : TimeSpan.Zero,
    };
    http = new HttpClient(handler)
    {
        Timeout = connectTimeout + TimeSpan.FromSeconds(30),
    };
}

try
{
    while (!cts.Token.IsCancellationRequested)
    {
        var cycleSw = Stopwatch.StartNew();
        Console.WriteLine($"--- {DateTime.Now:HH:mm:ss} ---");

        if (simpleBlockTest)
        {
            var tcpOutcome = await ProbeTcpAsync(tcpHost!, tcpPort!.Value, connectTimeout, cts.Token);
            LogOutcome("TCP", $"{tcpHost}:{tcpPort}", tcpOutcome);
        }
        else
        {
            var httpsOutcome = await ProbeHttpsAsync(http!, httpsUrl, connectTimeout, cts.Token);
            LogOutcome("HTTPS", httpsUrl, httpsOutcome);

            if (tcpHost is not null && tcpPort is not null)
            {
                var tcpOutcome = await ProbeTcpAsync(tcpHost, tcpPort.Value, connectTimeout, cts.Token);
                LogOutcome("TCP", $"{tcpHost}:{tcpPort}", tcpOutcome);
            }

            var dnsOutcome = await ProbeDnsAsync(dnsHost, cts.Token);
            LogOutcome("DNS", dnsHost, dnsOutcome);
        }

        cycleSw.Stop();
        Console.WriteLine($"Cycle time: {cycleSw.ElapsedMilliseconds} ms");
        Console.WriteLine();

        await Task.Delay(interval, cts.Token);
    }
}
catch (OperationCanceledException)
{
    // shutdown
}
finally
{
    http?.Dispose();
    try
    {
        listener?.Stop();
    }
    catch
    {
        // ignore
    }
}

Console.WriteLine("Exited.");

// --- helpers ---

static void LogOutcome(string kind, string target, ProbeOutcome o)
{
    var tag = o.Reachability switch
    {
        Reachability.Ok => "OK",
        Reachability.NotReachable => "NOT_REACHABLE",
        Reachability.DnsFailed => "DNS_FAILED",
        _ => "?",
    };
    Console.WriteLine($"  [{kind}] {tag,-16} {target}");
    if (!string.IsNullOrEmpty(o.Detail))
        Console.WriteLine($"           {o.Detail}");
}

static async Task<ProbeOutcome> ProbeHttpsAsync(HttpClient http, string url, TimeSpan connectTimeout, CancellationToken ct)
{
    try
    {
        using var req = new HttpRequestMessage(HttpMethod.Get, url);
        var sw = Stopwatch.StartNew();
        using var resp = await http.SendAsync(req, HttpCompletionOption.ResponseHeadersRead, ct);
        sw.Stop();
        var ok = resp.IsSuccessStatusCode;
        return new ProbeOutcome(
            ok ? Reachability.Ok : Reachability.NotReachable,
            ok
                ? $"HTTP {(int)resp.StatusCode} ({sw.ElapsedMilliseconds} ms)"
                : $"HTTP {(int)resp.StatusCode} {resp.ReasonPhrase}");
    }
    catch (Exception ex) when (ex is not OperationCanceledException)
    {
        return new ProbeOutcome(Reachability.NotReachable, ClassifyRemoteFailure(ex, connectTimeout));
    }
}

static async Task<ProbeOutcome> ProbeTcpAsync(string host, int port, TimeSpan connectTimeout, CancellationToken ct)
{
    try
    {
        using var tcp = new TcpClient();
        using var linked = CancellationTokenSource.CreateLinkedTokenSource(ct);
        linked.CancelAfter(connectTimeout);
        var sw = Stopwatch.StartNew();
        await tcp.ConnectAsync(host, port, linked.Token).ConfigureAwait(false);
        sw.Stop();
        return new ProbeOutcome(Reachability.Ok, $"connected ({sw.ElapsedMilliseconds} ms)");
    }
    catch (Exception ex) when (ex is not OperationCanceledException)
    {
        return new ProbeOutcome(Reachability.NotReachable, ClassifyRemoteFailure(ex, connectTimeout));
    }
}

static async Task<ProbeOutcome> ProbeDnsAsync(string host, CancellationToken ct)
{
    try
    {
        var addrs = await Dns.GetHostAddressesAsync(host, ct).ConfigureAwait(false);
        if (addrs.Length == 0)
            return new ProbeOutcome(Reachability.DnsFailed, "no addresses returned");
        var first = addrs[0];
        return new ProbeOutcome(Reachability.Ok, $"→ {first}");
    }
    catch (Exception ex) when (ex is not OperationCanceledException)
    {
        return new ProbeOutcome(Reachability.DnsFailed, ex.Message);
    }
}

static string ClassifyRemoteFailure(Exception ex, TimeSpan connectTimeout)
{
    if (ex is TaskCanceledException)
        return $"timed out (>{connectTimeout.TotalSeconds}s) — common when a rule drops packets";

    for (var e = ex; e != null; e = e.InnerException)
    {
        if (e is SocketException se)
        {
            return se.SocketErrorCode switch
            {
                SocketError.TimedOut =>
                    $"socket {se.SocketErrorCode} — timed out (often block/filter on path)",
                SocketError.ConnectionRefused =>
                    $"socket {se.SocketErrorCode} — refused (port closed or explicit RST, not typical silent block)",
                SocketError.HostUnreachable or SocketError.NetworkUnreachable =>
                    $"socket {se.SocketErrorCode} — no route / host unreachable",
                _ => $"socket {se.SocketErrorCode}: {se.Message}",
            };
        }

        if (e is HttpRequestException hre)
            return $"HTTP layer: {hre.Message}";
    }

    return ex.Message;
}

static bool TakeFlag(List<string> list, string name)
{
    var i = list.IndexOf(name);
    if (i < 0) return false;
    list.RemoveAt(i);
    return true;
}

static string? GetArg(List<string> list, string name)
{
    var i = list.IndexOf(name);
    if (i < 0 || i + 1 >= list.Count)
        return null;
    return list[i + 1];
}

enum Reachability
{
    Ok,
    NotReachable,
    DnsFailed,
}

readonly record struct ProbeOutcome(Reachability Reachability, string Detail);
