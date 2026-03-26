using System.Text.RegularExpressions;
using EndpointMonitorService.Models;
using Microsoft.Win32;

namespace EndpointMonitorService.Collectors;

public sealed class InstalledSoftwareCollector(ILogger<InstalledSoftwareCollector> logger)
{
    public Task<IReadOnlyList<InstalledSoftwareItem>> CollectAsync(CancellationToken cancellationToken)
    {
        var list = new List<InstalledSoftwareItem>();
        try
        {
            ReadUninstallKey(Registry.LocalMachine, @"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall", list);
            ReadUninstallKey(Registry.LocalMachine, @"SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall", list);
            ReadUninstallKey(Registry.CurrentUser, @"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall", list);
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "Registry uninstall enumeration failed");
        }

        return Task.FromResult<IReadOnlyList<InstalledSoftwareItem>>(list
            .OrderBy(x => x.Name)
            .ToList());
    }

    private static void ReadUninstallKey(RegistryKey root, string sub, List<InstalledSoftwareItem> list)
    {
        using var key = root.OpenSubKey(sub);
        if (key == null) return;
        foreach (var name in key.GetSubKeyNames())
        {
            using var app = key.OpenSubKey(name);
            if (app == null) continue;
            var disp = app.GetValue("DisplayName")?.ToString();
            if (string.IsNullOrWhiteSpace(disp)) continue;
            var ver = app.GetValue("DisplayVersion")?.ToString() ?? "";
            var vendor = app.GetValue("Publisher")?.ToString() ?? "";
            var rawDate = app.GetValue("InstallDate")?.ToString() ?? "";
            var installLocation = app.GetValue("InstallLocation")?.ToString() ?? "";
            var quiet = app.GetValue("QuietUninstallString")?.ToString() ?? "";
            var uninstall = app.GetValue("UninstallString")?.ToString() ?? "";
            var noRemove = app.GetValue("NoRemove");
            var noRemoveFlag = noRemove is int nr && nr != 0;
            var hasUninstall = !string.IsNullOrWhiteSpace(quiet) || !string.IsNullOrWhiteSpace(uninstall);
            var installSizeKb = ReadEstimatedSizeKb(app);

            list.Add(new InstalledSoftwareItem
            {
                Name = disp,
                Version = ver,
                Vendor = vendor,
                InstallDate = NormalizeInstallDate(rawDate),
                InstallLocation = installLocation,
                UninstallRegistrySubKey = name,
                InstallSizeKb = installSizeKb,
                CanUninstall = !noRemoveFlag && hasUninstall
            });
        }
    }

    private static int ReadEstimatedSizeKb(RegistryKey app)
    {
        var v = app.GetValue("EstimatedSize");
        if (v is int i) return Math.Max(0, i);
        if (v is long l) return (int)Math.Clamp(l, 0, int.MaxValue);
        return 0;
    }

    private static string NormalizeInstallDate(string raw)
    {
        if (Regex.IsMatch(raw, @"^\d{8}$") && DateTime.TryParseExact(raw, "yyyyMMdd", null, System.Globalization.DateTimeStyles.None, out var d))
            return d.ToString("yyyy-MM-dd");
        return raw;
    }
}
