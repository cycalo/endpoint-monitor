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
            .GroupBy(x => x.Name + x.Version)
            .Select(g => g.First())
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
            list.Add(new InstalledSoftwareItem
            {
                Name = disp,
                Version = ver,
                Vendor = vendor,
                InstallDate = NormalizeInstallDate(rawDate)
            });
        }
    }

    private static string NormalizeInstallDate(string raw)
    {
        if (Regex.IsMatch(raw, @"^\d{8}$") && DateTime.TryParseExact(raw, "yyyyMMdd", null, System.Globalization.DateTimeStyles.None, out var d))
            return d.ToString("yyyy-MM-dd");
        return raw;
    }
}
