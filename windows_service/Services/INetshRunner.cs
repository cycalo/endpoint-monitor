namespace EndpointMonitorService.Services;

public sealed record NetshResult(int ExitCode, string StdOut, string StdErr)
{
    public bool Success => ExitCode == 0;
}

public interface INetshRunner
{
    NetshResult Run(string arguments);
}
