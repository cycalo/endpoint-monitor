using System.Drawing;
using System.Diagnostics;
using System.Windows.Forms;
using EndpointMonitorService.Options;
using Microsoft.Extensions.Options;

namespace EndpointMonitorService.Hosted;

public sealed class TrayIconHostedService(
    ILogger<TrayIconHostedService> logger,
    IHostApplicationLifetime appLifetime,
    IOptions<ServerOptions> serverOptions) : IHostedService
{
    private Thread? _uiThread;
    private NotifyIcon? _notifyIcon;
    private ApplicationContext? _appContext;

    public Task StartAsync(CancellationToken cancellationToken)
    {
        if (!Environment.UserInteractive)
        {
            logger.LogInformation("Skipping tray icon: non-interactive session.");
            return Task.CompletedTask;
        }

        _uiThread = new Thread(() =>
        {
            _appContext = new ApplicationContext();
            var menu = new ContextMenuStrip();
            menu.Items.Add("Show status", null, (_, _) =>
            {
                var server = serverOptions.Value;
                var httpUrl = $"http://localhost:{server.Port}";
                var httpsState = server.UseHttps
                    ? $"Enabled on https://localhost:{server.HttpsPort}"
                    : "Disabled";
                var status = $"Service is running.{Environment.NewLine}{Environment.NewLine}" +
                             $"HTTP: {httpUrl}{Environment.NewLine}" +
                             $"HTTPS: {httpsState}";
                MessageBox.Show(
                    status,
                    "Endpoint Monitor Status",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Information);
            });
            menu.Items.Add("Open logs folder", null, (_, _) =>
            {
                try
                {
                    var logDir = Path.Combine(
                        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                        "EndpointMonitor");
                    Directory.CreateDirectory(logDir);
                    Process.Start(new ProcessStartInfo
                    {
                        FileName = logDir,
                        UseShellExecute = true
                    });
                }
                catch (Exception ex)
                {
                    logger.LogWarning(ex, "Unable to open logs folder from tray menu.");
                }
            });
            menu.Items.Add(new ToolStripSeparator());
            menu.Items.Add("Exit service", null, (_, _) =>
            {
                logger.LogInformation("Tray exit requested.");
                appLifetime.StopApplication();
                _appContext?.ExitThread();
            });

            _notifyIcon = new NotifyIcon
            {
                Icon = SystemIcons.Application,
                Text = "Endpoint Monitor Service",
                Visible = true,
                ContextMenuStrip = menu
            };

            _notifyIcon.DoubleClick += (_, _) =>
            {
                _notifyIcon.BalloonTipTitle = "Endpoint Monitor";
                _notifyIcon.BalloonTipText = "Service is running.";
                _notifyIcon.ShowBalloonTip(1500);
            };

            appLifetime.ApplicationStopping.Register(() =>
            {
                if (_notifyIcon != null)
                {
                    _notifyIcon.Visible = false;
                    _notifyIcon.Dispose();
                }

                _appContext?.ExitThread();
            });

            Application.Run(_appContext);
        })
        {
            Name = "EndpointMonitorTrayUI",
            IsBackground = true
        };
        _uiThread.SetApartmentState(ApartmentState.STA);
        _uiThread.Start();

        logger.LogInformation("System tray icon started.");
        return Task.CompletedTask;
    }

    public Task StopAsync(CancellationToken cancellationToken)
    {
        try
        {
            if (_notifyIcon != null)
            {
                _notifyIcon.Visible = false;
                _notifyIcon.Dispose();
                _notifyIcon = null;
            }

            _appContext?.ExitThread();
        }
        catch (Exception ex)
        {
            logger.LogDebug(ex, "Error while stopping tray icon.");
        }

        return Task.CompletedTask;
    }
}
