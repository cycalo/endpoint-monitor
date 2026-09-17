using EndpointMonitorService.Services;

namespace EndpointMonitorService.Desktop.Pages;

public partial class HomePage : UserControl
{
    private readonly AgentDataService _data;
    private readonly Action _navigateToPair;
    private readonly Action _navigateToDevices;

    private Border _statusPill = null!;
    private TextBlock _statusText = null!;
    private TextBlock _connectedPhones = null!;
    private TextBlock _pairedDevices = null!;
    private TextBlock _wifiStatus = null!;
    private TextBlock _tailscaleStatus = null!;
    private StackPanel _chipsPanel = null!;
    private TextBlock _nextTitle = null!;
    private TextBlock _nextBody = null!;
    private Button _pairBtn = null!;
    private Button _devicesBtn = null!;

    public HomePage(AgentDataService data, Action navigateToPair, Action navigateToDevices)
    {
        _data = data;
        _navigateToPair = navigateToPair;
        _navigateToDevices = navigateToDevices;
        BuildUi();
    }

    private void BuildUi()
    {
        var root = new StackPanel();
        root.Children.Add(new TextBlock { Text = "Home", Style = (Style)Application.Current.FindResource("CsPageTitle") });
        root.Children.Add(new TextBlock
        {
            Text = "Agent health, connected phones, and whether this PC can be reached.",
            Style = (Style)Application.Current.FindResource("CsBody"),
            Margin = new Thickness(0, -8, 0, 16),
        });

        var statusCard = new Border { Style = (Style)Application.Current.FindResource("CsCard"), Margin = new Thickness(0, 0, 0, 12) };
        var statusInner = new StackPanel();

        _statusPill = new Border
        {
            Style = (Style)Application.Current.FindResource("CsStatusPill"),
            Background = new SolidColorBrush(Color.FromRgb(0x17, 0x1F, 0x33)),
        };
        _statusText = new TextBlock
        {
            FontFamily = new FontFamily("Segoe UI"),
            FontSize = 12.5,
            FontWeight = FontWeights.SemiBold,
            Foreground = (Brush)Application.Current.FindResource("CsOnSurfaceVariantBrush"),
            Text = "Checking agent…",
        };
        _statusPill.Child = _statusText;
        statusInner.Children.Add(_statusPill);

        statusInner.Children.Add(MakeRow("Connected phones", out _connectedPhones));
        statusInner.Children.Add(MakeRow("Paired devices", out _pairedDevices));
        statusInner.Children.Add(MakeRow("This Wi-Fi", out _wifiStatus));
        statusInner.Children.Add(MakeRow("Away from home", out _tailscaleStatus));

        _chipsPanel = new StackPanel { Orientation = Orientation.Horizontal, Margin = new Thickness(0, 12, 0, 0) };
        statusInner.Children.Add(_chipsPanel);

        statusCard.Child = statusInner;
        root.Children.Add(statusCard);

        var nextCard = new Border { Style = (Style)Application.Current.FindResource("CsCard") };
        var nextInner = new StackPanel();
        _nextTitle = new TextBlock
        {
            FontFamily = new FontFamily("Segoe UI"),
            FontSize = 15,
            FontWeight = FontWeights.SemiBold,
            Foreground = (Brush)Application.Current.FindResource("CsOnSurfaceBrush"),
            Text = "Checking…",
        };
        nextInner.Children.Add(_nextTitle);
        _nextBody = new TextBlock
        {
            Style = (Style)Application.Current.FindResource("CsBody"),
            Margin = new Thickness(0, 6, 0, 0),
            Text = "",
        };
        nextInner.Children.Add(_nextBody);

        var btnRow = new StackPanel { Orientation = Orientation.Horizontal, Margin = new Thickness(0, 16, 0, 0) };
        _pairBtn = new Button
        {
            Content = "Open Pair",
            Style = (Style)Application.Current.FindResource("CsPrimaryButton"),
            Margin = new Thickness(0, 0, 8, 0),
            HorizontalAlignment = HorizontalAlignment.Left,
            Visibility = Visibility.Collapsed,
        };
        _pairBtn.Click += (_, _) => _navigateToPair();
        _devicesBtn = new Button
        {
            Content = "View devices",
            Style = (Style)Application.Current.FindResource("CsSecondaryButton"),
            HorizontalAlignment = HorizontalAlignment.Left,
            Visibility = Visibility.Collapsed,
        };
        _devicesBtn.Click += (_, _) => _navigateToDevices();
        btnRow.Children.Add(_pairBtn);
        btnRow.Children.Add(_devicesBtn);
        nextInner.Children.Add(btnRow);

        nextCard.Child = nextInner;
        root.Children.Add(nextCard);
        Content = root;
    }

