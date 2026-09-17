using EndpointMonitorService.Services;

namespace EndpointMonitorService.Desktop;

public readonly record struct HomeNextStep(
    string Title,
    string Body,
    bool ShowPair,
    bool ShowDevices);

/// <summary>Copy and status for the Home tab — health at a glance, not pairing.</summary>
public static class HomeDashboard
{
    public static bool WifiReady(IReadOnlyList<NetworkEndpoint> endpoints) =>
        endpoints.Any(e => e.Kind == NetworkEndpointKind.Lan);

    public static bool TailscaleConnected(IReadOnlyList<NetworkEndpoint> endpoints) =>
        endpoints.Any(e => e.Kind == NetworkEndpointKind.Tailscale);

    public static string WifiStatus(bool ready) => ready ? "Ready" : "Not detected";

    public static string TailscaleStatus(bool connected) => connected ? "Connected" : "Not connected";

    public static HomeNextStep NextStep(bool agentReachable, int pairedCount, int connectedPhones)
    {
        if (!agentReachable)
        {
            return new HomeNextStep(
                "Agent unreachable",
                "Start the Endpoint Monitor Windows service, then return here.",
                ShowPair: false,
                ShowDevices: false);
        }

        if (pairedCount <= 0)
        {
            return new HomeNextStep(
                "Pair a phone",
                "Open Pair to generate a code and copy the address the phone app should use.",
                ShowPair: true,
                ShowDevices: false);
        }

        if (connectedPhones <= 0)
        {
            var body = pairedCount == 1
                ? "1 phone is paired but not connected. Open the app on that phone, or pair another."
                : $"{pairedCount} phones are paired but none are connected. Open the app on a phone, or pair another.";
            return new HomeNextStep(
                "Waiting for a phone",
                body,
                ShowPair: true,
                ShowDevices: true);
        }

        var connected = connectedPhones == 1
            ? "1 phone is connected."
            : $"{connectedPhones} phones are connected.";
        return new HomeNextStep(
            "You're set up",
            $"{connected} Pair another phone any time.",
            ShowPair: true,
            ShowDevices: true);
    }
}
