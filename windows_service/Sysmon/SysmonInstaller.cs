using System.Diagnostics;
using System.IO.Compression;
using System.Net.Http;
using System.ServiceProcess;
using Microsoft.Extensions.Logging;

namespace EndpointMonitorService.Sysmon;

/// <summary>
/// Ensures Sysmon is installed (Sysmon64 service) by downloading Sysinternals Sysmon and the SwiftOnSecurity config when missing.
/// </summary>
public sealed class SysmonInstaller(
    ILogger<SysmonInstaller> logger,
    IHttpClientFactory httpClientFactory)
{
    private const string SysmonZipUrl = "https://download.sysinternals.com/files/Sysmon.zip";
    private const string ConfigUrl =
        "https://raw.githubusercontent.com/SwiftOnSecurity/sysmon-config/master/sysmonconfig-export.xml";
    private const string ConfigFileName = "sysmonconfig-export.xml";
    private const string ServiceName64 = "Sysmon64";
    private const string ServiceName32 = "Sysmon";

    public async Task EnsureInstalledAsync(CancellationToken cancellationToken = default)
    {
        try
        {
            if (IsSysmonServiceInstalled())
            {
                logger.LogInformation(
                    "Sysmon installer: Sysmon service ({Service}) is already present; skipping installation.",
                    GetInstalledServiceName() ?? ServiceName64);
                return;
            }

            logger.LogInformation("Sysmon installer: Sysmon service not found; starting download and installation.");

            var tempRoot = Path.Combine(Path.GetTempPath(), "EndpointMonitorSysmon_" + Guid.NewGuid().ToString("N"));
            Directory.CreateDirectory(tempRoot);
            var zipPath = Path.Combine(tempRoot, "Sysmon.zip");
            var extractDir = Path.Combine(tempRoot, "extract");
            var sysmon64Path = Path.Combine(extractDir, "Sysmon64.exe");
            var configPath = Path.Combine(extractDir, ConfigFileName);

            try
            {
                await DownloadFileAsync(SysmonZipUrl, zipPath, cancellationToken).ConfigureAwait(false);
                logger.LogInformation("Sysmon installer: Downloaded Sysmon.zip to {Path}.", zipPath);

                ZipFile.ExtractToDirectory(zipPath, extractDir);
                logger.LogInformation("Sysmon installer: Extracted zip to {Path}.", extractDir);

                if (!File.Exists(sysmon64Path))
                {
                    logger.LogError(
                        "Sysmon installer: Sysmon64.exe not found after extract at {Path}; aborting.",
                        sysmon64Path);
                    return;
                }

                await DownloadFileAsync(ConfigUrl, configPath, cancellationToken).ConfigureAwait(false);
                logger.LogInformation("Sysmon installer: Downloaded config to {Path}.", configPath);

                var exitCode = await RunSysmonInstallAsync(sysmon64Path, configPath, extractDir, cancellationToken)
                    .ConfigureAwait(false);
                if (exitCode != 0)
                {
                    logger.LogError(
                        "Sysmon installer: Sysmon64.exe exited with code {ExitCode}; installation may have failed.",
                        exitCode);
                    return;
                }

                logger.LogInformation("Sysmon installer: Sysmon64.exe completed with exit code 0.");

                if (!await TryEnsureSysmonServiceRunningAsync(cancellationToken).ConfigureAwait(false))
                    return;

                logger.LogInformation("Sysmon installer: Verified Sysmon service is running.");
            }
            finally
            {
                try
                {
                    if (Directory.Exists(tempRoot))
                        Directory.Delete(tempRoot, recursive: true);
                }
                catch (Exception ex)
                {
                    logger.LogWarning(ex, "Sysmon installer: Failed to delete temp directory {Path}.", tempRoot);
                }
            }
        }
        catch (OperationCanceledException)
        {
            throw;
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Sysmon installer: Failed to ensure Sysmon installation; continuing without Sysmon.");
        }
    }

    /// <summary>True when Sysmon64 or Sysmon Windows service is registered.</summary>
    public bool IsSysmonInstalled() => IsSysmonServiceInstalled();

    private static bool IsSysmonServiceInstalled()
    {
        return ServiceExists(ServiceName64) || ServiceExists(ServiceName32);
    }

    private static string? GetInstalledServiceName()
    {
        if (ServiceExists(ServiceName64))
            return ServiceName64;
        if (ServiceExists(ServiceName32))
            return ServiceName32;
        return null;
    }

    private static bool ServiceExists(string serviceName)
    {
        try
        {
            using var sc = new ServiceController(serviceName);
            _ = sc.Status;
            return true;
        }
        catch (InvalidOperationException)
        {
            return false;
        }
    }

    private async Task<bool> TryEnsureSysmonServiceRunningAsync(CancellationToken cancellationToken)
    {
        try
        {
            await Task.Delay(1500, cancellationToken).ConfigureAwait(false);

            if (!ServiceExists(ServiceName64) && !ServiceExists(ServiceName32))
            {
                logger.LogError("Sysmon installer: Neither Sysmon64 nor Sysmon service exists after install.");
                return false;
            }

            var name = ServiceExists(ServiceName64) ? ServiceName64 : ServiceName32;

            using var sc = new ServiceController(name);
            sc.Refresh();

            if (sc.Status == ServiceControllerStatus.Running)
                return true;

            logger.LogInformation(
                "Sysmon installer: Service {Name} status is {Status}; attempting to start.",
                name,
                sc.Status);

            sc.Start();
            sc.WaitForStatus(ServiceControllerStatus.Running, TimeSpan.FromSeconds(60));

            sc.Refresh();
            if (sc.Status != ServiceControllerStatus.Running)
            {
                logger.LogError(
                    "Sysmon installer: Sysmon service is not running after start attempt (status: {Status}).",
                    sc.Status);
                return false;
            }

            return true;
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Sysmon installer: Could not verify or start Sysmon service.");
            return false;
        }
    }

    private async Task DownloadFileAsync(string url, string destinationPath, CancellationToken cancellationToken)
    {
        var client = httpClientFactory.CreateClient(nameof(SysmonInstaller));

        using var responseMessage = await client
            .GetAsync(url, HttpCompletionOption.ResponseHeadersRead, cancellationToken)
            .ConfigureAwait(false);
        responseMessage.EnsureSuccessStatusCode();
        await using var response = await responseMessage.Content
            .ReadAsStreamAsync(cancellationToken)
            .ConfigureAwait(false);
        await using var fs = new FileStream(
            destinationPath,
            FileMode.Create,
            FileAccess.Write,
            FileShare.None,
            bufferSize: 81920,
            useAsync: true);
        await response.CopyToAsync(fs, cancellationToken).ConfigureAwait(false);
    }

    private async Task<int> RunSysmonInstallAsync(
        string sysmon64Path,
        string configPath,
        string workingDirectory,
        CancellationToken cancellationToken)
    {
        logger.LogInformation(
            "Sysmon installer: Starting {Exe} -accepteula -i {Config}",
            sysmon64Path,
            configPath);

        var psi = new ProcessStartInfo
        {
            FileName = sysmon64Path,
            Arguments = $"-accepteula -i \"{configPath}\"",
            WorkingDirectory = workingDirectory,
            UseShellExecute = false,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            CreateNoWindow = true
        };

        using var process = new Process { StartInfo = psi, EnableRaisingEvents = true };
        if (!process.Start())
        {
            logger.LogError("Sysmon installer: Failed to start Sysmon64.exe process.");
            return -1;
        }

        using var registration = cancellationToken.Register(() =>
        {
            try
            {
                if (!process.HasExited)
                    process.Kill(entireProcessTree: true);
            }
            catch
            {
                // ignored
            }
        });

        var stdoutTask = process.StandardOutput.ReadToEndAsync();
        var stderrTask = process.StandardError.ReadToEndAsync();

        await process.WaitForExitAsync(cancellationToken).ConfigureAwait(false);

        var stdout = await stdoutTask.ConfigureAwait(false);
        var stderr = await stderrTask.ConfigureAwait(false);

        if (!string.IsNullOrWhiteSpace(stdout))
            logger.LogDebug("Sysmon installer stdout: {Out}", stdout.Trim());
        if (!string.IsNullOrWhiteSpace(stderr))
            logger.LogDebug("Sysmon installer stderr: {Err}", stderr.Trim());

        return process.ExitCode;
    }
}
