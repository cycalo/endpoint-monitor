using System.Windows.Threading;
using EndpointMonitorService.Desktop.Pages;

namespace EndpointMonitorService.Desktop;

public partial class MainWindow : Window
{
    private readonly AgentDataService _data;
    private readonly UiSettings _settings;
    private readonly HomePage _homePage;
    private readonly PairPage _pairPage;
    private readonly DevicesPage _devicesPage;
    private readonly DiagnosticsPage _diagnosticsPage;
    private readonly SettingsPage _settingsPage;
    private readonly DispatcherTimer _pollTimer;
    private bool _isHidden;

    public event EventHandler? RequestHideToTray;
    public event EventHandler? RequestExitUi;

    public MainWindow(AgentDataService data, UiSettings settings)
    {
        _data = data;
        _settings = settings;

        EnsureThemeResources();
        InitializeComponent();

        _homePage = new HomePage(data, () => NavigateTo(NavPair), () => NavigateTo(NavDevices));
        _pairPage = new PairPage(data);
        _devicesPage = new DevicesPage(data);
        _diagnosticsPage = new DiagnosticsPage(data);
        _settingsPage = new SettingsPage(settings);

        NavHome.Checked += (_, _) => ShowPage(_homePage);
        NavPair.Checked += (_, _) => ShowPage(_pairPage);
        NavDevices.Checked += (_, _) => ShowPage(_devicesPage);
        NavDiagnostics.Checked += (_, _) => ShowPage(_diagnosticsPage);
        NavSettings.Checked += (_, _) => { ShowPage(_settingsPage); _settingsPage.Refresh(); };

        ShowPage(_homePage);

        _pollTimer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(2) };
        _pollTimer.Tick += async (_, _) => await PollCurrentPageAsync().ConfigureAwait(true);

        Loaded += async (_, _) =>
        {
            _pollTimer.Start();
            await PollCurrentPageAsync().ConfigureAwait(true);
        };

        StateChanged += (_, _) => OnWindowStateChanged();
        Closing += OnClosing;
    }

    public void NavigateToPair() => NavPair.IsChecked = true;

    public void RestoreFromTray()
    {
        _isHidden = false;
        Show();
        WindowState = WindowState.Normal;
        Activate();
        _pollTimer.Start();
        _ = PollCurrentPageAsync();
    }

    public void HideToTray()
    {
        _isHidden = true;
        _pollTimer.Stop();
        Hide();
        RequestHideToTray?.Invoke(this, EventArgs.Empty);
    }

    private void ShowPage(UserControl page)
    {
        PageHost.Content = page;
        FitPage();
        if (page is PairPage pair)
            _ = pair.RefreshAsync();
        _ = PollCurrentPageAsync();
    }

    private void PageScroll_SizeChanged(object sender, SizeChangedEventArgs e) => FitPage();

    private void FitPage()
    {
        if (PageHost.Content is not FrameworkElement page)
            return;

        var pad = PageScroll.Padding.Top + PageScroll.Padding.Bottom;
        page.MinHeight = Math.Max(0, PageScroll.ViewportHeight - pad);
    }

    private static void EnsureThemeResources()
    {
        if (Application.Current == null)
            new Application();

        var app = Application.Current!;
        var alreadyLoaded = app.Resources.MergedDictionaries
            .Any(d => d.Source?.OriginalString.Contains("CyberSlate", StringComparison.OrdinalIgnoreCase) == true);
        if (alreadyLoaded)
            return;

        app.Resources.MergedDictionaries.Add(
            (ResourceDictionary)Application.LoadComponent(
                new Uri("/EndpointMonitorService;component/Desktop/CyberSlate.xaml", UriKind.Relative)));
    }

    private void NavigateTo(RadioButton nav)
    {
        nav.IsChecked = true;
    }

    private async Task PollCurrentPageAsync()
    {
        if (_isHidden || !IsVisible)
            return;

        var status = await _data.GetStatusAsync().ConfigureAwait(true);
        UpdateSidebar(status);

        switch (PageHost.Content)
        {
            case HomePage home:
                await home.RefreshAsync(status).ConfigureAwait(true);
                break;
            case PairPage:
                // Pairing codes refresh only when the page is opened.
                break;
            case DevicesPage devices:
                await devices.RefreshAsync(status).ConfigureAwait(true);
                break;
            case DiagnosticsPage diag:
                await diag.RefreshAsync(status).ConfigureAwait(true);
                break;
        }
    }

    private void UpdateSidebar(LocalStatusDto? status)
    {
        var uptime = TimeSpan.FromMilliseconds(Math.Max(0, Environment.TickCount64));
        UptimeText.Text = "Up " + ConsoleFormat.FormatHostUptime(uptime);

        if (status == null)
        {
            ServiceDot.Fill = (Brush)FindResource("CsErrorBrush");
            ServiceLabel.Text = "Service offline";
            ServiceLabel.Foreground = (Brush)FindResource("CsErrorBrush");
            VersionText.Text = ConsoleFormat.FormatAgentVersion(null);
            return;
        }

        ServiceDot.Fill = (Brush)FindResource("CsSuccessBrush");
        ServiceLabel.Text = "Service active";
        ServiceLabel.Foreground = (Brush)FindResource("CsSuccessBrush");
        VersionText.Text = ConsoleFormat.FormatAgentVersion(status.Version);
    }

    private void OnWindowStateChanged()
    {
        if (_settings.MinimizeToTray && WindowState == WindowState.Minimized)
            HideToTray();
    }

    private void OnClosing(object? sender, System.ComponentModel.CancelEventArgs e)
    {
        if (_settings.MinimizeToTray)
        {
            e.Cancel = true;
            HideToTray();
            return;
        }

        RequestExitUi?.Invoke(this, EventArgs.Empty);
    }
}
