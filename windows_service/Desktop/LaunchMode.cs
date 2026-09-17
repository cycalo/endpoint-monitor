using System.Text.Json;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Hosting.WindowsServices;

namespace EndpointMonitorService.Desktop;

internal enum LaunchMode
{
    WindowsService,
    UiOnly,
    InProcessHost,
}

internal readonly record struct LaunchContext(LaunchMode Mode, int Port);

internal static class LaunchModeDetector
{
    internal static LaunchContext Detect()
    {
        var port = ReadConfiguredPort();

        if (WindowsServiceHelpers.IsWindowsService())
            return new LaunchContext(LaunchMode.WindowsService, port);

        if (IsAgentHealthy(port))
            return new LaunchContext(LaunchMode.UiOnly, port);

        return new LaunchContext(LaunchMode.InProcessHost, port);
    }

    private static int ReadConfiguredPort()
    {
        var config = new ConfigurationBuilder()
            .SetBasePath(AppContext.BaseDirectory)
            .AddJsonFile("appsettings.json", optional: true)
            .AddJsonFile($"appsettings.{Environment.GetEnvironmentVariable("DOTNET_ENVIRONMENT") ?? "Production"}.json", optional: true)
            .AddEnvironmentVariables()
            .Build();

        return config.GetSection("Server").GetValue<int?>("Port") ?? 5000;
    }

    private static bool IsAgentHealthy(int port)
    {
        try
        {
            using var http = new HttpClient { Timeout = TimeSpan.FromSeconds(2) };
            using var response = http.GetAsync($"http://127.0.0.1:{port}/health").GetAwaiter().GetResult();
            if (!response.IsSuccessStatusCode)
                return false;

            using var stream = response.Content.ReadAsStream();
            using var doc = JsonDocument.Parse(stream);
            return doc.RootElement.TryGetProperty("service", out var svc)
                && string.Equals(svc.GetString(), "EndpointMonitor", StringComparison.Ordinal);
        }
        catch
        {
            return false;
        }
    }
}
