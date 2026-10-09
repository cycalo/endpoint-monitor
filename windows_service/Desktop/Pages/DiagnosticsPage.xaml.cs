using System.Diagnostics;

namespace EndpointMonitorService.Desktop.Pages;

public partial class DiagnosticsPage : UserControl
{
    private readonly AgentDataService _data;
    private readonly StackPanel _host;
    private string _copyText = "";
    private string _dataPath = "";

    public DiagnosticsPage(AgentDataService data)
    {
        _data = data;
        _host = new StackPanel();
        _host.Children.Add(new TextBlock
        {
            Text = "Checking the agent.",
            Style = CsUi.Style("CsBody"),
            Margin = new Thickness(0, 0, 0, 12),
        });
        BuildUi();
    }

    private void BuildUi()
    {
        var root = new StackPanel();
        root.Children.Add(new TextBlock { Text = "Diagnostics", Style = CsUi.Style("CsPageTitle") });
        root.Children.Add(new TextBlock
        {
            Text = "Agent build, ports, and collector health.",
            Style = CsUi.Style("CsBody"),
            Margin = new Thickness(0, 0, 0, 16),
        });
        root.Children.Add(_host);

        var actions = new WrapPanel { Margin = new Thickness(0, 4, 0, 0) };
        var copyInfo = new Button
        {
            Content = CsUi.Labeled("\uE8C8", "Copy system info"),
            Style = CsUi.Style("CsSecondaryButton"),
            Margin = new Thickness(0, 0, 8, 8),
        };
        copyInfo.Click += (_, _) => CopyFeedback.CopyFromButton(copyInfo, _copyText, "Copied!");
        var copyPath = new Button
        {
            Content = CsUi.Labeled("\uE8C8", "Copy path"),
            Style = CsUi.Style("CsSecondaryButton"),
            Margin = new Thickness(0, 0, 8, 8),
        };
        copyPath.Click += (_, _) => CopyFeedback.CopyFromButton(copyPath, _dataPath, "Copied!");
        var openFolder = new Button
        {
            Content = CsUi.Labeled("\uE838", "Open data folder"),
            Style = CsUi.Style("CsPrimaryButton"),
            Margin = new Thickness(0, 0, 8, 8),
        };
        openFolder.Click += (_, _) => OpenDataFolder();
        actions.Children.Add(copyInfo);
        actions.Children.Add(copyPath);
        actions.Children.Add(openFolder);
        root.Children.Add(actions);
        Content = root;
    }

    public Task RefreshAsync(LocalStatusDto? status)
    {
        _host.Children.Clear();
        if (status == null)
        {
            _copyText = "";
            _dataPath = "";
            _host.Children.Add(new TextBlock
            {
                Text = "Could not reach the agent.",
                Style = CsUi.Style("CsBody"),
            });
            return Task.CompletedTask;
        }

        _dataPath = ConsoleFormat.SafeInline(status.DataDirectory, 260);
        var https = status.UseHttps ? status.HttpsPort.ToString() : "off";
        var rows = new List<(string Label, string Value)>
        {
            ("Version", ConsoleFormat.SafeInline(status.Version, 32)),
            ("HTTP port", status.HttpPort.ToString()),
            ("HTTPS", https),
            ("WebSocket clients", status.WebSocketClients.ToString()),
            ("Sysmon", status.SysmonInstalled ? "Installed" : "Not detected"),
            ("Threat intel", status.ThreatIntelEnabled ? "Enabled" : "Disabled"),
            ("Intel entries", status.ThreatIntelEnabled ? status.ThreatIntelEntryCount.ToString() : "-"),
            ("Intel last run", FormatStamp(status.ThreatIntelLastRunUtc)),
            ("Administrator", status.RunningAsAdministrator ? "Yes" : "No"),
            ("Interactive session", status.InteractiveSession ? "Yes" : "No"),
        };

        var grid = new Grid { Margin = new Thickness(0, 0, 0, 4) };
        grid.ColumnDefinitions.Add(new ColumnDefinition());
        grid.ColumnDefinitions.Add(new ColumnDefinition());
        grid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        var pathCell = PropertyCell("Data folder", _dataPath.Length == 0 ? "-" : _dataPath);
        pathCell.Margin = new Thickness(0, 0, 12, 12);
        Grid.SetColumnSpan(pathCell, 2);
        grid.Children.Add(pathCell);

        for (var i = 0; i < rows.Count; i++)
        {
            var rowIndex = (i / 2) + 1;
            while (grid.RowDefinitions.Count <= rowIndex)
                grid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
            var cell = PropertyCell(rows[i].Label, rows[i].Value);
            Grid.SetRow(cell, rowIndex);
            Grid.SetColumn(cell, i % 2);
            grid.Children.Add(cell);
        }

        _host.Children.Add(grid);

        var intelError = ConsoleFormat.SafeInline(status.ThreatIntelLastError, 180);
        if (intelError.Length > 0 && !string.Equals(intelError, "disabled", StringComparison.OrdinalIgnoreCase))
        {
            _host.Children.Add(new TextBlock
            {
                Text = "Threat intel: " + intelError,
                Foreground = CsUi.Brush("CsErrorBrush"),
                FontFamily = CsUi.Font("CsFontUi"),
                FontSize = 12.5,
                TextWrapping = TextWrapping.Wrap,
                Margin = new Thickness(0, 0, 0, 8),
            });
        }

        _copyText = "Data folder: " + (_dataPath.Length == 0 ? "-" : _dataPath) + Environment.NewLine +
                    string.Join(Environment.NewLine, rows.Select(r => $"{r.Label}: {r.Value}"));
        if (intelError.Length > 0 && !string.Equals(intelError, "disabled", StringComparison.OrdinalIgnoreCase))
            _copyText += Environment.NewLine + "Threat intel error: " + intelError;
        return Task.CompletedTask;
    }

    private static Border PropertyCell(string label, string value)
    {
        var cell = new Border
        {
            Style = CsUi.Style("CsCard"),
            Padding = new Thickness(14, 12, 14, 12),
            Margin = new Thickness(0, 0, 12, 12),
        };
        var stack = new StackPanel();
        stack.Children.Add(new TextBlock
        {
            Text = label,
            Style = CsUi.Style("CsKicker"),
        });
        stack.Children.Add(new TextBlock
        {
            Text = value.Length == 0 ? "-" : value,
            Style = CsUi.Style("CsMono"),
            FontSize = 15,
            FontWeight = FontWeights.SemiBold,
            Margin = new Thickness(0, 6, 0, 0),
        });
        cell.Child = stack;
        return cell;
    }

    private static string FormatStamp(string? iso)
    {
        if (string.IsNullOrWhiteSpace(iso))
            return "never";
        if (DateTime.TryParse(iso, out var dt))
            return dt.ToLocalTime().ToString("yyyy-MM-dd HH:mm");
        return ConsoleFormat.SafeInline(iso, 40);
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
