using EndpointMonitorService.Services;

namespace EndpointMonitorService.Desktop.Pages;

public partial class HomePage : UserControl
{
    private readonly AgentDataService _data;
    private readonly Action _navigateToPair;

    private Border _statusPill = null!;
    private TextBlock _statusText = null!;
    private TextBlock _httpUrl = null!;
    private TextBlock _wsClients = null!;
    private StackPanel _chipsPanel = null!;
    private StackPanel _addressHost = null!;

    public HomePage(AgentDataService data, Action navigateToPair)
    {
        _data = data;
        _navigateToPair = navigateToPair;
        BuildUi();
    }

    private void BuildUi()
    {
        var root = new StackPanel();
        root.Children.Add(new TextBlock { Text = "Home", Style = (Style)Application.Current.FindResource("CsPageTitle") });

        var card = new Border { Style = (Style)Application.Current.FindResource("CsCard") };
        var inner = new StackPanel();

        _statusPill = new Border { Style = (Style)Application.Current.FindResource("CsStatusPill"), Background = new SolidColorBrush(Color.FromRgb(0x17, 0x1F, 0x33)) };
        _statusText = new TextBlock
        {
            FontFamily = new FontFamily("Segoe UI"),
            FontSize = 12.5,
            FontWeight = FontWeights.SemiBold,
            Foreground = (Brush)Application.Current.FindResource("CsOnSurfaceVariantBrush"),
            Text = "Checking agent…",
        };
        _statusPill.Child = _statusText;
        inner.Children.Add(_statusPill);

        inner.Children.Add(MakeRow("HTTP URL", out _httpUrl));
        inner.Children.Add(MakeRow("Connected phones", out _wsClients));

        _chipsPanel = new StackPanel { Orientation = Orientation.Horizontal, Margin = new Thickness(0, 12, 0, 0) };
        inner.Children.Add(_chipsPanel);

        var pairBtn = new Button
        {
            Content = "Pair a phone",
            Style = (Style)Application.Current.FindResource("CsPrimaryButton"),
            Margin = new Thickness(0, 20, 0, 0),
            HorizontalAlignment = HorizontalAlignment.Left,
        };
        pairBtn.Click += (_, _) => _navigateToPair();
        inner.Children.Add(pairBtn);

        var copyHttp = new Button
        {
            Content = "Copy HTTP URL",
            Style = (Style)Application.Current.FindResource("CsSecondaryButton"),
            Margin = new Thickness(0, 10, 8, 0),
            HorizontalAlignment = HorizontalAlignment.Left,
        };
        copyHttp.Click += (_, _) => EndpointAddressList.CopyText(_httpUrl.Text);
        inner.Children.Add(copyHttp);

        card.Child = inner;
        root.Children.Add(card);

        _addressHost = new StackPanel { Margin = new Thickness(0, 16, 0, 0) };
        root.Children.Add(_addressHost);
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
        var status = await _data.GetStatusAsync().ConfigureAwait(true);
        if (status == null)
        {
            SetUnreachable();
            return;
        }

        SetRunning();
        _httpUrl.Text = $"http://localhost:{status.HttpPort}";
        _wsClients.Text = status.WebSocketClients.ToString();
        RenderAddresses(EndpointAddressList.FromStatus(status));

        _chipsPanel.Children.Clear();
        AddChip(status.SysmonInstalled ? "Sysmon installed" : "Sysmon not detected",
            status.SysmonInstalled ? "CsSuccessBrush" : "CsOnSurfaceVariantBrush");
        AddChip(status.RunningAsAdministrator ? "Administrator" : "Not elevated",
            status.RunningAsAdministrator ? "CsSuccessBrush" : "CsErrorBrush");
    }

    private void RenderAddresses(IReadOnlyList<NetworkEndpoint> endpoints)
    {
        _addressHost.Children.Clear();
        var lan = endpoints.Where(e => e.Kind == NetworkEndpointKind.Lan).ToList();
        var tailscale = endpoints.Where(e => e.Kind == NetworkEndpointKind.Tailscale).ToList();
        var other = endpoints.Where(e => e.Kind == NetworkEndpointKind.Other).ToList();

        _addressHost.Children.Add(EndpointAddressList.PathCard(
            "This Wi-Fi",
            "Phone and PC on the same network. Use one of these addresses in the app.",
            "On the phone: Connect → This Wi-Fi.",
            lan,
            "No local Wi-Fi or Ethernet address detected."));

        _addressHost.Children.Add(EndpointAddressList.PathCard(
            "Away from home",
            "Reach this PC over Tailscale from any network.",
            "On the phone: Connect → Away from home. Use the 100. address, not a 192.168 address.",
            tailscale,
            "Tailscale is not connected on this PC."));

        if (other.Count > 0)
        {
            _addressHost.Children.Add(EndpointAddressList.PathCard(
                "Other adapters",
                "Virtual switches and extra NICs. Do not use these in the phone app.",
                "",
                other,
                ""));
        }
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

    private void SetUnreachable()
    {
        _statusPill.Background = new SolidColorBrush(Color.FromArgb(0x33, 0xFF, 0xB4, 0xAB));
        _statusText.Text = "Agent unreachable";
        _statusText.Foreground = (Brush)Application.Current.FindResource("CsErrorBrush");
        _httpUrl.Text = "—";
        _wsClients.Text = "—";
        _chipsPanel.Children.Clear();
        _addressHost.Children.Clear();
    }
}
