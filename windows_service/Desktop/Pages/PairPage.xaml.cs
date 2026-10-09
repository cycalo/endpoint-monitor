using System.IO;
using System.Windows.Controls.Primitives;
using System.Windows.Media.Imaging;
using System.Windows.Threading;
using EndpointMonitorService.Services;
using QRCoder;

namespace EndpointMonitorService.Desktop.Pages;

public partial class PairPage : UserControl
{
    private readonly AgentDataService _data;
    private readonly DispatcherTimer _countdown;

    private StackPanel _digits = null!;
    private CountdownRing _ring = null!;
    private TextBlock _expiryText = null!;
    private TextBlock _errorText = null!;
    private UniformGrid _pathsHost = null!;
    private System.Windows.Controls.Image _qrImage = null!;
    private Border _qrFrame = null!;
    private Border _qrQuiet = null!;
    private TextBlock _qrPlaceholder = null!;
    private string _code = "";
    private bool _digitsExpired;
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
        root.Children.Add(new TextBlock { Text = "Pair", Style = CsUi.Style("CsPageTitle") });
        root.Children.Add(new TextBlock
        {
            Text = "Generate a code and copy the address the phone app should use.",
            Style = CsUi.Style("CsBody"),
            Margin = new Thickness(0, 0, 0, 16),
        });

        var card = new Border { Style = CsUi.Style("CsCard"), Margin = new Thickness(0, 0, 0, 16) };
        var inner = new StackPanel();
        inner.Children.Add(new TextBlock
        {
            Text = "Scan the QR in the phone app after choosing This Wi-Fi or Away from home. The same QR works for both - the phone uses the matching address. You can also type the 6-digit code.",
            Style = CsUi.Style("CsBody"),
            Margin = new Thickness(0, 0, 0, 16),
        });

