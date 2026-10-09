namespace EndpointMonitorService.Desktop;

public enum DevicePlatform
{
    Unknown,
    Android,
    Ios,
    Windows,
}

/// <summary>Display helpers for the desktop console. No secrets; input is treated as untrusted text.</summary>
public static class ConsoleFormat
{
    public static string SafeInline(string? value, int maxLength = 128)
    {
        if (string.IsNullOrWhiteSpace(value) || maxLength <= 0)
            return "";

        var cleaned = new string(value.Where(c => !char.IsControl(c)).ToArray()).Trim();
        if (cleaned.Length == 0)
            return "";
        return cleaned.Length <= maxLength ? cleaned : cleaned[..maxLength];
    }

    public static string FormatAgentVersion(string? version)
    {
        var clean = SafeInline(version, 32);
        if (clean.Length == 0)
            return "Agent -";
        if (clean.StartsWith('v') || clean.StartsWith('V'))
            return "Agent " + clean;
        return "Agent v" + clean;
    }

    public static string FormatHostUptime(TimeSpan uptime)
    {
        if (uptime < TimeSpan.Zero)
            uptime = TimeSpan.Zero;

        if (uptime.TotalDays >= 1)
            return $"{(int)uptime.TotalDays}d {uptime.Hours}h {uptime.Minutes}m";
        if (uptime.TotalHours >= 1)
            return $"{(int)uptime.TotalHours}h {uptime.Minutes}m";
        return $"{(int)uptime.TotalMinutes}m";
    }

    public static DevicePlatform PlatformOf(string? deviceName)
    {
        var name = SafeInline(deviceName, 128);
        if (ContainsAny(name, "iphone", "ipad", "ios"))
            return DevicePlatform.Ios;
        if (ContainsAny(name, "android", "pixel", "samsung", "galaxy", "oneplus", "xiaomi", "huawei"))
            return DevicePlatform.Android;
        if (ContainsAny(name, "windows", "desktop"))
            return DevicePlatform.Windows;
        return DevicePlatform.Unknown;
    }

    public static string PlatformLabel(DevicePlatform platform) => platform switch
    {
        DevicePlatform.Android => "Android",
        DevicePlatform.Ios => "iOS",
        DevicePlatform.Windows => "Windows",
        _ => "Device",
    };

    public static bool IsLiveSession(string? deviceId, IEnumerable<string>? liveDeviceIds)
    {
        if (string.IsNullOrWhiteSpace(deviceId) || liveDeviceIds == null)
            return false;

        foreach (var id in liveDeviceIds)
        {
            if (string.Equals(id, deviceId, StringComparison.OrdinalIgnoreCase))
                return true;
        }

        return false;
    }

    private static bool ContainsAny(string haystack, params string[] needles)
    {
        foreach (var needle in needles)
        {
            if (haystack.Contains(needle, StringComparison.OrdinalIgnoreCase))
                return true;
        }

        return false;
    }
}
