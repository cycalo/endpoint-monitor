using System.Windows.Threading;
using EndpointMonitorService.Services;

namespace EndpointMonitorService.Desktop.Pages;

public partial class PairPage : UserControl
{
    private readonly AgentDataService _data;
    private readonly DispatcherTimer _countdown;

    private TextBlock _codeText = null!;
    private TextBlock _expiryText = null!;
    private Border _countdownFill = null!;
    private TextBlock _errorText = null!;
    private StackPanel _pathsHost = null!;
    private DateTime _expiresAtUtc;
    private TimeSpan _ttl = TimeSpan.FromMinutes(5);

    public PairPage(AgentDataService data)
    {
        _data = data;
        _countdown = new DispatcherTimer { Interval = TimeSpan.FromSeconds(1) };
        _countdown.Tick += (_, _) => UpdateCountdown();
        BuildUi();
        Unloaded += (_, _) => _countdown.Stop();
        Loaded += (_, _) =>
        {
            if (_expiresAtUtc != default)
                _countdown.Start();
        };
    }

    private void BuildUi()
    {
        var root = new StackPanel();
        root.Children.Add(new TextBlock { Text = "Pair", Style = (Style)Application.Current.FindResource("CsPageTitle") });
        root.Children.Add(new TextBlock
        {
            Text = "Generate a code and copy the address the phone app should use.",
            Style = (Style)Application.Current.FindResource("CsBody"),
            Margin = new Thickness(0, -8, 0, 16),
        });

        var card = new Border { Style = (Style)Application.Current.FindResource("CsCard"), Margin = new Thickness(0, 0, 0, 12) };
        var inner = new StackPanel();
        inner.Children.Add(new TextBlock
        {
            Text = "Enter this 6-digit code in the phone app on Connect. Same code for This Wi-Fi or Away from home.",
            Style = (Style)Application.Current.FindResource("CsBody"),
            Margin = new Thickness(0, 0, 0, 16),
        });

        _codeText = new TextBlock
        {
            FontFamily = new FontFamily("Consolas"),
            FontSize = 32,
            FontWeight = FontWeights.Bold,
            Foreground = (Brush)Application.Current.FindResource("CsPrimaryBrush"),
            Text = "------",
            HorizontalAlignment = HorizontalAlignment.Center,
            Margin = new Thickness(0, 8, 0, 8),
        };
        inner.Children.Add(_codeText);

        var track = new Border
        {
            Height = 6,
            CornerRadius = new CornerRadius(3),
            Background = (Brush)Application.Current.FindResource("CsSurfaceContainerLowBrush"),
            Margin = new Thickness(0, 4, 0, 8),
            ClipToBounds = true,
        };
        _countdownFill = new Border
        {
            Height = 6,
            CornerRadius = new CornerRadius(3),
            Background = (Brush)Application.Current.FindResource("CsPrimaryBrush"),
            HorizontalAlignment = HorizontalAlignment.Left,
            Width = 0,
        };
        track.Child = _countdownFill;
        track.SizeChanged += (_, _) => UpdateCountdown();
        inner.Children.Add(track);

        _expiryText = new TextBlock
        {
            Style = (Style)Application.Current.FindResource("CsBody"),
            HorizontalAlignment = HorizontalAlignment.Center,
            Text = "",
        };
        inner.Children.Add(_expiryText);

        _errorText = new TextBlock
        {
            Foreground = (Brush)Application.Current.FindResource("CsErrorBrush"),
            FontSize = 12.5,
            TextWrapping = TextWrapping.Wrap,
            Visibility = Visibility.Collapsed,
            Margin = new Thickness(0, 8, 0, 8),
        };
        inner.Children.Add(_errorText);

        var btnRow = new StackPanel { Orientation = Orientation.Horizontal, Margin = new Thickness(0, 8, 0, 0) };
        var copyCode = new Button { Content = "Copy code", Style = (Style)Application.Current.FindResource("CsPrimaryButton"), Margin = new Thickness(0, 0, 8, 0) };
        copyCode.Click += (_, _) => CopyFeedback.CopyFromButton(copyCode, _codeText.Text, "Copied!");
        var newCode = new Button { Content = "New code", Style = (Style)Application.Current.FindResource("CsSecondaryButton") };
        newCode.Click += async (_, _) => await GenerateCodeAsync().ConfigureAwait(true);
        btnRow.Children.Add(copyCode);
        btnRow.Children.Add(newCode);
        inner.Children.Add(btnRow);

        card.Child = inner;
        root.Children.Add(card);

        root.Children.Add(new TextBlock
        {
            Text = "How should the phone reach this PC?",
            FontFamily = new FontFamily("Segoe UI"),
            FontSize = 13,
            FontWeight = FontWeights.SemiBold,
            Foreground = (Brush)Application.Current.FindResource("CsOnSurfaceBrush"),
            Margin = new Thickness(0, 4, 0, 10),
        });

        _pathsHost = new StackPanel();
        root.Children.Add(_pathsHost);
        Content = root;
    }