        var codeRow = new Grid();
        codeRow.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        codeRow.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });

        _qrImage = new System.Windows.Controls.Image
        {
            Width = 168,
            Height = 168,
            Stretch = Stretch.Uniform,
        };
        RenderOptions.SetBitmapScalingMode(_qrImage, BitmapScalingMode.NearestNeighbor);
        _qrQuiet = new Border
        {
            Background = System.Windows.Media.Brushes.White,
            CornerRadius = new CornerRadius(10),
            Padding = new Thickness(10),
            Child = _qrImage,
            Visibility = Visibility.Collapsed,
        };
        _qrPlaceholder = new TextBlock
        {
            Text = "QR appears with a code",
            Style = CsUi.Style("CsBody"),
            HorizontalAlignment = HorizontalAlignment.Center,
            VerticalAlignment = VerticalAlignment.Center,
            TextAlignment = TextAlignment.Center,
            Width = 140,
        };
        var frameHost = new Grid { MinWidth = 200, MinHeight = 200 };
        frameHost.Children.Add(_qrPlaceholder);
        frameHost.Children.Add(_qrQuiet);
        _qrFrame = new Border
        {
            Padding = new Thickness(16),
            CornerRadius = new CornerRadius(16),
            Background = CsUi.Brush("CsSurfaceContainerLowBrush"),
            BorderBrush = CsUi.Brush("CsGhostBorderBrush"),
            BorderThickness = new Thickness(1),
            Child = frameHost,
            VerticalAlignment = VerticalAlignment.Top,
            HorizontalAlignment = HorizontalAlignment.Left,
            Margin = new Thickness(0, 0, 24, 0),
        };
        Grid.SetColumn(_qrFrame, 0);
        codeRow.Children.Add(_qrFrame);

        var codeColumn = new StackPanel { VerticalAlignment = VerticalAlignment.Center };
        Grid.SetColumn(codeColumn, 1);
        codeColumn.Children.Add(new TextBlock
        {
            Text = "Pairing code",
            Style = CsUi.Style("CsKicker"),
            Margin = new Thickness(0, 0, 0, 8),
        });
        _digits = new StackPanel { Orientation = Orientation.Horizontal, Margin = new Thickness(0, 0, 0, 16) };
        codeColumn.Children.Add(_digits);
        RenderDigits("", expired: false);

        var timerRow = new StackPanel { Orientation = Orientation.Horizontal, Margin = new Thickness(0, 0, 0, 8) };
        _ring = new CountdownRing { VerticalAlignment = VerticalAlignment.Center };
        _ring.SetProgress(0, "--:--", warning: false);
        timerRow.Children.Add(_ring);
        _expiryText = new TextBlock
        {
            Style = CsUi.Style("CsBody"),
            VerticalAlignment = VerticalAlignment.Center,
            Margin = new Thickness(14, 0, 0, 0),
            Text = "Generate a code to start the timer.",
        };
        timerRow.Children.Add(_expiryText);
        codeColumn.Children.Add(timerRow);

        var btnRow = new StackPanel { Orientation = Orientation.Horizontal, Margin = new Thickness(0, 8, 0, 0) };
        var copyCode = new Button
        {
            Content = CsUi.Labeled("\uE8C8", "Copy code"),
            Style = CsUi.Style("CsPrimaryButton"),
            Margin = new Thickness(0, 0, 8, 0),
        };
        copyCode.Click += (_, _) =>
        {
            if (_code.Length == 6 && _code.All(char.IsDigit))
                CopyFeedback.CopyFromButton(copyCode, _code, "Copied!");
        };
        var newCode = new Button
        {
            Content = CsUi.Labeled("\uE72C", "New code"),
            Style = CsUi.Style("CsSecondaryButton"),
        };
        newCode.Click += async (_, _) => await GenerateCodeAsync().ConfigureAwait(true);
        btnRow.Children.Add(copyCode);
        btnRow.Children.Add(newCode);
        codeColumn.Children.Add(btnRow);
        codeRow.Children.Add(codeColumn);
        inner.Children.Add(codeRow);

        _errorText = new TextBlock
        {
            Foreground = CsUi.Brush("CsErrorBrush"),
            FontSize = 12.5,
            TextWrapping = TextWrapping.Wrap,
            Visibility = Visibility.Collapsed,
            Margin = new Thickness(0, 12, 0, 0),
        };
        inner.Children.Add(_errorText);
        card.Child = inner;
        root.Children.Add(card);

        root.Children.Add(new TextBlock
        {
            Text = "How should the phone reach this PC?",
            FontFamily = CsUi.Font("CsFontUi"),
            FontSize = 15,
            FontWeight = FontWeights.SemiBold,
            Foreground = CsUi.Brush("CsOnSurfaceBrush"),
            Margin = new Thickness(0, 0, 0, 12),
        });

        _pathsHost = new UniformGrid { Columns = 2 };
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
            _code = "";
            _digitsExpired = false;
            RenderDigits("", expired: false);
            _expiryText.Text = "";
            _ring.SetProgress(0, "0:00", warning: true);
            _errorText.Text = "Could not generate a pairing code. Check agent configuration.";
            _errorText.Visibility = Visibility.Visible;
            ClearQrImage();
            RenderPaths([]);
            return;
        }

        _code = ConsoleFormat.SafeInline(pairing.Code, 12);
        _digitsExpired = false;
        RenderDigits(_code, expired: false);
        _expiresAtUtc = pairing.ExpiresAtUtc.Kind == DateTimeKind.Unspecified
            ? DateTime.SpecifyKind(pairing.ExpiresAtUtc, DateTimeKind.Utc)
            : pairing.ExpiresAtUtc.ToUniversalTime();
        var remaining = _expiresAtUtc - DateTime.UtcNow;
        _ttl = remaining > TimeSpan.Zero ? remaining : TimeSpan.FromMinutes(5);
        _countdown.Start();
        UpdateCountdown();
        var endpoints = EndpointAddressList.FromPairing(pairing);
        UpdateQrImage(PairingQrPayload.BuildUri(pairing.Code, _expiresAtUtc, endpoints, pairing.HttpPort));
        RenderPaths(endpoints);
    }

    private void RenderDigits(string code, bool expired)
    {
        _digits.Children.Clear();
        var shown = string.IsNullOrEmpty(code) ? "------" : code;
        var foreground = expired ? CsUi.Brush("CsErrorBrush") : CsUi.Brush("CsPrimaryBrush");
        foreach (var ch in shown)
        {
            _digits.Children.Add(new Border
            {
                Width = 44,
                Height = 56,
                Margin = new Thickness(0, 0, 8, 0),
                CornerRadius = new CornerRadius(8),
                Background = CsUi.Brush("CsSurfaceContainerLowBrush"),
                BorderBrush = CsUi.Brush("CsGhostBorderBrush"),
                BorderThickness = new Thickness(1),
                Child = new TextBlock
                {
                    Text = ch.ToString(),
                    FontFamily = CsUi.Font("CsFontMono"),
                    FontSize = 26,
                    FontWeight = FontWeights.SemiBold,
                    Foreground = foreground,
                    HorizontalAlignment = HorizontalAlignment.Center,
                    VerticalAlignment = VerticalAlignment.Center,
                },
            });
        }
    }

    private void UpdateQrImage(string uri)
    {
        try
        {
            using var generator = new QRCodeGenerator();
            using var data = generator.CreateQrCode(uri, QRCodeGenerator.ECCLevel.M);
            var png = new PngByteQRCode(data).GetGraphic(4);
            using var stream = new MemoryStream(png);
            var bitmap = new BitmapImage();
            bitmap.BeginInit();
            bitmap.CacheOption = BitmapCacheOption.OnLoad;
            bitmap.StreamSource = stream;
            bitmap.EndInit();
            bitmap.Freeze();
            _qrImage.Source = bitmap;
            _qrQuiet.Visibility = Visibility.Visible;
            _qrPlaceholder.Visibility = Visibility.Collapsed;
            _qrFrame.Opacity = 1;
        }
        catch
        {
            ClearQrImage();
        }
    }

    private void ClearQrImage()
    {
        _qrImage.Source = null;
        _qrQuiet.Visibility = Visibility.Collapsed;
        _qrPlaceholder.Visibility = Visibility.Visible;
        _qrFrame.Opacity = 1;
    }

    private void RenderPaths(IReadOnlyList<NetworkEndpoint> endpoints)
    {
        _pathsHost.Children.Clear();
        var lan = endpoints.Where(e => e.Kind == NetworkEndpointKind.Lan).ToList();
        var tailscale = endpoints.Where(e => e.Kind == NetworkEndpointKind.Tailscale).ToList();
        var other = endpoints.Where(e => e.Kind == NetworkEndpointKind.Other).ToList();

        var cards = new List<UIElement>
        {
            EndpointAddressList.PathCard(
                "This Wi-Fi",
                "Phone and PC on the same Wi-Fi. Fastest first-time setup.",
                "On the phone: Connect → This Wi-Fi. Scan the QR, or paste one local address below and the code.",
                lan,
                "No local Wi-Fi or Ethernet address detected. Check the PC is on Wi-Fi or Ethernet.",
                "\uE701",
                "CsPrimaryBrush"),
            EndpointAddressList.PathCard(
                "Away from home",
                "Reach this PC over Tailscale from any network. Both devices must use the same Tailscale account.",
                "On the phone: Connect → Away from home. Scan the QR, or paste the 100. address and the code.",
                tailscale,
                "Tailscale is not connected on this PC. Install Tailscale, sign in, then generate a new code.",
                "\uE72E",
                "CsTertiaryBrush"),
        };

        if (other.Count > 0)
        {
            cards.Add(EndpointAddressList.PathCard(
                "Other adapters",
                "Virtual switches (Hyper-V, VMware, etc.). Do not enter these in the phone app.",
                "",
                other,
                "",
                "\uE839",
                "CsOnSurfaceVariantBrush"));
        }

        _pathsHost.Columns = cards.Count >= 3 ? 3 : Math.Max(1, cards.Count);
        foreach (var card in cards)
            _pathsHost.Children.Add(card);
    }

    private void UpdateCountdown()
    {
        if (_expiresAtUtc == default)
            return;

        var remaining = _expiresAtUtc - DateTime.UtcNow;
        if (remaining <= TimeSpan.Zero)
        {
            _countdown.Stop();
            _expiryText.Text = "Code expired - generate a new one.";
            _expiryText.Foreground = CsUi.Brush("CsErrorBrush");
            _ring.SetProgress(0, "0:00", warning: true);
            if (!_digitsExpired)
            {
                _digitsExpired = true;
                RenderDigits(_code, expired: true);
            }

            ClearQrImage();
            return;
        }

        var fraction = Math.Clamp(remaining.TotalSeconds / Math.Max(_ttl.TotalSeconds, 1), 0, 1);
        var warning = remaining.TotalSeconds <= 30;
        _ring.SetProgress(fraction, NetworkEndpoint.FormatRemaining(remaining), warning);
        _expiryText.Text = warning ? "Expiring soon" : "Time remaining";
        _expiryText.Foreground = warning
            ? CsUi.Brush("CsErrorBrush")
            : CsUi.Brush("CsOnSurfaceVariantBrush");
        if (_digitsExpired)
        {
            _digitsExpired = false;
            RenderDigits(_code, expired: false);
        }
    }
}
