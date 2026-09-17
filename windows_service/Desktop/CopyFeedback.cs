using System.Windows.Threading;

namespace EndpointMonitorService.Desktop;

internal static class CopyFeedback
{
    private static readonly Dictionary<Button, (DispatcherTimer Timer, object OriginalContent)> _active = new();

    internal static bool TryCopy(string? text)
    {
        if (string.IsNullOrWhiteSpace(text) || text == "—")
            return false;

        try
        {
            Clipboard.SetText(text);
            return true;
        }
        catch
        {
            return false;
        }
    }

    internal static void CopyFromButton(Button button, string? text, string copiedLabel = "Copied")
    {
        if (!TryCopy(text))
            return;

        Reset(button);

        var original = button.Content;
        button.Content = copiedLabel;

        var timer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(2) };
        timer.Tick += (_, _) => Reset(button);
        _active[button] = (timer, original);
        timer.Start();
    }

    private static void Reset(Button button)
    {
        if (!_active.TryGetValue(button, out var state))
            return;

        state.Timer.Stop();
        button.Content = state.OriginalContent;
        _active.Remove(button);
    }
}
