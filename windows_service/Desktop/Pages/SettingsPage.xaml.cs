namespace EndpointMonitorService.Desktop.Pages;

public partial class SettingsPage : UserControl
{
    private readonly UiSettings _settings;
    private CheckBox _minimizeTray = null!;
    private CheckBox _startWithWindows = null!;
    private bool _suppressStartWithWindowsEvents;

    public SettingsPage(UiSettings settings)
    {
        _settings = settings;
        BuildUi();
    }

    private void BuildUi()
    {
        var root = new StackPanel();
        root.Children.Add(new TextBlock { Text = "Settings", Style = CsUi.Style("CsPageTitle") });
        root.Children.Add(new TextBlock
        {
            Text = "Desktop console preferences. Monitoring continues when this window is closed.",
            Style = CsUi.Style("CsBody"),
            Margin = new Thickness(0, 0, 0, 16),
        });

        var grid = new Grid();
        grid.ColumnDefinitions.Add(new ColumnDefinition());
        grid.ColumnDefinitions.Add(new ColumnDefinition());

        var startup = SettingCard(
            "\uE7E8",
            "Windows startup",
            "Registers the Windows service to start at boot. Approving the UAC prompt applies the change.");
        _startWithWindows = CheckBox("Start with Windows (Windows Service)");
        _suppressStartWithWindowsEvents = true;
        _startWithWindows.IsChecked = SafeIsAutomaticStart();
        _suppressStartWithWindowsEvents = false;
        _startWithWindows.Checked += (_, _) =>
        {
            if (!_suppressStartWithWindowsEvents)
                ToggleWindowsStart(true);
        };
        _startWithWindows.Unchecked += (_, _) =>
        {
            if (!_suppressStartWithWindowsEvents)
                ToggleWindowsStart(false);
        };
        ((StackPanel)startup.Child).Children.Add(_startWithWindows);
        startup.Margin = new Thickness(0, 0, 12, 0);
        Grid.SetColumn(startup, 0);
        grid.Children.Add(startup);

        var tray = SettingCard(
            "\uE718",
            "System tray",
            "Closing or minimizing this window keeps the console in the system tray.");
        _minimizeTray = CheckBox("Minimize to system tray when closing or minimizing");
        _minimizeTray.IsChecked = _settings.MinimizeToTray;
        _minimizeTray.Checked += (_, _) => SaveMinimizeTray(true);
        _minimizeTray.Unchecked += (_, _) => SaveMinimizeTray(false);
        ((StackPanel)tray.Child).Children.Add(_minimizeTray);
        Grid.SetColumn(tray, 1);
        grid.Children.Add(tray);
        root.Children.Add(grid);

        root.Children.Add(new TextBlock
        {
            Text = "Closing this app does not stop the agent. The Windows Service continues monitoring in the background.",
            Style = CsUi.Style("CsBody"),
            Margin = new Thickness(0, 16, 0, 0),
        });
        Content = root;
    }

    private static Border SettingCard(string glyph, string title, string body)
    {
        var card = new Border
        {
            Style = CsUi.Style("CsCard"),
            VerticalAlignment = VerticalAlignment.Stretch,
        };
        var inner = new StackPanel();
        var header = new StackPanel { Orientation = Orientation.Horizontal, Margin = new Thickness(0, 0, 0, 10) };
        var badge = CsUi.Badge(glyph, "CsPrimaryBrush");
        badge.Margin = new Thickness(0, 0, 12, 0);
        header.Children.Add(badge);
        header.Children.Add(new TextBlock
        {
            Text = title,
            FontFamily = CsUi.Font("CsFontUi"),
            FontSize = 16,
            FontWeight = FontWeights.SemiBold,
            Foreground = CsUi.Brush("CsOnSurfaceBrush"),
            VerticalAlignment = VerticalAlignment.Center,
        });
        inner.Children.Add(header);
        inner.Children.Add(new TextBlock
        {
            Text = body,
            Style = CsUi.Style("CsBody"),
            Margin = new Thickness(0, 0, 0, 14),
        });
        card.Child = inner;
        return card;
    }

    private static CheckBox CheckBox(string label) => new()
    {
        Content = label,
        Foreground = CsUi.Brush("CsOnSurfaceBrush"),
        FontFamily = CsUi.Font("CsFontUi"),
        FontSize = 13.5,
    };

    public void Refresh()
    {
        try
        {
            _suppressStartWithWindowsEvents = true;
            _startWithWindows.IsChecked = WindowsServiceAutorunHelper.IsAutomaticStart();
            _suppressStartWithWindowsEvents = false;
        }
        catch
        {
            _startWithWindows.IsEnabled = false;
        }
    }

    public bool MinimizeToTray => _settings.MinimizeToTray;

    private static bool SafeIsAutomaticStart()
    {
        try { return WindowsServiceAutorunHelper.IsAutomaticStart(); }
        catch { return false; }
    }

    private static void ToggleWindowsStart(bool enable)
    {
        try
        {
            WindowsServiceAutorunHelper.RequestSetAutomaticStart(enable);
            MessageBox.Show(
                "If a UAC prompt appeared, approve it to apply the change.\n\n" +
                "The service starts at boot independently of this desktop app.",
                "Windows startup",
                MessageBoxButton.OK,
                MessageBoxImage.Information);
        }
        catch (InvalidOperationException ex)
        {
            MessageBox.Show(ex.Message, "Windows startup", MessageBoxButton.OK, MessageBoxImage.Warning);
        }
        catch (Exception)
        {
            MessageBox.Show(
                "Could not start the elevated setup. Run as Administrator or see BUILD-SINGLE-EXE.md.",
                "Windows startup",
                MessageBoxButton.OK,
                MessageBoxImage.Warning);
        }
    }

    private void SaveMinimizeTray(bool value)
    {
        _settings.MinimizeToTray = value;
        UiSettingsStore.Save(_settings);
    }
}
