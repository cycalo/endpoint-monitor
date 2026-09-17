using EndpointMonitorService.Desktop;

namespace EndpointMonitorService.Tests;

public sealed class UiSettingsStoreTests
{
    [Fact]
    public void Load_returns_defaults_when_missing()
    {
        var settings = UiSettingsStore.Load();
        Assert.True(settings.MinimizeToTray);
    }

    [Fact]
    public void Save_round_trips_minimize_to_tray()
    {
        var path = UiSettingsStore.SettingsPath;
        var backup = File.Exists(path) ? File.ReadAllText(path) : null;
        try
        {
            var settings = new UiSettings { MinimizeToTray = false };
            UiSettingsStore.Save(settings);
            var loaded = UiSettingsStore.Load();
            Assert.False(loaded.MinimizeToTray);
        }
        finally
        {
            if (backup == null)
                File.Delete(path);
            else
                File.WriteAllText(path, backup);
        }
    }
}
