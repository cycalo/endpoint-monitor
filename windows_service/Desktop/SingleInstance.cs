using System.IO.Pipes;
using System.Threading;

namespace EndpointMonitorService.Desktop;

/// <summary>Ensures only one desktop UI instance; signals an existing window to restore.</summary>
internal sealed class SingleInstance : IDisposable
{
    private const string MutexName = @"Local\EndpointMonitor.DesktopUi";
    private const string PipeName = "EndpointMonitor.DesktopUi.Activate";

    private readonly Mutex _mutex;
    private readonly bool _ownsMutex;
    private CancellationTokenSource? _pipeCts;
    private Thread? _pipeThread;

    private SingleInstance(Mutex mutex, bool ownsMutex)
    {
        _mutex = mutex;
        _ownsMutex = ownsMutex;
    }

    internal static bool TryAcquire(out SingleInstance? instance)
    {
        var mutex = new Mutex(true, MutexName, out var createdNew);
        if (!createdNew)
        {
            SignalExistingInstance();
            mutex.Dispose();
            instance = null;
            return false;
        }

        instance = new SingleInstance(mutex, true);
        return true;
    }

    internal void StartActivationListener(Action onActivate)
    {
        _pipeCts = new CancellationTokenSource();
        var token = _pipeCts.Token;
        _pipeThread = new Thread(() => ListenForActivation(onActivate, token))
        {
            IsBackground = true,
            Name = "EndpointMonitor.ActivatePipe",
        };
        _pipeThread.Start();
    }

    private static void SignalExistingInstance()
    {
        try
        {
            using var client = new NamedPipeClientStream(".", PipeName, PipeDirection.Out);
            client.Connect(1500);
            using var writer = new StreamWriter(client) { AutoFlush = true };
            writer.WriteLine("activate");
        }
        catch
        {
            // Existing UI may be busy; ignore.
        }
    }

    private static void ListenForActivation(Action onActivate, CancellationToken token)
    {
        while (!token.IsCancellationRequested)
        {
            try
            {
                using var server = new NamedPipeServerStream(
                    PipeName,
                    PipeDirection.In,
                    1,
                    PipeTransmissionMode.Byte,
                    PipeOptions.Asynchronous);
                server.WaitForConnection();
                using var reader = new StreamReader(server);
                _ = reader.ReadLine();
                onActivate();
            }
            catch (OperationCanceledException)
            {
                break;
            }
            catch
            {
                Thread.Sleep(200);
            }
        }
    }

    public void Dispose()
    {
        _pipeCts?.Cancel();
        _pipeThread?.Join(500);
        _pipeCts?.Dispose();
        if (_ownsMutex)
        {
            try { _mutex.ReleaseMutex(); } catch { /* ignore */ }
        }
        _mutex.Dispose();
    }
}
