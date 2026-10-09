using System.Windows.Controls.Primitives;

namespace EndpointMonitorService.Desktop.Pages;

public partial class DevicesPage : UserControl
{
    private readonly AgentDataService _data;
    private UniformGrid _listPanel = null!;
    private Border _emptyCard = null!;

    public DevicesPage(AgentDataService data)
    {
        _data = data;
        BuildUi();
    }

    private void BuildUi()
    {
        var root = new StackPanel();
        root.Children.Add(new TextBlock { Text = "Devices", Style = CsUi.Style("CsPageTitle") });
        root.Children.Add(new TextBlock
        {
            Text = "Phones that have paired with this PC.",
            Style = CsUi.Style("CsBody"),
            Margin = new Thickness(0, 0, 0, 16),
        });

        _emptyCard = new Border
        {
            Style = CsUi.Style("CsCard"),
            MaxWidth = 520,
            HorizontalAlignment = HorizontalAlignment.Left,
            Visibility = Visibility.Visible,
            Child = new TextBlock
            {
                Style = CsUi.Style("CsBody"),
                Text = "No paired devices yet. Use the Pair screen to connect your phone.",
            },
        };
        root.Children.Add(_emptyCard);

        _listPanel = new UniformGrid { Columns = 2 };
        root.Children.Add(_listPanel);
        Content = root;
    }

    public async Task RefreshAsync(LocalStatusDto? status)
    {
        var devices = await _data.GetDevicesAsync().ConfigureAwait(true);
        var live = (status?.LiveClients ?? [])
            .Where(c => !string.IsNullOrWhiteSpace(c.DeviceId))
            .GroupBy(c => c.DeviceId, StringComparer.OrdinalIgnoreCase)
            .ToDictionary(g => g.Key, g => ConsoleFormat.SafeInline(g.First().RemoteIp, 64), StringComparer.OrdinalIgnoreCase);

        _listPanel.Children.Clear();
        var active = devices.Where(d => !d.Revoked).ToList();
        if (active.Count == 0)
        {
            _emptyCard.Visibility = Visibility.Visible;
            return;
        }

        _emptyCard.Visibility = Visibility.Collapsed;
        foreach (var device in active)
        {
            var isLive = ConsoleFormat.IsLiveSession(device.Id, live.Keys);
            var remoteIp = live.TryGetValue(device.Id, out var ip) ? ip : "";
            _listPanel.Children.Add(DeviceCard(device, isLive, remoteIp));
        }
    }

