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
        root.Children.Add(new TextBlock { Text = "Settings", Style = (Style)Application.Current.FindResource("CsPageTitle") });

        var card = new Border { Style = (Style)Application.Current.FindResource("CsCard") };
        var inner = new StackPanel();

        _startWithWindows = new CheckBox
        {
            Content = "Start with Windows (Windows Service)",
            Foreground = (System.Windows.Media.Brush)Application.Current.FindResource("CsOnSurfaceBrush"),
            FontFamily = new System.Windows.Media.FontFamily("Segoe UI"),
            FontSize = 13.5,
            Margin = new Thickness(0, 0, 0, 16),
        };
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
        inner.Children.Add(_startWithWindows);

        _minimizeTray = new CheckBox
        {
            Content = "Minimize to system tray when closing or minimizing",
            Foreground = (System.Windows.Media.Brush)Application.Current.FindResource("CsOnSurfaceBrush"),
            FontFamily = new System.Windows.Media.FontFamily("Segoe UI"),
            FontSize = 13.5,
            IsChecked = _settings.MinimizeToTray,
        };
        _minimizeTray.Checked += (_, _) => SaveMinimizeTray(true);
        _minimizeTray.Unchecked += (_, _) => SaveMinimizeTray(false);
        inner.Children.Add(_minimizeTray);

        inner.Children.Add(new TextBlock
        {
            Text = "Closing this app does not stop the agent. The Windows Service continues monitoring in the background.",
            Style = (Style)Application.Current.FindResource("CsBody"),
            Margin = new Thickness(0, 20, 0, 0),
        });

        card.Child = inner;
        root.Children.Add(card);
        Content = root;
    }

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
