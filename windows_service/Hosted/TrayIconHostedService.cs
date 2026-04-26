using System.Diagnostics;
using System.Drawing;
using System.Windows.Forms;
using EndpointMonitorService;
using EndpointMonitorService.Options;
using EndpointMonitorService.Services;
using Microsoft.Extensions.Options;

namespace EndpointMonitorService.Hosted;

public sealed class TrayIconHostedService(
    ILogger<TrayIconHostedService> logger,
    IHostApplicationLifetime appLifetime,
    IOptions<ServerOptions> serverOptions,
    PairingAuthService pairingAuthService) : IHostedService
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
            var menu = new ContextMenuStrip
            {
                Font = new Font("Segoe UI", 9.25f, FontStyle.Regular, GraphicsUnit.Point),
            };
            menu.Items.Add("Service status", null, (_, _) =>
            {
                var s = serverOptions.Value;
                TrayMessageUi.ShowServiceStatus(s.Port, s.UseHttps, s.HttpsPort);
            });
            menu.Items.Add("Pairing code…", null, (_, _) =>
            {
                try
                {
                    var (code, expiresAtUtc) = pairingAuthService.CreatePairingCode(TimeSpan.FromMinutes(5));
                    TrayMessageUi.ShowPairingCode(code, expiresAtUtc.ToLocalTime());
                }
                catch (InvalidOperationException ex)
                {
                    TrayMessageUi.ShowWarning("Pairing unavailable", ex.Message);
                }
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
            var startWithWindowsItem = new ToolStripMenuItem("Start with Windows (Windows Service)")
            {
                CheckOnClick = false,
            };
            startWithWindowsItem.Click += (_, _) =>
            {
                try
                {
                    var isAuto = WindowsServiceAutorunHelper.IsAutomaticStart();
                    WindowsServiceAutorunHelper.RequestSetAutomaticStart(!isAuto);
                    TrayMessageUi.ShowInfo(
                        "Windows startup",
                        "If a UAC prompt appeared, approve it to apply the change.\n\n" +
                        "The tray checks the real service state when you open this menu again.\n\n" +
                        "Note: the installed service runs without the tray icon. Stop any interactive " +
                        "copy before starting the service if both would use the same HTTP port.");
                }
                catch (InvalidOperationException ex)
                {
                    TrayMessageUi.ShowWarning("Windows startup", ex.Message);
                }
                catch (Exception ex)
                {
                    logger.LogWarning(ex, "Windows startup toggle failed.");
                    TrayMessageUi.ShowWarning(
                        "Windows startup",
                        "Could not start the elevated setup. Run the app as Administrator or see BUILD-SINGLE-EXE.md.");
                }
            };
            menu.Items.Add(startWithWindowsItem);
            menu.Opening += (_, _) =>
            {
                try
                {
                    startWithWindowsItem.Checked = WindowsServiceAutorunHelper.IsAutomaticStart();
                    var canInstall =
                        WindowsServiceAutorunHelper.TryResolveBinaryPathForServiceInstallation() != null;
                    startWithWindowsItem.Enabled =
                        WindowsServiceAutorunHelper.ServiceIsRegistered() || canInstall;
                }
                catch (Exception ex)
                {
                    logger.LogDebug(ex, "Could not refresh Windows startup menu state.");
                    startWithWindowsItem.Enabled = true;
                }
            };
            menu.Items.Add(new ToolStripSeparator());
            menu.Items.Add("Exit", null, (_, _) =>
            {
                logger.LogInformation("Tray exit requested.");
                appLifetime.StopApplication();
                _appContext?.ExitThread();
            });

            _notifyIcon = new NotifyIcon
            {
                Icon = SystemIcons.Application,
                Text = "Endpoint Monitor — right-click for menu",
                Visible = true,
                ContextMenuStrip = menu
            };

            _notifyIcon.DoubleClick += (_, _) =>
            {
                var s = serverOptions.Value;
                TrayMessageUi.ShowServiceStatus(s.Port, s.UseHttps, s.HttpsPort);
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
