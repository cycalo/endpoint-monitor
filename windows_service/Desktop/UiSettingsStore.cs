using System.Text.Json;

namespace EndpointMonitorService.Desktop;

public sealed class UiSettings
{
    public bool MinimizeToTray { get; set; } = true;
}

public static class UiSettingsStore
{
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        WriteIndented = true,
    };

    public static string SettingsPath =>
        Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "EndpointMonitor",
            "ui-settings.json");

    public static UiSettings Load()
    {
        try
        {
            var path = SettingsPath;
            if (!File.Exists(path))
                return new UiSettings();

            var json = File.ReadAllText(path);
            return JsonSerializer.Deserialize<UiSettings>(json, JsonOptions) ?? new UiSettings();
        }
        catch
        {
            return new UiSettings();
        }
    }

    public static void Save(UiSettings settings)
    {
        var path = SettingsPath;
        Directory.CreateDirectory(Path.GetDirectoryName(path)!);
        var json = JsonSerializer.Serialize(settings, JsonOptions);
        File.WriteAllText(path, json);
    }
}