    private Border DeviceCard(LocalDeviceDto device, bool isLive, string remoteIp)
    {
        var platform = ConsoleFormat.PlatformOf(device.DeviceName);
        var card = new Border
        {
            Style = CsUi.Style("CsCard"),
            Margin = new Thickness(0, 0, 12, 12),
            VerticalAlignment = VerticalAlignment.Stretch,
        };
        var inner = new Grid();
        inner.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        inner.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        inner.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });
        inner.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });

        var header = new Grid();
        header.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        header.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        var badge = CsUi.Badge(PlatformGlyph(platform), PlatformBrush(platform));
        badge.Margin = new Thickness(0, 0, 12, 0);
        badge.VerticalAlignment = VerticalAlignment.Top;
        Grid.SetColumn(badge, 0);
        header.Children.Add(badge);

        var titles = new StackPanel();
        titles.Children.Add(new TextBlock
        {
            Text = ConsoleFormat.SafeInline(device.DeviceName, 128),
            Style = CsUi.Style("CsValue"),
            FontWeight = FontWeights.SemiBold,
            FontSize = 15,
        });
        titles.Children.Add(new TextBlock
        {
            Text = ConsoleFormat.PlatformLabel(platform),
            Style = CsUi.Style("CsKicker"),
            Margin = new Thickness(0, 2, 0, 0),
        });
        Grid.SetColumn(titles, 1);
        header.Children.Add(titles);
        Grid.SetRow(header, 0);
        inner.Children.Add(header);

        var session = new Border
        {
            Style = CsUi.Style("CsStatusPill"),
            Margin = new Thickness(0, 12, 0, 0),
            Background = isLive
                ? new SolidColorBrush(Color.FromArgb(0x33, 0x34, 0xD3, 0x99))
                : CsUi.Brush("CsSurfaceContainerLowBrush"),
            Child = new TextBlock
            {
                Text = isLive ? "Active session" : "Paired / offline",
                FontSize = 12,
                FontWeight = FontWeights.SemiBold,
                Foreground = isLive ? CsUi.Brush("CsSuccessBrush") : CsUi.Brush("CsOnSurfaceVariantBrush"),
            },
        };
        Grid.SetRow(session, 1);
        inner.Children.Add(session);

        var meta = new StackPanel { Margin = new Thickness(0, 12, 0, 0) };
        meta.Children.Add(MetaLine("Last used", FormatDate(device.LastUsedAt)));
        meta.Children.Add(MetaLine("Paired", FormatDate(device.CreatedAt)));
        if (remoteIp.Length > 0)
            meta.Children.Add(MetaLine("Client IP", remoteIp));
        Grid.SetRow(meta, 2);
        inner.Children.Add(meta);

        var revoke = new Button
        {
            Content = "Revoke",
            Style = CsUi.Style("CsSecondaryButton"),
            HorizontalAlignment = HorizontalAlignment.Left,
            Margin = new Thickness(0, 14, 0, 0),
            Tag = device.Id,
        };
        revoke.Click += async (_, e) =>
        {
            if (e.Source is not Button btn || btn.Tag is not string id)
                return;

            var name = ConsoleFormat.SafeInline(device.DeviceName, 128);
            var confirm = MessageBox.Show(
                $"Revoke access for \"{name}\"?",
                "Confirm revoke",
                MessageBoxButton.YesNo,
                MessageBoxImage.Warning);
            if (confirm != MessageBoxResult.Yes)
                return;

            await _data.RevokeDeviceAsync(id).ConfigureAwait(true);
            var latest = await _data.GetStatusAsync().ConfigureAwait(true);
            await RefreshAsync(latest).ConfigureAwait(true);
        };
        Grid.SetRow(revoke, 3);
        inner.Children.Add(revoke);
        card.Child = inner;
        return card;
    }

    private static TextBlock MetaLine(string label, string value)
    {
        var shown = ConsoleFormat.SafeInline(value, 80);
        return new TextBlock
        {
            Margin = new Thickness(0, 2, 0, 0),
            FontSize = 12,
            TextWrapping = TextWrapping.Wrap,
            Inlines =
            {
                new System.Windows.Documents.Run(label + "  ")
                {
                    Foreground = CsUi.Brush("CsOnSurfaceVariantBrush"),
                    FontFamily = CsUi.Font("CsFontUi"),
                },
                new System.Windows.Documents.Run(shown.Length == 0 ? "-" : shown)
                {
                    Foreground = CsUi.Brush("CsOnSurfaceBrush"),
                    FontFamily = CsUi.Font("CsFontMono"),
                },
            },
        };
    }

    private static string PlatformGlyph(DevicePlatform platform) => platform switch
    {
        DevicePlatform.Windows => "\uE977",
        _ => "\uE717",
    };

    private static string PlatformBrush(DevicePlatform platform) => platform switch
    {
        DevicePlatform.Android => "CsPrimaryBrush",
        DevicePlatform.Ios => "CsOnSurfaceBrush",
        DevicePlatform.Windows => "CsTertiaryBrush",
        _ => "CsOnSurfaceVariantBrush",
    };

    private static string FormatDate(string iso)
    {
        if (DateTime.TryParse(iso, out var dt))
            return dt.ToLocalTime().ToString("yyyy-MM-dd HH:mm");
        return ConsoleFormat.SafeInline(iso, 40);
    }
}
