using System.Diagnostics;

namespace EndpointMonitorService.Desktop.Pages;

public partial class DiagnosticsPage : UserControl
{
    private readonly AgentDataService _data;
    private TextBlock _body = null!;

    public DiagnosticsPage(AgentDataService data)
    {
        _data = data;
        BuildUi();
    }

    private void BuildUi()
    {
        var root = new StackPanel();
        root.Children.Add(new TextBlock { Text = "Diagnostics", Style = (Style)Application.Current.FindResource("CsPageTitle") });

        var card = new Border { Style = (Style)Application.Current.FindResource("CsCard") };
        _body = new TextBlock
        {
            Style = (Style)Application.Current.FindResource("CsBody"),
            FontFamily = new System.Windows.Media.FontFamily("Consolas"),
            FontSize = 12.5,
            LineHeight = 22,
        };
        card.Child = _body;

        var openFolder = new Button
        {
            Content = "Open data folder",
            Style = (Style)Application.Current.FindResource("CsSecondaryButton"),
            Margin = new Thickness(0, 12, 0, 0),
            HorizontalAlignment = HorizontalAlignment.Left,
        };
        openFolder.Click += (_, _) => OpenDataFolder();

        root.Children.Add(card);
        root.Children.Add(openFolder);
        Content = root;
    }

    public async Task RefreshAsync()
    {
        var status = await _data.GetStatusAsync().ConfigureAwait(true);
        if (status == null)
        {
            _body.Text = "Could not reach the agent.";
            return;
        }

        var intel = status.ThreatIntelEnabled
            ? $"enabled · {status.ThreatIntelEntryCount} entries · last run {status.ThreatIntelLastRunUtc ?? "never"}"
            : "disabled";
        if (!string.IsNullOrEmpty(status.ThreatIntelLastError) && status.ThreatIntelLastError != "disabled")
            intel += $"\nLast error: {status.ThreatIntelLastError}";

        var https = status.UseHttps ? status.HttpsPort.ToString() : "off";
        _body.Text =
            $"Version: {status.Version}\n" +
            $"Data folder: {status.DataDirectory}\n" +
            $"HTTP port: {status.HttpPort}\n" +
            $"HTTPS: {https}\n" +
            $"WebSocket clients: {status.WebSocketClients}\n" +
            $"Sysmon: {(status.SysmonInstalled ? "installed" : "not detected")}\n" +
            $"Threat intel: {intel}\n" +
            $"Administrator: {(status.RunningAsAdministrator ? "yes" : "no")}\n" +
            $"Interactive session: {(status.InteractiveSession ? "yes" : "no")}";
    }

    private static void OpenDataFolder()
    {
        try
        {
            var logDir = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "EndpointMonitor");
            Directory.CreateDirectory(logDir);
            Process.Start(new ProcessStartInfo
            {
                FileName = logDir,
                UseShellExecute = true,
            });
        }
        catch
        {
            MessageBox.Show("Could not open the data folder.", "Endpoint Monitor",
                MessageBoxButton.OK, MessageBoxImage.Warning);
        }
    }
}
