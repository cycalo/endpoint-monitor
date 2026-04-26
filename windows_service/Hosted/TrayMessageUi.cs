using System.Drawing;
using System.Windows.Forms;

namespace EndpointMonitorService.Hosted;

/// <summary>Custom tray dialogs to avoid the default system sound from <see cref="MessageBox" />.</summary>
internal static class TrayMessageUi
{
    private const int Edge = 20;
    private static readonly Color Bg = Color.FromArgb(248, 249, 252);
    private static readonly Color Muted = Color.FromArgb(90, 95, 110);
    private static readonly Color TextMain = Color.FromArgb(30, 35, 50);

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

    internal static void ShowServiceStatus(int httpPort, bool useHttps, int httpsPort)
    {
        using var f = Shell("Endpoint Monitor", 420, 200);
        var text = "The service is running.\r\n\r\n" +
                    $"Local HTTP: http://localhost:{httpPort}\r\n" +
                    $"HTTPS: {(useHttps ? $"on (port {httpsPort})" : "off")}\r\n\r\n" +
                    "In the app: enter this PC’s IP, then get a pairing code from this menu.";

        var body = new Label
        {
            Text = text,
            ForeColor = TextMain,
            Font = new Font("Segoe UI", 9.5f, FontStyle.Regular, GraphicsUnit.Point),
            AutoSize = false,
            Size = new Size(380, 120),
            Location = new Point(Edge, Edge),
        };
        var ok = new Button
        {
            Text = "OK",
            DialogResult = DialogResult.OK,
            Location = new Point(Edge, 150),
        };
        f.Controls.Add(body);
        f.Controls.Add(ok);
        f.AcceptButton = ok;
        f.ShowDialog();
    }

    internal static void ShowPairingCode(string code, DateTime expiresAtLocal)
    {
        using var f = Shell("Pairing code", 420, 200);
        var instr = new Label
        {
            Text = "Enter this code in the phone app (Connect).",
            ForeColor = Muted,
            Font = new Font("Segoe UI", 9.25f, FontStyle.Regular, GraphicsUnit.Point),
            AutoSize = false,
            Size = new Size(380, 40),
            Location = new Point(Edge, 16),
        };
        var codeBox = new TextBox
        {
            Text = code,
            ReadOnly = true,
            Font = new Font("Consolas", 20f, FontStyle.Bold, GraphicsUnit.Point),
            Location = new Point(Edge, 58),
            Size = new Size(380, 38),
            BorderStyle = BorderStyle.FixedSingle,
            BackColor = Color.White,
            ForeColor = Color.FromArgb(25, 40, 90),
        };
        var expiry = new Label
        {
            Text = $"Valid until  {expiresAtLocal:HH:mm}  —  {expiresAtLocal:yyyy-MM-dd}",
            ForeColor = Muted,
            Font = new Font("Segoe UI", 8.75f, FontStyle.Regular, GraphicsUnit.Point),
            AutoSize = false,
            Size = new Size(380, 24),
            Location = new Point(Edge, 104),
        };
        var ok = new Button
        {
            Text = "OK",
            DialogResult = DialogResult.OK,
            Location = new Point(Edge, 140),
        };
        f.Controls.Add(instr);
        f.Controls.Add(codeBox);
        f.Controls.Add(expiry);
        f.Controls.Add(ok);
        f.AcceptButton = ok;
        f.ShowDialog();
    }

    internal static void ShowInfo(string title, string message)
    {
        using var f = Shell(title, 420, 200);
        var body = new Label
        {
            Text = message,
            ForeColor = TextMain,
            Font = new Font("Segoe UI", 9.5f, FontStyle.Regular, GraphicsUnit.Point),
            AutoSize = false,
            Size = new Size(380, 120),
            Location = new Point(Edge, Edge),
        };
        var ok = new Button
        {
            Text = "OK",
            DialogResult = DialogResult.OK,
            Location = new Point(Edge, 150),
        };
        f.Controls.Add(body);
        f.Controls.Add(ok);
        f.AcceptButton = ok;
        f.ShowDialog();
    }

    internal static void ShowWarning(string title, string message)
    {
        using var f = Shell(title, 400, 160);
        var body = new Label
        {
            Text = message,
            ForeColor = Color.FromArgb(100, 45, 30),
            Font = new Font("Segoe UI", 9.5f, FontStyle.Regular, GraphicsUnit.Point),
            AutoSize = false,
            Size = new Size(360, 80),
            Location = new Point(Edge, Edge),
        };
        var ok = new Button
        {
            Text = "OK",
            DialogResult = DialogResult.OK,
            Location = new Point(Edge, 100),
        };
        f.Controls.Add(body);
        f.Controls.Add(ok);
        f.AcceptButton = ok;
        f.ShowDialog();
    }
}
