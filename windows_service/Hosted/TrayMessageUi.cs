using System.Drawing;
using System.Windows.Forms;
using EndpointMonitorService.Services;

namespace EndpointMonitorService.Hosted;

/// <summary>Custom tray dialogs to avoid the default system sound from <see cref="MessageBox" />.</summary>
internal static class TrayMessageUi
{
    private const int Edge = 20;
    private static readonly Color Bg = Color.FromArgb(248, 249, 252);
    private static readonly Color Muted = Color.FromArgb(90, 95, 110);
    private static readonly Color TextMain = Color.FromArgb(30, 35, 50);
    private static readonly Color Accent = Color.FromArgb(25, 40, 90);

    private static Form Shell(string title, int width, int height)
    {
        return new Form
        {
            Text = title,
            FormBorderStyle = FormBorderStyle.FixedDialog,
            MaximizeBox = false,
            MinimizeBox = false,
            StartPosition = FormStartPosition.CenterScreen,
            ShowInTaskbar = false,
            BackColor = Bg,
            ClientSize = new Size(width, height),
        };
    }

    internal static void ShowServiceStatus(AgentDiagnostics diag, IReadOnlyList<string> lanIps)
    {
        var lan = LocalNetworkHelper.FormatLanAddressesForDisplay(lanIps);
        var httpsLine = diag.UseHttps ? $"on (port {diag.HttpsPort})" : "off";
        var text =
            "The agent is running.\r\n\r\n" +
            $"Version: {diag.Version}\r\n" +
            $"HTTP: http://localhost:{diag.HttpPort}\r\n" +
            $"HTTPS: {httpsLine}\r\n\r\n" +
            "LAN IPv4 (use in the phone app):\r\n" +
            lan + "\r\n\r\n" +
            $"WebSocket clients: {diag.WebSocketClients}\r\n" +
            $"Administrator: {(diag.RunningAsAdministrator ? "yes" : "no")}\r\n" +
            $"Interactive session: {(diag.InteractiveSession ? "yes" : "no")}\r\n\r\n" +
            "Get a pairing code from this menu, or open the local pairing page in a browser on this PC.";

        using var f = Shell("Endpoint Monitor", 460, 360);
        var body = BodyLabel(text, 400, 250);
        body.Location = new Point(Edge, Edge);

        var copyIp = new Button
        {
            Text = "Copy first LAN IP",
            Location = new Point(Edge, 278),
            AutoSize = true,
            Enabled = lanIps.Count > 0,
        };
        copyIp.Click += (_, _) => TryCopy(lanIps[0]);

        var ok = OkButton(318);
        f.Controls.Add(body);
        f.Controls.Add(copyIp);
        f.Controls.Add(ok);
        f.AcceptButton = ok;
        f.ShowDialog();
    }

    internal static void ShowDiagnostics(AgentDiagnostics diag)
    {
        var intel = diag.ThreatIntelEnabled
            ? $"enabled · {diag.ThreatIntelEntryCount} entries · last run {diag.ThreatIntelLastRunUtc ?? "never"}"
            : "disabled";
        if (!string.IsNullOrEmpty(diag.ThreatIntelLastError) && diag.ThreatIntelLastError != "disabled")
            intel += $"\r\nLast error: {diag.ThreatIntelLastError}";

        var text =
            $"Version: {diag.Version}\r\n" +
            $"Data folder: {diag.DataDirectory}\r\n" +
            $"HTTP port: {diag.HttpPort}\r\n" +
            $"HTTPS: {(diag.UseHttps ? diag.HttpsPort.ToString() : "off")}\r\n" +
            $"WebSocket clients: {diag.WebSocketClients}\r\n" +
            $"Sysmon: {(diag.SysmonInstalled ? "installed" : "not detected")}\r\n" +
            $"Threat intel: {intel}\r\n" +
            $"Administrator: {(diag.RunningAsAdministrator ? "yes" : "no")}\r\n" +
            $"Interactive session: {(diag.InteractiveSession ? "yes" : "no")}";

        using var f = Shell("Diagnostics", 480, 320);
        var body = BodyLabel(text, 420, 220);
        body.Location = new Point(Edge, Edge);
        var ok = OkButton(248);
        f.Controls.Add(body);
        f.Controls.Add(ok);
        f.AcceptButton = ok;
        f.ShowDialog();
    }

