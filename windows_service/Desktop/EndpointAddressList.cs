using EndpointMonitorService.Services;

namespace EndpointMonitorService.Desktop;

internal static class EndpointAddressList
{
    internal static IReadOnlyList<NetworkEndpoint> FromStatus(LocalStatusDto? status)
    {
        if (status == null)
            return [];
        if (status.Endpoints.Length > 0)
            return LocalStatusMapper.FromDtos(status.Endpoints);
        return status.LanIpv4
            .Select(ip => new NetworkEndpoint(ip, "Adapter", NetworkEndpoint.Classify(ip, "")))
            .ToList();
    }

    internal static IReadOnlyList<NetworkEndpoint> FromPairing(LocalPairingDto? pairing)
    {
        if (pairing == null)
            return [];
        if (pairing.Endpoints.Length > 0)
            return LocalStatusMapper.FromDtos(pairing.Endpoints);
        return pairing.LanIpv4
            .Select(ip => new NetworkEndpoint(ip, "Adapter", NetworkEndpoint.Classify(ip, "")))
            .ToList();
    }

    internal static UIElement PathCard(
        string title,
        string subtitle,
        string phoneHint,
        IReadOnlyList<NetworkEndpoint> addresses,
        string emptyText,
        string glyph,
        string accentBrushKey)
    {
        var card = new Border
        {
            Style = (Style)Application.Current.FindResource("CsCard"),
            Margin = new Thickness(0, 0, 12, 12),
            VerticalAlignment = VerticalAlignment.Stretch,
        };
        var inner = new StackPanel();

        var header = new Grid { Margin = new Thickness(0, 0, 0, 10) };
        header.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        header.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        var badge = CsUi.Badge(glyph, accentBrushKey);
        badge.Margin = new Thickness(0, 0, 12, 0);
        badge.VerticalAlignment = VerticalAlignment.Top;
        Grid.SetColumn(badge, 0);
        header.Children.Add(badge);

        var titles = new StackPanel();
        titles.Children.Add(new TextBlock
        {
            Text = title,
            FontFamily = CsUi.Font("CsFontUi"),
            FontSize = 15,
            FontWeight = FontWeights.SemiBold,
            Foreground = CsUi.Brush("CsOnSurfaceBrush"),
            TextWrapping = TextWrapping.Wrap,
        });
        titles.Children.Add(new TextBlock
        {
            Text = subtitle,
            Style = CsUi.Style("CsBody"),
            Margin = new Thickness(0, 4, 0, 0),
        });
        Grid.SetColumn(titles, 1);
        header.Children.Add(titles);
        inner.Children.Add(header);

        if (addresses.Count == 0)
        {
            inner.Children.Add(new TextBlock
            {
                Text = emptyText,
                Style = CsUi.Style("CsBody"),
            });
        }
        else
        {
            var allowCopy = addresses[0].Kind != NetworkEndpointKind.Other;
            foreach (var endpoint in addresses)
                inner.Children.Add(AddressRow(endpoint, allowCopy));
        }

        if (!string.IsNullOrWhiteSpace(phoneHint))
        {
            inner.Children.Add(new TextBlock
            {
                Text = phoneHint,
                Style = CsUi.Style("CsBody"),
                Margin = new Thickness(0, 8, 0, 0),
            });
        }

        card.Child = inner;
        return card;
    }

    internal static UIElement AddressRow(NetworkEndpoint endpoint, bool allowCopy = true)
    {
        var row = new Grid { Margin = new Thickness(0, 0, 0, 8) };
        row.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        row.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });

        var info = new StackPanel();
        info.Children.Add(new TextBlock
        {
            Text = ConsoleFormat.SafeInline(endpoint.Adapter, 80),
            Style = CsUi.Style("CsLabel"),
        });
        info.Children.Add(new TextBlock
        {
            Text = ConsoleFormat.SafeInline(endpoint.Ip, 64),
            FontFamily = CsUi.Font("CsFontMono"),
            FontSize = 14,
            FontWeight = FontWeights.SemiBold,
            Foreground = CsUi.Brush("CsPrimaryBrush"),
        });
        Grid.SetColumn(info, 0);
        row.Children.Add(info);

        if (allowCopy)
        {
            var copy = new Button
            {
                Content = CsUi.Labeled("\uE8C8", "Copy"),
                Style = CsUi.Style("CsSecondaryButton"),
                Tag = endpoint.Ip,
                VerticalAlignment = VerticalAlignment.Center,
                Margin = new Thickness(8, 0, 0, 0),
            };
            copy.Click += (_, _) =>
            {
                if (copy.Tag is string ip)
                    CopyFeedback.CopyFromButton(copy, ip);
            };
            Grid.SetColumn(copy, 1);
            row.Children.Add(copy);
        }

        return row;
    }
}
