using System.Runtime.InteropServices;

namespace EndpointMonitorService.Desktop;

/// <summary>Cheap host CPU and memory samples for the Home sparkline. Does not call the agent.</summary>
internal static class HostTelemetrySampler
{
    internal readonly record struct Sample(bool HasCpu, double CpuPercent, bool HasRam, double RamPercent);

    private static ulong _idle;
    private static ulong _kernel;
    private static ulong _user;
    private static bool _primed;

    internal static Sample Read()
    {
        var hasCpu = TryCpu(out var cpu);
        var hasRam = TryRam(out var ram);
        return new Sample(hasCpu, cpu, hasRam, ram);
    }

    private static bool TryCpu(out double percent)
    {
        percent = 0;
        try
        {
            if (!GetSystemTimes(out var idleFt, out var kernelFt, out var userFt))
                return false;

            var idle = ToU64(idleFt);
            var kernel = ToU64(kernelFt);
            var user = ToU64(userFt);
            if (!_primed)
            {
                _primed = true;
                _idle = idle;
                _kernel = kernel;
                _user = user;
                return false;
            }

            var idleDelta = idle - _idle;
            // Kernel time from GetSystemTimes includes idle time.
            var total = (kernel - _kernel) + (user - _user);
            _idle = idle;
            _kernel = kernel;
            _user = user;
            if (total == 0 || idleDelta > total)
                return false;

            percent = Math.Clamp((1.0 - (idleDelta / (double)total)) * 100.0, 0, 100);
            return true;
        }
        catch
        {
            return false;
        }
    }

    private static bool TryRam(out double percent)
    {
        percent = 0;
        try
        {
            var status = new MemoryStatusEx { dwLength = (uint)Marshal.SizeOf<MemoryStatusEx>() };
            if (!GlobalMemoryStatusEx(ref status))
                return false;
            percent = Math.Clamp(status.dwMemoryLoad, 0, 100);
            return true;
        }
        catch
        {
            return false;
        }
    }

    private static ulong ToU64(FileTime ft) => ((ulong)ft.dwHighDateTime << 32) | ft.dwLowDateTime;

    [StructLayout(LayoutKind.Sequential)]
    private struct FileTime
    {
        public uint dwLowDateTime;
        public uint dwHighDateTime;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct MemoryStatusEx
    {
        public uint dwLength;
        public uint dwMemoryLoad;
        public ulong ullTotalPhys;
        public ulong ullAvailPhys;
        public ulong ullTotalPageFile;
        public ulong ullAvailPageFile;
        public ulong ullTotalVirtual;
        public ulong ullAvailVirtual;
        public ulong ullAvailExtendedVirtual;
    }

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool GetSystemTimes(out FileTime idle, out FileTime kernel, out FileTime user);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool GlobalMemoryStatusEx(ref MemoryStatusEx buffer);
}
