using System.Diagnostics;

namespace EndpointMonitorService.Collectors;

/// <summary>
/// Sums bytes/sec from Windows "Network Interface" performance counters (non-loopback / tunnel instances).
/// </summary>
public sealed class NetworkThroughputCollector(ILogger<NetworkThroughputCollector> logger)
{
    private readonly List<PerformanceCounter> _sent = [];
    private readonly List<PerformanceCounter> _recv = [];

    private void EnsureCounters()
    {
        if (_sent.Count > 0) return;

        try
        {
            var cat = new PerformanceCounterCategory("Network Interface");
            foreach (var name in cat.GetInstanceNames())
            {
                if (!ShouldIncludeInstance(name)) continue;
                try
                {
                    var s = new PerformanceCounter("Network Interface", "Bytes Sent/sec", name, true);
                    var r = new PerformanceCounter("Network Interface", "Bytes Received/sec", name, true);
                    s.NextValue();
                    r.NextValue();
                    _sent.Add(s);
                    _recv.Add(r);
                }
                catch (Exception ex)
                {
                    logger.LogDebug(ex, "Failed to create network perf counters for {Instance}", name);
                }
            }
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "Network Interface performance counters unavailable");
        }
    }

    private static bool ShouldIncludeInstance(string name)
    {
        if (string.IsNullOrWhiteSpace(name)) return false;
        if (name.Contains("Loopback", StringComparison.OrdinalIgnoreCase)) return false;
        if (name.Contains("isatap", StringComparison.OrdinalIgnoreCase)) return false;
        if (name.Contains("Teredo", StringComparison.OrdinalIgnoreCase)) return false;
        if (name.Contains("6to4", StringComparison.OrdinalIgnoreCase)) return false;
        return true;
    }

    public void Sample(out double bytesSentPerSec, out double bytesReceivedPerSec)
    {
        EnsureCounters();
        bytesSentPerSec = 0;
        bytesReceivedPerSec = 0;

        for (var i = 0; i < _sent.Count; i++)
        {
            try
            {
                bytesSentPerSec += _sent[i].NextValue();
                bytesReceivedPerSec += _recv[i].NextValue();
            }
            catch (Exception ex)
            {
                logger.LogDebug(ex, "Network counter sample failed at index {Index}", i);
            }
        }
    }
}
