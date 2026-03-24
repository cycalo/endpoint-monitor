namespace EndpointMonitorService.Models;

public sealed class ProcessInfo
{
    public int Pid { get; set; }
    public string Name { get; set; } = "";
    public string CommandLine { get; set; } = "";
    public int ParentPid { get; set; }
    public double CpuPercent { get; set; }
    public double MemoryMb { get; set; }
    public string StartTime { get; set; } = "";
    public string Status { get; set; } = "";
}
