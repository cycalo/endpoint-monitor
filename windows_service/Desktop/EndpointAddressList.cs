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
        string emptyText)
    {
        var card = new Border { Style = (Style)Application.Current.FindResource("CsCard"), Margin = new Thickness(0, 0, 0, 12) };
        var inner = new StackPanel();
        inner.Children.Add(new TextBlock
        {
            Text = title,
            FontFamily = new FontFamily("Segoe UI"),
            FontSize = 15,
            FontWeight = FontWeights.SemiBold,
            Foreground = (Brush)Application.Current.FindResource("CsOnSurfaceBrush"),
        });
        inner.Children.Add(new TextBlock
        {
            Text = subtitle,
            Style = (Style)Application.Current.FindResource("CsBody"),
            Margin = new Thickness(0, 4, 0, 12),
        });

        if (addresses.Count == 0)
        {
            inner.Children.Add(new TextBlock
            {
                Text = emptyText,
                Style = (Style)Application.Current.FindResource("CsBody"),
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
                Style = (Style)Application.Current.FindResource("CsBody"),
                Margin = new Thickness(0, 12, 0, 0),
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
            Text = endpoint.Adapter,
            Style = (Style)Application.Current.FindResource("CsLabel"),
        });
        info.Children.Add(new TextBlock
        {
            Text = endpoint.Ip,
            FontFamily = new FontFamily("Consolas"),
            FontSize = 15,
            FontWeight = FontWeights.SemiBold,
            Foreground = (Brush)Application.Current.FindResource("CsPrimaryBrush"),
        });
        Grid.SetColumn(info, 0);
        row.Children.Add(info);

        if (allowCopy)
        {
            var copy = new Button
            {
                Content = "Copy",
                Style = (Style)Application.Current.FindResource("CsSecondaryButton"),
                Tag = endpoint.Ip,
                VerticalAlignment = VerticalAlignment.Center,
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
