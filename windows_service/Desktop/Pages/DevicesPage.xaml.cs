namespace EndpointMonitorService.Desktop.Pages;

public partial class DevicesPage : UserControl
{
    private readonly AgentDataService _data;
    private StackPanel _listPanel = null!;
    private TextBlock _emptyText = null!;

    public DevicesPage(AgentDataService data)
    {
        _data = data;
        BuildUi();
    }

    private void BuildUi()
    {
        var root = new StackPanel();
        root.Children.Add(new TextBlock { Text = "Devices", Style = (Style)Application.Current.FindResource("CsPageTitle") });

        var card = new Border { Style = (Style)Application.Current.FindResource("CsCard") };
        var inner = new StackPanel();

        _emptyText = new TextBlock
        {
            Style = (Style)Application.Current.FindResource("CsBody"),
            Text = "No paired devices yet. Use the Pair screen to connect your phone.",
            Visibility = Visibility.Collapsed,
        };
        inner.Children.Add(_emptyText);

        _listPanel = new StackPanel();
        inner.Children.Add(_listPanel);

        card.Child = inner;
        root.Children.Add(card);
        Content = root;
    }

    public async Task RefreshAsync()
    {
        var devices = await _data.GetDevicesAsync().ConfigureAwait(true);
        _listPanel.Children.Clear();

        var active = devices.Where(d => !d.Revoked).ToList();
        if (active.Count == 0)
        {
            _emptyText.Visibility = Visibility.Visible;
            return;
        }

        _emptyText.Visibility = Visibility.Collapsed;
        foreach (var device in active)
        {
            var row = new Grid { Margin = new Thickness(0, 0, 0, 12) };
            row.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
            row.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });

            var info = new StackPanel();
            info.Children.Add(new TextBlock
            {
                Text = device.DeviceName,
                Style = (Style)Application.Current.FindResource("CsValue"),
                FontWeight = FontWeights.SemiBold,
            });
            info.Children.Add(new TextBlock
            {
                Text = $"Last used: {FormatDate(device.LastUsedAt)}",
                Style = (Style)Application.Current.FindResource("CsBody"),
                FontSize = 12,
                Margin = new Thickness(0, 2, 0, 0),
            });
            Grid.SetColumn(info, 0);
            row.Children.Add(info);

            var revoke = new Button
            {
                Content = "Revoke",
                Style = (Style)Application.Current.FindResource("CsSecondaryButton"),
                Tag = device.Id,
            };
            revoke.Click += async (_, e) =>
            {
                if (e.Source is not Button btn || btn.Tag is not string id)
                    return;

                var confirm = MessageBox.Show(
                    $"Revoke access for \"{device.DeviceName}\"?",
                    "Confirm revoke",
                    MessageBoxButton.YesNo,
                    MessageBoxImage.Warning);
                if (confirm != MessageBoxResult.Yes)
                    return;

                await _data.RevokeDeviceAsync(id).ConfigureAwait(true);
                await RefreshAsync().ConfigureAwait(true);
            };
            Grid.SetColumn(revoke, 1);
            row.Children.Add(revoke);

            _listPanel.Children.Add(row);
        }
    }

    private static string FormatDate(string iso)
    {
        if (DateTime.TryParse(iso, out var dt))
            return dt.ToLocalTime().ToString("g");
        return iso;
    }
}