    public async Task RefreshAsync() => await GenerateCodeAsync().ConfigureAwait(true);

    private async Task GenerateCodeAsync()
    {
        _errorText.Visibility = Visibility.Collapsed;
        var pairing = await _data.CreatePairingAsync().ConfigureAwait(true);
        if (pairing == null || string.IsNullOrEmpty(pairing.Code))
        {
            _countdown.Stop();
            _codeText.Text = "------";
            _expiryText.Text = "";
            _countdownFill.Width = 0;
            _errorText.Text = "Could not generate a pairing code. Check agent configuration.";
            _errorText.Visibility = Visibility.Visible;
            RenderPaths([]);
            return;
        }

        _codeText.Text = pairing.Code;
        _expiresAtUtc = pairing.ExpiresAtUtc.Kind == DateTimeKind.Unspecified
            ? DateTime.SpecifyKind(pairing.ExpiresAtUtc, DateTimeKind.Utc)
            : pairing.ExpiresAtUtc.ToUniversalTime();
        var remaining = _expiresAtUtc - DateTime.UtcNow;
        _ttl = remaining > TimeSpan.Zero ? remaining : TimeSpan.FromMinutes(5);
        _countdown.Start();
        UpdateCountdown();
        RenderPaths(EndpointAddressList.FromPairing(pairing));
    }

    private void RenderPaths(IReadOnlyList<NetworkEndpoint> endpoints)
    {
        _pathsHost.Children.Clear();
        var lan = endpoints.Where(e => e.Kind == NetworkEndpointKind.Lan).ToList();
        var tailscale = endpoints.Where(e => e.Kind == NetworkEndpointKind.Tailscale).ToList();
        var other = endpoints.Where(e => e.Kind == NetworkEndpointKind.Other).ToList();

        _pathsHost.Children.Add(EndpointAddressList.PathCard(
            "This Wi-Fi",
            "Phone and PC on the same Wi-Fi. Fastest first-time setup.",
            "On the phone: Connect → This Wi-Fi. Paste one local address below, then the code.",
            lan,
            "No local Wi-Fi or Ethernet address detected. Check the PC is on Wi-Fi or Ethernet."));

        _pathsHost.Children.Add(EndpointAddressList.PathCard(
            "Away from home",
            "Reach this PC over Tailscale from any network. Both devices must use the same Tailscale account.",
            "On the phone: Connect → Away from home. Paste the 100. address (not a 192.168 address), then the code.",
            tailscale,
            "Tailscale is not connected on this PC. Install Tailscale, sign in, then generate a new code."));

        if (other.Count > 0)
        {
            _pathsHost.Children.Add(EndpointAddressList.PathCard(
                "Other adapters",
                "Virtual switches (Hyper-V, VMware, etc.). Do not enter these in the phone app.",
                "",
                other,
                ""));
        }
    }

    private void UpdateCountdown()
    {
        if (_expiresAtUtc == default)
            return;

        var remaining = _expiresAtUtc - DateTime.UtcNow;
        var track = _countdownFill.Parent as Border;
        var trackWidth = track?.ActualWidth ?? 0;

        if (remaining <= TimeSpan.Zero)
        {
            _countdown.Stop();
            _expiryText.Text = "Code expired — generate a new one.";
            _expiryText.Foreground = (Brush)Application.Current.FindResource("CsErrorBrush");
            _countdownFill.Width = 0;
            _countdownFill.Background = (Brush)Application.Current.FindResource("CsErrorBrush");
            return;
        }

        var label = NetworkEndpoint.FormatRemaining(remaining);
        _expiryText.Text = $"Expires in {label}";
        _expiryText.Foreground = remaining.TotalSeconds <= 30
            ? (Brush)Application.Current.FindResource("CsErrorBrush")
            : (Brush)Application.Current.FindResource("CsOnSurfaceVariantBrush");
        _countdownFill.Background = remaining.TotalSeconds <= 30
            ? (Brush)Application.Current.FindResource("CsErrorBrush")
            : (Brush)Application.Current.FindResource("CsPrimaryBrush");

        var fraction = Math.Clamp(remaining.TotalSeconds / Math.Max(_ttl.TotalSeconds, 1), 0, 1);
        _countdownFill.Width = trackWidth * fraction;
    }
}
