using System.Diagnostics;
using System.Reflection;
using System.ServiceProcess;
using System.Text;

namespace EndpointMonitorService;

/// <summary>Installs or configures the Windows Service so the agent can start automatically at boot.</summary>
internal static class WindowsServiceAutorunHelper
{
    internal const string ServiceName = "EndpointMonitor";
    internal const string DisplayName = "Endpoint Monitor";

    /// <summary>Executable to register with <c>sc create</c> (app host or single-file publish).</summary>
    internal static string? TryResolveBinaryPathForServiceInstallation()
    {
        var processPath = Environment.ProcessPath;
        if (!string.IsNullOrEmpty(processPath)
            && processPath.EndsWith(".exe", StringComparison.OrdinalIgnoreCase)
            && !string.Equals(Path.GetFileName(processPath), "dotnet.exe", StringComparison.OrdinalIgnoreCase))
        {
            return processPath;
        }

        var loc = Assembly.GetExecutingAssembly().Location;
        if (string.IsNullOrEmpty(loc))
            return null;

        var dir = Path.GetDirectoryName(loc);
        if (string.IsNullOrEmpty(dir))
            return null;

        var baseName = Path.GetFileNameWithoutExtension(loc);
        var candidate = Path.Combine(dir, baseName + ".exe");
        return File.Exists(candidate) ? candidate : null;
    }

    internal static bool ServiceIsRegistered()
    {
        try
        {
            using var _ = new ServiceController(ServiceName);
            return true;
        }
        catch (InvalidOperationException)
        {
            return false;
        }
    }

    /// <summary>True when the service exists and is set to start automatically (including delayed auto).</summary>
    internal static bool IsAutomaticStart()
    {
        if (!ServiceIsRegistered())
            return false;

        using var sc = new ServiceController(ServiceName);
        return sc.StartType is ServiceStartMode.Automatic
            or ServiceStartMode.Boot
            or ServiceStartMode.System;
    }

    /// <summary>Launches an elevated helper script (UAC). User must approve the prompt.</summary>
    internal static void RequestSetAutomaticStart(bool enable)
    {
        var registered = ServiceIsRegistered();
        var exe = TryResolveBinaryPathForServiceInstallation();

        if (enable && !registered && string.IsNullOrEmpty(exe))
        {
            throw new InvalidOperationException(
                "Could not find EndpointMonitorService.exe for this build. Build the project (apphost) or publish a single-file exe, then try again. See BUILD-SINGLE-EXE.md.");
        }

        var batchPath = Path.Combine(Path.GetTempPath(), $"endpoint-monitor-svc-{Guid.NewGuid():N}.cmd");
        if (enable)
        {
            var sb = new StringBuilder();
            sb.AppendLine("@echo off");
            sb.AppendLine("setlocal");
            sb.AppendLine("set \"EM_BIN=%~1\"");
            sb.AppendLine("if \"%EM_BIN%\"==\"\" goto registered_only");
            sb.AppendLine($"sc query {ServiceName} >nul 2>&1");
            sb.AppendLine("if errorlevel 1 (");
            sb.AppendLine($"  sc create {ServiceName} binPath= \"%EM_BIN%\" DisplayName= \"{DisplayName}\" start= auto");
            sb.AppendLine("  if errorlevel 1 exit /b 1");
            sb.AppendLine(") else (");
            sb.AppendLine($"  sc config {ServiceName} start= auto");
            sb.AppendLine("  if errorlevel 1 exit /b 1");
            sb.AppendLine(")");
            sb.AppendLine("goto finish");
            sb.AppendLine(":registered_only");
            sb.AppendLine($"sc query {ServiceName} >nul 2>&1");
            sb.AppendLine("if errorlevel 1 exit /b 1");
            sb.AppendLine($"sc config {ServiceName} start= auto");
            sb.AppendLine("if errorlevel 1 exit /b 1");
            sb.AppendLine(":finish");
            sb.AppendLine(
                $"sc description {ServiceName} \"Monitors endpoint telemetry for the Endpoint Monitor mobile app.\"");
            sb.AppendLine($"sc start {ServiceName} >nul 2>&1");
            sb.AppendLine("exit /b 0");
            File.WriteAllText(batchPath, sb.ToString(), Encoding.ASCII);

            var psi = new ProcessStartInfo
            {
                FileName = batchPath,
                Verb = "runas",
                UseShellExecute = true,
            };
            if (!string.IsNullOrEmpty(exe))
                psi.Arguments = $"\"{exe}\"";
            Process.Start(psi);
        }
        else
        {
            var sb = new StringBuilder();
            sb.AppendLine("@echo off");
            sb.AppendLine($"sc query {ServiceName} >nul 2>&1");
            sb.AppendLine("if errorlevel 1 exit /b 0");
            sb.AppendLine($"sc config {ServiceName} start= demand");
            sb.AppendLine("exit /b 0");
            File.WriteAllText(batchPath, sb.ToString(), Encoding.ASCII);

            Process.Start(new ProcessStartInfo
            {
                FileName = batchPath,
                Verb = "runas",
                UseShellExecute = true,
            });
        }
    }
}
