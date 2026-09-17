using System.Diagnostics;

namespace EndpointMonitorService.Services;

public sealed class NetshRunner(ILogger<NetshRunner> logger) : INetshRunner
{
    public NetshResult Run(string arguments)
    {
        try
        {
            using var p = Process.Start(new ProcessStartInfo("netsh", arguments)
            {
                UseShellExecute = false,
                CreateNoWindow = true,
                RedirectStandardError = true,
                RedirectStandardOutput = true,
            });
            if (p == null)
                return new NetshResult(-1, "", "Process start failed");

            var stdout = p.StandardOutput.ReadToEnd();
            var stderr = p.StandardError.ReadToEnd();
            if (!p.WaitForExit(30_000))
            {
                try { p.Kill(entireProcessTree: true); } catch { /* best effort */ }
                logger.LogWarning("netsh timed out: {Args}", arguments);
                return new NetshResult(-1, stdout, "Timed out after 30 seconds");
            }

            if (p.ExitCode != 0)
                logger.LogWarning("netsh exit {Code} for {Args}: {Err}", p.ExitCode, arguments, stderr);

            return new NetshResult(p.ExitCode, stdout, stderr);
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "netsh failed: {Args}", arguments);
            return new NetshResult(-1, "", ex.Message);
        }
    }
}
