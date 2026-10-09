using System.Windows.Media.Animation;
using EndpointMonitorService.Services;

namespace EndpointMonitorService.Desktop.Pages;

public partial class HomePage : UserControl
{
    private const int SeriesCap = 48;

    private readonly AgentDataService _data;
    private readonly Action _navigateToPair;
    private readonly Action _navigateToDevices;
    private readonly List<double> _cpuSeries = new();
    private readonly List<double> _ramSeries = new();

    private TextBlock _agentText = null!;
    private TextBlock _agentIcon = null!;
    private TextBlock _elevationText = null!;
    private TextBlock _elevationIcon = null!;
    private TextBlock _sysmonText = null!;
    private TextBlock _sysmonIcon = null!;
    private TextBlock _wsCount = null!;
    private TextBlock _pairedCount = null!;
    private System.Windows.Shapes.Ellipse _pulse = null!;
    private bool _pulseLive;
    private TextBlock _wifiStatus = null!;
    private TextBlock _tailscaleStatus = null!;
    private WrapPanel _wifiChips = null!;
    private WrapPanel _tailscaleChips = null!;
    private TextBlock _cpuLabel = null!;
    private TextBlock _ramLabel = null!;
    private TextBlock _telemetryHint = null!;
    private SparklineChart _spark = null!;
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
        var root = new Grid();
        root.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        root.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        root.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        root.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });

        var title = new TextBlock { Text = "Home", Style = CsUi.Style("CsPageTitle") };
        Grid.SetRow(title, 0);
        root.Children.Add(title);
        var lead = new TextBlock
        {
            Text = "Agent health, live sessions, and whether this PC can be reached.",
            Style = CsUi.Style("CsBody"),
            Margin = new Thickness(0, 0, 0, 16),
        };
        Grid.SetRow(lead, 1);
        root.Children.Add(lead);

        var tiles = new Grid { Margin = new Thickness(0, 0, 0, 12) };
        tiles.ColumnDefinitions.Add(new ColumnDefinition());
        tiles.ColumnDefinitions.Add(new ColumnDefinition());
        tiles.ColumnDefinitions.Add(new ColumnDefinition());

        var core = Tile();
        core.Margin = new Thickness(0, 0, 12, 0);
        var coreInner = new StackPanel();
        coreInner.Children.Add(Kicker("Core service"));
        coreInner.Children.Add(StatusRow(out _agentIcon, out _agentText, "Checking agent"));
        coreInner.Children.Add(StatusRow(out _elevationIcon, out _elevationText, "Elevation -"));
        coreInner.Children.Add(StatusRow(out _sysmonIcon, out _sysmonText, "Sysmon -"));
        core.Child = coreInner;
        Grid.SetColumn(core, 0);
        tiles.Children.Add(core);

        var connection = Tile();
        connection.Margin = new Thickness(0, 0, 12, 0);
        var connectionInner = new StackPanel();
        connectionInner.Children.Add(Kicker("Connections"));
        var stats = new Grid { Margin = new Thickness(0, 12, 0, 0), ClipToBounds = true };
        stats.ColumnDefinitions.Add(new ColumnDefinition());
        stats.ColumnDefinitions.Add(new ColumnDefinition());
        _pulse = new System.Windows.Shapes.Ellipse();
        var wsBlock = StatBlock(_pulse, out _wsCount, "Active WebSockets");
        Grid.SetColumn(wsBlock, 0);
        stats.Children.Add(wsBlock);
        var pairedBlock = StatBlock(null, out _pairedCount, "Paired devices");
        Grid.SetColumn(pairedBlock, 1);
        stats.Children.Add(pairedBlock);
        connectionInner.Children.Add(stats);
        connection.Child = connectionInner;
        Grid.SetColumn(connection, 1);
        tiles.Children.Add(connection);

        var network = Tile();
        var networkInner = new StackPanel();
        networkInner.Children.Add(Kicker("Network readiness"));
        networkInner.Children.Add(ReadinessBlock("This Wi-Fi", "\uE701", out _wifiStatus, out _wifiChips));
        networkInner.Children.Add(ReadinessBlock("Away from home", "\uE72E", out _tailscaleStatus, out _tailscaleChips));
        network.Child = networkInner;
        Grid.SetColumn(network, 2);
        tiles.Children.Add(network);
        Grid.SetRow(tiles, 2);
        root.Children.Add(tiles);

        var lower = new Grid();
        lower.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1.35, GridUnitType.Star) });
        lower.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });

        var telemetry = Tile();
        telemetry.Margin = new Thickness(0, 0, 12, 0);
        var telemetryInner = new Grid();
        telemetryInner.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        telemetryInner.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        telemetryInner.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });
        telemetryInner.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        var telemetryTitle = Kicker("Live telemetry");
        Grid.SetRow(telemetryTitle, 0);
        telemetryInner.Children.Add(telemetryTitle);
        var legend = new StackPanel { Orientation = Orientation.Horizontal, Margin = new Thickness(0, 10, 0, 8) };
        legend.Children.Add(LegendDot("CsPrimaryBrush"));
        _cpuLabel = LegendValue("CPU -");
        legend.Children.Add(_cpuLabel);
        legend.Children.Add(LegendDot("CsTertiaryBrush"));
        _ramLabel = LegendValue("RAM -");
        legend.Children.Add(_ramLabel);
        Grid.SetRow(legend, 1);
        telemetryInner.Children.Add(legend);
        _spark = new SparklineChart { Margin = new Thickness(0, 4, 0, 0) };
        Grid.SetRow(_spark, 2);
        telemetryInner.Children.Add(_spark);
        _telemetryHint = new TextBlock
        {
            Text = "Sampling this PC…",
            Style = CsUi.Style("CsBody"),
            FontSize = 12,
            Margin = new Thickness(0, 6, 0, 0),
        };
        Grid.SetRow(_telemetryHint, 3);
        telemetryInner.Children.Add(_telemetryHint);
        telemetry.Child = telemetryInner;
        Grid.SetColumn(telemetry, 0);
        lower.Children.Add(telemetry);

        var next = Tile();
        var nextInner = new StackPanel();
        nextInner.Children.Add(Kicker("Next step"));
        _nextTitle = new TextBlock
        {
            FontFamily = CsUi.Font("CsFontUi"),
            FontSize = 16,
            FontWeight = FontWeights.SemiBold,
            Foreground = CsUi.Brush("CsOnSurfaceBrush"),
            Text = "Checking…",
            Margin = new Thickness(0, 10, 0, 0),
            TextWrapping = TextWrapping.Wrap,
        };
        nextInner.Children.Add(_nextTitle);
        _nextBody = new TextBlock
        {
            Style = CsUi.Style("CsBody"),
            Margin = new Thickness(0, 6, 0, 0),
        };
        nextInner.Children.Add(_nextBody);
        var btnRow = new WrapPanel { Margin = new Thickness(0, 16, 0, 0) };
        _pairBtn = new Button
        {
            Content = CsUi.Labeled("\uE71B", "Open Pair"),
            Style = CsUi.Style("CsPrimaryButton"),
            Margin = new Thickness(0, 0, 8, 8),
            Visibility = Visibility.Collapsed,
        };
        _pairBtn.Click += (_, _) => _navigateToPair();
        _devicesBtn = new Button
        {
            Content = CsUi.Labeled("\uE717", "View devices"),
            Style = CsUi.Style("CsSecondaryButton"),
            Margin = new Thickness(0, 0, 8, 8),
            Visibility = Visibility.Collapsed,
        };
        _devicesBtn.Click += (_, _) => _navigateToDevices();
        btnRow.Children.Add(_pairBtn);
        btnRow.Children.Add(_devicesBtn);
        nextInner.Children.Add(btnRow);
        next.Child = nextInner;
        Grid.SetColumn(next, 1);
        lower.Children.Add(next);
        Grid.SetRow(lower, 3);
        root.Children.Add(lower);
        Content = root;
    }

    public async Task RefreshAsync(LocalStatusDto? status)
    {
        SampleHost();

        var devices = await _data.GetDevicesAsync().ConfigureAwait(true);
        var pairedCount = devices.Count(d => !d.Revoked);
        if (status == null)
        {
            SetUnreachable(pairedCount);
            return;
        }

        SetStatusRow(_agentIcon, _agentText, "Agent running", ok: true);
        SetStatusRow(_elevationIcon, _elevationText,
            status.RunningAsAdministrator ? "Administrator" : "Not elevated",
            ok: status.RunningAsAdministrator,
            bad: !status.RunningAsAdministrator);
        SetStatusRow(_sysmonIcon, _sysmonText,
            status.SysmonInstalled ? "Sysmon installed" : "Sysmon not detected",
            ok: status.SysmonInstalled);

        _wsCount.Text = status.WebSocketClients.ToString();
        _pairedCount.Text = pairedCount.ToString();
        SetPulse(status.WebSocketClients > 0);

        var endpoints = EndpointAddressList.FromStatus(status);
        var wifiReady = HomeDashboard.WifiReady(endpoints);
        var tailscale = HomeDashboard.TailscaleConnected(endpoints);
        SetReadiness(_wifiStatus, HomeDashboard.WifiStatus(wifiReady), wifiReady);
        SetReadiness(_tailscaleStatus, HomeDashboard.TailscaleStatus(tailscale), tailscale);
        FillIpChips(_wifiChips, endpoints.Where(e => e.Kind == NetworkEndpointKind.Lan).Take(2));
        FillIpChips(_tailscaleChips, endpoints.Where(e => e.Kind == NetworkEndpointKind.Tailscale).Take(1));

        ApplyNextStep(HomeDashboard.NextStep(true, pairedCount, status.WebSocketClients));
    }

    private void SampleHost()
    {
        var sample = HostTelemetrySampler.Read();
        _ramLabel.Text = sample.HasRam ? $"RAM {sample.RamPercent:0}%" : "RAM -";
        if (!sample.HasCpu)
        {
            _cpuLabel.Text = "CPU -";
            return;
        }

        _cpuLabel.Text = $"CPU {sample.CpuPercent:0}%";
        Push(_cpuSeries, sample.CpuPercent);
        Push(_ramSeries, sample.HasRam ? sample.RamPercent : 0);
        _spark.SetSeries(_cpuSeries, _ramSeries);
        _telemetryHint.Visibility = _cpuSeries.Count >= 2 ? Visibility.Collapsed : Visibility.Visible;
    }

    private static void Push(List<double> series, double value)
    {
        series.Add(value);
        if (series.Count > SeriesCap)
            series.RemoveAt(0);
    }

    private void ApplyNextStep(HomeNextStep step)
    {
        _nextTitle.Text = step.Title;
        _nextBody.Text = step.Body;
        _pairBtn.Visibility = step.ShowPair ? Visibility.Visible : Visibility.Collapsed;
        _devicesBtn.Visibility = step.ShowDevices ? Visibility.Visible : Visibility.Collapsed;
        _pairBtn.Content = CsUi.Labeled("\uE71B", step.ShowDevices ? "Pair another" : "Open Pair");
    }

    private void SetUnreachable(int pairedCount)
    {
        SetStatusRow(_agentIcon, _agentText, "Agent unreachable", ok: false, bad: true);
        SetStatusRow(_elevationIcon, _elevationText, "Elevation -", ok: false);
        SetStatusRow(_sysmonIcon, _sysmonText, "Sysmon -", ok: false);
        _wsCount.Text = "-";
        _pairedCount.Text = pairedCount > 0 ? pairedCount.ToString() : "-";
        SetPulse(false);
        SetReadiness(_wifiStatus, "-", ok: false);
        SetReadiness(_tailscaleStatus, "-", ok: false);
        _wifiChips.Children.Clear();
        _tailscaleChips.Children.Clear();
        ApplyNextStep(HomeDashboard.NextStep(false, pairedCount, 0));
    }

    private void SetPulse(bool live)
    {
        if (live)
        {
            _pulse.Fill = CsUi.Brush("CsSuccessBrush");
            if (_pulseLive)
                return;
            _pulseLive = true;
            _pulse.BeginAnimation(OpacityProperty, new DoubleAnimation(1, 0.25, TimeSpan.FromMilliseconds(850))
            {
                AutoReverse = true,
                RepeatBehavior = RepeatBehavior.Forever,
            });
            return;
        }

        _pulseLive = false;
        _pulse.BeginAnimation(OpacityProperty, null);
        _pulse.Opacity = 0.45;
        _pulse.Fill = CsUi.Brush("CsOnSurfaceVariantBrush");
    }

    private static void SetStatusRow(TextBlock icon, TextBlock label, string text, bool ok, bool bad = false)
    {
        icon.Text = ok ? "\uE73E" : "\uE711";
        icon.Foreground = ok
            ? CsUi.Brush("CsSuccessBrush")
            : CsUi.Brush(bad ? "CsErrorBrush" : "CsOnSurfaceVariantBrush");
        label.Text = text;
        label.Foreground = ok
            ? CsUi.Brush("CsOnSurfaceBrush")
            : CsUi.Brush(bad ? "CsErrorBrush" : "CsOnSurfaceVariantBrush");
    }

    private static void SetReadiness(TextBlock target, string text, bool ok)
    {
        target.Text = text;
        target.Foreground = ok
            ? CsUi.Brush("CsSuccessBrush")
            : CsUi.Brush("CsOnSurfaceVariantBrush");
    }

    private static void FillIpChips(WrapPanel host, IEnumerable<NetworkEndpoint> endpoints)
    {
        host.Children.Clear();
        foreach (var endpoint in endpoints)
        {
            var ip = ConsoleFormat.SafeInline(endpoint.Ip, 64);
            if (ip.Length == 0)
                continue;
            var chip = new Border { Style = CsUi.Style("CsChip"), Margin = new Thickness(0, 8, 8, 0) };
            chip.Child = new TextBlock
            {
                Text = ip,
                FontFamily = CsUi.Font("CsFontMono"),
                FontSize = 12,
                Foreground = CsUi.Brush("CsPrimaryBrush"),
            };
            host.Children.Add(chip);
        }
    }

    private static Border Tile() => new()
    {
        Style = CsUi.Style("CsCard"),
        VerticalAlignment = VerticalAlignment.Stretch,
    };

    private static TextBlock Kicker(string text) => new()
    {
        Text = text,
        Style = CsUi.Style("CsKicker"),
    };

    private static StackPanel StatusRow(out TextBlock icon, out TextBlock label, string text)
    {
        var row = new StackPanel { Orientation = Orientation.Horizontal, Margin = new Thickness(0, 12, 0, 0) };
        icon = CsUi.Icon("\uE73E", 14);
        icon.Width = 16;
        icon.Foreground = CsUi.Brush("CsOnSurfaceVariantBrush");
        label = new TextBlock
        {
            Text = text,
            Margin = new Thickness(8, 0, 0, 0),
            VerticalAlignment = VerticalAlignment.Center,
            FontFamily = CsUi.Font("CsFontUi"),
            FontSize = 13.5,
            Foreground = CsUi.Brush("CsOnSurfaceBrush"),
            TextWrapping = TextWrapping.Wrap,
        };
        row.Children.Add(icon);
        row.Children.Add(label);
        return row;
    }

    private static StackPanel StatBlock(System.Windows.Shapes.Ellipse? pulse, out TextBlock value, string caption)
    {
        var block = new StackPanel();
        var numberRow = new StackPanel { Orientation = Orientation.Horizontal };
        if (pulse != null)
        {
            pulse.Width = 8;
            pulse.Height = 8;
            pulse.Margin = new Thickness(0, 0, 8, 0);
            pulse.VerticalAlignment = VerticalAlignment.Center;
            pulse.Fill = CsUi.Brush("CsOnSurfaceVariantBrush");
            pulse.Opacity = 0.45;
            numberRow.Children.Add(pulse);
        }

        value = new TextBlock
        {
            Text = "-",
            FontFamily = CsUi.Font("CsFontMono"),
            FontSize = 36,
            FontWeight = FontWeights.SemiBold,
            Foreground = CsUi.Brush("CsOnSurfaceBrush"),
        };
        numberRow.Children.Add(value);
        block.Children.Add(numberRow);
        block.Children.Add(new TextBlock
        {
            Text = caption,
            Style = CsUi.Style("CsKicker"),
            TextWrapping = TextWrapping.Wrap,
            Margin = new Thickness(pulse == null ? 0 : 16, 4, 12, 0),
        });
        return block;
    }

    private static StackPanel ReadinessBlock(string title, string glyph, out TextBlock status, out WrapPanel chips)
    {
        var block = new StackPanel { Margin = new Thickness(0, 12, 0, 0) };
        var row = new Grid();
        row.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        row.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        row.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        var icon = CsUi.Icon(glyph, 14);
        icon.Margin = new Thickness(0, 0, 8, 0);
        icon.Foreground = CsUi.Brush("CsPrimaryBrush");
        Grid.SetColumn(icon, 0);
        row.Children.Add(icon);
        var name = new TextBlock
        {
            Text = title,
            FontFamily = CsUi.Font("CsFontUi"),
            FontSize = 13,
            Foreground = CsUi.Brush("CsOnSurfaceBrush"),
            VerticalAlignment = VerticalAlignment.Center,
        };
        Grid.SetColumn(name, 1);
        row.Children.Add(name);
        status = new TextBlock
        {
            Text = "-",
            FontFamily = CsUi.Font("CsFontUi"),
            FontSize = 12,
            FontWeight = FontWeights.SemiBold,
            Foreground = CsUi.Brush("CsOnSurfaceVariantBrush"),
            VerticalAlignment = VerticalAlignment.Center,
        };
        Grid.SetColumn(status, 2);
        row.Children.Add(status);
        block.Children.Add(row);
        chips = new WrapPanel();
        block.Children.Add(chips);
        return block;
    }

    private static System.Windows.Shapes.Ellipse LegendDot(string brushKey)
    {
        return new System.Windows.Shapes.Ellipse
        {
            Width = 8,
            Height = 8,
            Fill = CsUi.Brush(brushKey),
            Margin = new Thickness(0, 0, 6, 0),
            VerticalAlignment = VerticalAlignment.Center,
        };
    }

    private static TextBlock LegendValue(string text) => new()
    {
        Text = text,
        FontFamily = CsUi.Font("CsFontMono"),
        FontSize = 12.5,
        Foreground = CsUi.Brush("CsOnSurfaceBrush"),
        Margin = new Thickness(0, 0, 16, 0),
        VerticalAlignment = VerticalAlignment.Center,
    };
}
