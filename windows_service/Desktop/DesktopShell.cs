using System.Drawing;
using System.Windows.Forms;
using Microsoft.Extensions.Hosting;

namespace EndpointMonitorService.Desktop;

/// <summary>Runs the WPF desktop console and optional system tray icon.</summary>
public sealed class DesktopShell : IDisposable
{
    private readonly AgentDataService _data;
    private readonly UiSettings _settings;
    private readonly bool _ownsApplication;
    private readonly SingleInstance? _singleInstance;
    private MainWindow? _mainWindow;
    private NotifyIcon? _notifyIcon;
    private Application? _wpfApp;

    private DesktopShell(
        AgentDataService data,
        UiSettings settings,
        bool ownsApplication,
        SingleInstance? singleInstance)
    {
        _data = data;
        _settings = settings;
        _ownsApplication = ownsApplication;
        _singleInstance = singleInstance;
    }

    /// <summary>UI-only mode: agent already running, WPF on main STA thread.</summary>
    internal static void RunUiOnly(int port)
    {
        if (!SingleInstance.TryAcquire(out var singleInstance))
            return;

        var settings = UiSettingsStore.Load();
        using var data = new AgentDataService(port);
        using var shell = new DesktopShell(data, settings, ownsApplication: true, singleInstance);
        shell.RunBlocking();
    }

    /// <summary>In-process mode: WPF on background STA thread while Kestrel runs on main thread.</summary>
    internal static DesktopShell StartInProcess(IServiceProvider services, IHostApplicationLifetime lifetime)
    {
        if (!SingleInstance.TryAcquire(out var singleInstance))
            return new DesktopShell(
                new AgentDataService(services),
                UiSettingsStore.Load(),
                ownsApplication: false,
                singleInstance: null);

        var settings = UiSettingsStore.Load();
        var data = new AgentDataService(services);
        var shell = new DesktopShell(data, settings, ownsApplication: false, singleInstance);

        var uiThread = new Thread(shell.RunBlocking)
        {
            Name = "EndpointMonitorDesktopUI",
            IsBackground = true,
        };
        uiThread.SetApartmentState(ApartmentState.STA);
        uiThread.Start();

        lifetime.ApplicationStopping.Register(() => shell.Dispose());

        return shell;
    }

    private void RunBlocking()
    {
        _wpfApp = Application.Current ?? new Application();
        _wpfApp.ShutdownMode = ShutdownMode.OnMainWindowClose;

        _mainWindow = new MainWindow(_data, _settings);
        _mainWindow.RequestHideToTray += (_, _) => EnsureTrayIcon();
        _mainWindow.RequestExitUi += (_, _) => ShutdownUi();
        _mainWindow.Closed += (_, _) =>
        {
            if (_notifyIcon != null)
            {
                _notifyIcon.Visible = false;
                _notifyIcon.Dispose();
                _notifyIcon = null;
            }
        };

        _singleInstance?.StartActivationListener(() =>
        {
            _wpfApp?.Dispatcher.Invoke(() => _mainWindow?.RestoreFromTray());
        });

        EnsureTrayIcon();
        _wpfApp.Run(_mainWindow);
    }

    private void EnsureTrayIcon()
    {
        if (_notifyIcon != null)
            return;

        var menu = new ContextMenuStrip
        {
            Font = new Font("Segoe UI", 9.25f, System.Drawing.FontStyle.Regular, GraphicsUnit.Point),
        };
        menu.Items.Add("Open Endpoint Monitor", null, (_, _) =>
        {
            _wpfApp?.Dispatcher.Invoke(() => _mainWindow?.RestoreFromTray());
        });
        menu.Items.Add("Pairing code…", null, (_, _) =>
        {
            _wpfApp?.Dispatcher.Invoke(() =>
            {
                _mainWindow?.RestoreFromTray();
                _mainWindow?.NavigateToPair();
            });
        });
        menu.Items.Add(new ToolStripSeparator());
        menu.Items.Add("Exit", null, (_, _) =>
        {
            _wpfApp?.Dispatcher.Invoke(ShutdownUi);
        });

        _notifyIcon = new NotifyIcon
        {
            Icon = SystemIcons.Shield,
            Text = "Endpoint Monitor — right-click for menu",
            Visible = true,
            ContextMenuStrip = menu,
        };
        _notifyIcon.DoubleClick += (_, _) =>
        {
            _wpfApp?.Dispatcher.Invoke(() => _mainWindow?.RestoreFromTray());
        };
    }

    private void ShutdownUi()
    {
        if (_notifyIcon != null)
        {
            _notifyIcon.Visible = false;
            _notifyIcon.Dispose();
            _notifyIcon = null;
        }

        if (_ownsApplication)
        {
            _wpfApp?.Shutdown();
        }
        else
        {
            _mainWindow?.Close();
            _wpfApp?.Dispatcher.InvokeShutdown();
        }
    }

    public void Dispose()
    {
        if (_notifyIcon != null)
        {
            _notifyIcon.Visible = false;
            _notifyIcon.Dispose();
            _notifyIcon = null;
        }

        _singleInstance?.Dispose();
        _data.Dispose();
    }
}