    internal static void ShowPairingCode(string code, DateTime expiresAtLocal, IReadOnlyList<string> lanIps)
    {
        using var f = Shell("Pairing code", 460, 248);
        var instr = new Label
        {
            Text = "Enter this code in the phone app (Connect).",
            ForeColor = Muted,
            Font = new Font("Segoe UI", 9.25f, FontStyle.Regular, GraphicsUnit.Point),
            AutoSize = false,
            Size = new Size(400, 22),
            Location = new Point(Edge, 16),
        };
        var codeBox = new TextBox
        {
            Text = code,
            ReadOnly = true,
            Font = new Font("Consolas", 20f, FontStyle.Bold, GraphicsUnit.Point),
            Location = new Point(Edge, 44),
            Size = new Size(400, 38),
            BorderStyle = BorderStyle.FixedSingle,
            BackColor = Color.White,
            ForeColor = Accent,
        };
        var expiry = new Label
        {
            Text = $"Valid until  {expiresAtLocal:HH:mm}  —  {expiresAtLocal:yyyy-MM-dd}",
            ForeColor = Muted,
            Font = new Font("Segoe UI", 8.75f, FontStyle.Regular, GraphicsUnit.Point),
            AutoSize = false,
            Size = new Size(400, 20),
            Location = new Point(Edge, 90),
        };
        var lanHint = new Label
        {
            Text = lanIps.Count > 0
                ? $"Phone IP: {lanIps[0]}{(lanIps.Count > 1 ? $" (+{lanIps.Count - 1} more)" : "")}"
                : "Phone IP: detect LAN address in network settings",
            ForeColor = Muted,
            Font = new Font("Segoe UI", 8.75f, FontStyle.Regular, GraphicsUnit.Point),
            AutoSize = false,
            Size = new Size(400, 20),
            Location = new Point(Edge, 112),
        };
        var copyCode = new Button
        {
            Text = "Copy code",
            Location = new Point(Edge, 144),
            AutoSize = true,
        };
        copyCode.Click += (_, _) => TryCopy(code);

        var copyIp = new Button
        {
            Text = "Copy LAN IP",
            Location = new Point(120, 144),
            AutoSize = true,
            Enabled = lanIps.Count > 0,
        };
        copyIp.Click += (_, _) => TryCopy(lanIps[0]);

        var ok = OkButton(188);
        f.Controls.Add(instr);
        f.Controls.Add(codeBox);
        f.Controls.Add(expiry);
        f.Controls.Add(lanHint);
        f.Controls.Add(copyCode);
        f.Controls.Add(copyIp);
        f.Controls.Add(ok);
        f.AcceptButton = ok;
        f.ShowDialog();
    }

    internal static void ShowInfo(string title, string message)
    {
        using var f = Shell(title, 420, 200);
        var body = BodyLabel(message, 380, 120);
        body.Location = new Point(Edge, Edge);
        var ok = OkButton(150);
        f.Controls.Add(body);
        f.Controls.Add(ok);
        f.AcceptButton = ok;
        f.ShowDialog();
    }

    internal static void ShowWarning(string title, string message)
    {
        using var f = Shell(title, 400, 160);
        var body = BodyLabel(message, 360, 80, Color.FromArgb(100, 45, 30));
        body.Location = new Point(Edge, Edge);
        var ok = OkButton(100);
        f.Controls.Add(body);
        f.Controls.Add(ok);
        f.AcceptButton = ok;
        f.ShowDialog();
    }

    private static Label BodyLabel(string text, int width, int height, Color? fore = null) =>
        new()
        {
            Text = text,
            ForeColor = fore ?? TextMain,
            Font = new Font("Segoe UI", 9.5f, FontStyle.Regular, GraphicsUnit.Point),
            AutoSize = false,
            Size = new Size(width, height),
        };

    private static Button OkButton(int top) =>
        new()
        {
            Text = "OK",
            DialogResult = DialogResult.OK,
            Location = new Point(Edge, top),
        };

    private static void TryCopy(string text)
    {
        try
        {
            Clipboard.SetText(text);
        }
        catch
        {
            // clipboard may be unavailable
        }
    }
}