    private static StackPanel MakeRow(string label, out TextBlock value)
    {
        var panel = new StackPanel { Margin = new Thickness(0, 14, 0, 0) };
        panel.Children.Add(new TextBlock { Text = label, Style = (Style)Application.Current.FindResource("CsLabel") });
        value = new TextBlock { Style = (Style)Application.Current.FindResource("CsValue"), Text = "—" };
        panel.Children.Add(value);
        return panel;
    }

    public async Task RefreshAsync()
    {
        var statusTask = _data.GetStatusAsync();
        var devicesTask = _data.GetDevicesAsync();
        await Task.WhenAll(statusTask, devicesTask).ConfigureAwait(true);

        var status = statusTask.Result;
        var pairedCount = devicesTask.Result.Count(d => !d.Revoked);

        if (status == null)
        {
            SetUnreachable(pairedCount);
            return;
        }

        SetRunning();
        _connectedPhones.Text = status.WebSocketClients.ToString();
        _pairedDevices.Text = pairedCount.ToString();

        var endpoints = EndpointAddressList.FromStatus(status);
        var wifiReady = HomeDashboard.WifiReady(endpoints);
        var tailscale = HomeDashboard.TailscaleConnected(endpoints);
        SetReadiness(_wifiStatus, HomeDashboard.WifiStatus(wifiReady), wifiReady);
        SetReadiness(_tailscaleStatus, HomeDashboard.TailscaleStatus(tailscale), tailscale);

        _chipsPanel.Children.Clear();
        AddChip(status.SysmonInstalled ? "Sysmon installed" : "Sysmon not detected",
            status.SysmonInstalled ? "CsSuccessBrush" : "CsOnSurfaceVariantBrush");
        AddChip(status.RunningAsAdministrator ? "Administrator" : "Not elevated",
            status.RunningAsAdministrator ? "CsSuccessBrush" : "CsErrorBrush");

        ApplyNextStep(HomeDashboard.NextStep(true, pairedCount, status.WebSocketClients));
    }

    private void ApplyNextStep(HomeNextStep step)
    {
        _nextTitle.Text = step.Title;
        _nextBody.Text = step.Body;
        _pairBtn.Visibility = step.ShowPair ? Visibility.Visible : Visibility.Collapsed;
        _devicesBtn.Visibility = step.ShowDevices ? Visibility.Visible : Visibility.Collapsed;
        _pairBtn.Content = step.ShowDevices ? "Pair another" : "Open Pair";
    }

    private void AddChip(string text, string brushKey)
    {
        var chip = new Border { Style = (Style)Application.Current.FindResource("CsChip") };
        chip.Child = new TextBlock
        {
            Text = text,
            FontSize = 11.5,
            Foreground = (Brush)Application.Current.FindResource(brushKey),
        };
        _chipsPanel.Children.Add(chip);
    }

    private void SetRunning()
    {
        _statusPill.Background = new SolidColorBrush(Color.FromArgb(0x33, 0x4A, 0xDE, 0x80));
        _statusText.Text = "Agent running";
        _statusText.Foreground = (Brush)Application.Current.FindResource("CsSuccessBrush");
    }

    private void SetUnreachable(int pairedCount)
    {
        _statusPill.Background = new SolidColorBrush(Color.FromArgb(0x33, 0xFF, 0xB4, 0xAB));
        _statusText.Text = "Agent unreachable";
        _statusText.Foreground = (Brush)Application.Current.FindResource("CsErrorBrush");
        _connectedPhones.Text = "—";
        _pairedDevices.Text = pairedCount > 0 ? pairedCount.ToString() : "—";
        SetReadiness(_wifiStatus, "—", ok: false);
        SetReadiness(_tailscaleStatus, "—", ok: false);
        _chipsPanel.Children.Clear();
        ApplyNextStep(HomeDashboard.NextStep(false, pairedCount, 0));
    }

    private static void SetReadiness(TextBlock target, string text, bool ok)
    {
        target.Text = text;
        target.Foreground = ok
            ? (Brush)Application.Current.FindResource("CsSuccessBrush")
            : (Brush)Application.Current.FindResource("CsOnSurfaceVariantBrush");
    }
}
