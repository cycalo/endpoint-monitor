using System.Diagnostics;
using System.IO.Compression;
using System.Security.Cryptography;
using System.ServiceProcess;
using System.Text;
using System.Xml.Linq;
using Microsoft.Win32;

namespace EndpointMonitorService.Sysmon;

/// <summary>
/// Installs Sysmon when it is missing, and applies the bundled SwiftOnSecurity config
/// (sysmon -i on first install, sysmon -c when the service already exists).
/// </summary>
public sealed class SysmonInstaller(
    ILogger<SysmonInstaller> logger,
    IHttpClientFactory httpClientFactory)
{
    private const string ResourceName = "EndpointMonitorService.Sysmon.sysmonconfig-export.xml";
    private const string SysmonZipUrl = "https://download.sysinternals.com/files/Sysmon.zip";
    private const string ConfigFileName = "sysmonconfig-export.xml";
    private const string ConfigStampFileName = "sysmonconfig.sha256";
    private const string ServiceName64 = "Sysmon64";
    private const string ServiceName32 = "Sysmon";

    public async Task EnsureInstalledAsync(CancellationToken cancellationToken = default)
    {
        try
        {
            var config = await MaterializeBundledConfigAsync(cancellationToken).ConfigureAwait(false);
            if (config == null)
                return;

            if (!IsSafeConfigPath(config.Path))
            {
                logger.LogError("Sysmon installer: Config path is not safe to pass to Sysmon.");
                return;
            }

            if (!IsSysmonServiceInstalled())
            {
                logger.LogInformation("Sysmon installer: Sysmon service not found; starting download and installation.");
                if (!await InstallSysmonAsync(config, cancellationToken).ConfigureAwait(false))
                    return;

                await TryEnsureSysmonServiceRunningAsync(cancellationToken, waitForRegistration: true)
                    .ConfigureAwait(false);
                return;
            }

            logger.LogInformation(
                "Sysmon installer: Sysmon service ({Service}) is already present.",
                GetInstalledServiceName() ?? ServiceName64);

            if (IsConfigCurrent(config))
            {
                logger.LogInformation("Sysmon installer: Bundled Sysmon config is already applied.");
            }
            else if (!await UpdateConfigAsync(config, cancellationToken).ConfigureAwait(false))
            {
                return;
            }

            await TryEnsureSysmonServiceRunningAsync(cancellationToken, waitForRegistration: false)
                .ConfigureAwait(false);
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

    private async Task<bool> InstallSysmonAsync(BundledConfig config, CancellationToken cancellationToken)
    {
        var tempRoot = Path.Combine(Path.GetTempPath(), "EndpointMonitorSysmon_" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(tempRoot);
        var zipPath = Path.Combine(tempRoot, "Sysmon.zip");
        var extractDir = Path.Combine(tempRoot, "extract");
        var sysmon64Path = Path.Combine(extractDir, "Sysmon64.exe");

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
                return false;
            }

            var exitCode = await RunSysmonAsync(
                    sysmon64Path,
                    $"-accepteula -i \"{config.Path}\"",
                    extractDir,
                    "install",
                    cancellationToken)
                .ConfigureAwait(false);
            if (exitCode != 0)
            {
                logger.LogError(
                    "Sysmon installer: Sysmon64.exe exited with code {ExitCode}; installation may have failed.",
                    exitCode);
                return false;
            }

            WriteConfigStamp(config);
            logger.LogInformation("Sysmon installer: Sysmon64.exe completed with exit code 0.");
            return true;
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

    private async Task<bool> UpdateConfigAsync(BundledConfig config, CancellationToken cancellationToken)
    {
        var exe = FindInstalledSysmonExe();
        if (exe == null)
        {
            logger.LogError("Sysmon installer: Sysmon service is installed but Sysmon64.exe / Sysmon.exe was not found.");
            return false;
        }

        logger.LogInformation("Sysmon installer: Applying bundled config with {Exe} -c.", exe);
        var exitCode = await RunSysmonAsync(
                exe,
                $"-accepteula -c \"{config.Path}\"",
                Path.GetDirectoryName(config.Path)!,
                "update-config",
                cancellationToken)
            .ConfigureAwait(false);
        if (exitCode != 0)
        {
            logger.LogError(
                "Sysmon installer: Config update exited with code {ExitCode}; existing Sysmon config was left unchanged.",
                exitCode);
            return false;
        }

        WriteConfigStamp(config);
        logger.LogInformation("Sysmon installer: Bundled Sysmon config applied.");
        return true;
    }

    private async Task<BundledConfig?> MaterializeBundledConfigAsync(CancellationToken cancellationToken)
    {
        var assembly = typeof(SysmonInstaller).Assembly;
        await using var stream = assembly.GetManifestResourceStream(ResourceName);
        if (stream == null)
        {
            logger.LogError("Sysmon installer: Bundled config resource {Name} was not found.", ResourceName);
            return null;
        }

        using var buffer = new MemoryStream();
        await stream.CopyToAsync(buffer, cancellationToken).ConfigureAwait(false);
        var bytes = buffer.ToArray();
        if (!IsValidSysmonConfig(bytes))
        {
            logger.LogError("Sysmon installer: Bundled Sysmon config is not valid Sysmon XML.");
            return null;
        }

        var directory = ConfigDirectory();
        Directory.CreateDirectory(directory);
        var path = Path.Combine(directory, ConfigFileName);
        var tempPath = path + ".tmp";
        await File.WriteAllBytesAsync(tempPath, bytes, cancellationToken).ConfigureAwait(false);
        File.Move(tempPath, path, overwrite: true);

        var hash = Convert.ToHexString(SHA256.HashData(bytes));
        return new BundledConfig(path, hash);
    }

    private static bool IsValidSysmonConfig(byte[] bytes)
    {
        try
        {
            var doc = XDocument.Parse(Encoding.UTF8.GetString(bytes));
            return string.Equals(doc.Root?.Name.LocalName, "Sysmon", StringComparison.OrdinalIgnoreCase);
        }
        catch (Exception)
        {
            return false;
        }
    }

    private static bool IsSafeConfigPath(string path)
    {
        return path.IndexOfAny(['"', '\r', '\n']) < 0;
    }

    private static bool IsConfigCurrent(BundledConfig config)
    {
        var stampPath = Path.Combine(ConfigDirectory(), ConfigStampFileName);
        if (!File.Exists(stampPath))
            return false;

        var previous = File.ReadAllText(stampPath).Trim();
        return previous.Equals(config.Sha256, StringComparison.OrdinalIgnoreCase);
    }

    private static void WriteConfigStamp(BundledConfig config)
    {
        var stampPath = Path.Combine(ConfigDirectory(), ConfigStampFileName);
        File.WriteAllText(stampPath, config.Sha256, Encoding.ASCII);
    }

    private static string ConfigDirectory()
    {
        return Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData),
            "EndpointMonitor");
    }

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

    private static string? FindInstalledSysmonExe()
    {
        foreach (var name in new[] { ServiceName64, ServiceName32 })
        {
            if (!ServiceExists(name))
                continue;

            var fromRegistry = ReadServiceExePath(name);
            if (fromRegistry != null && File.Exists(fromRegistry))
                return fromRegistry;
        }

        var windows = Environment.GetFolderPath(Environment.SpecialFolder.Windows);
        foreach (var file in new[] { "Sysmon64.exe", "Sysmon.exe" })
        {
            var path = Path.Combine(windows, file);
            if (File.Exists(path))
                return path;
        }

        return null;
    }

    private static string? ReadServiceExePath(string serviceName)
    {
        try
        {
            using var key = Registry.LocalMachine.OpenSubKey($@"SYSTEM\CurrentControlSet\Services\{serviceName}");
            var image = key?.GetValue("ImagePath") as string;
            if (string.IsNullOrWhiteSpace(image))
                return null;

            image = image.Trim().Trim('"');
            if (image.StartsWith(@"\??\", StringComparison.Ordinal))
                image = image[4..];

            if (!image.EndsWith(".exe", StringComparison.OrdinalIgnoreCase))
                return null;

            return Path.IsPathRooted(image)
                ? image
                : Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Windows), image);
        }
        catch (Exception)
        {
            return null;
        }
    }

    private async Task<bool> TryEnsureSysmonServiceRunningAsync(
        CancellationToken cancellationToken,
        bool waitForRegistration)
    {
        try
        {
            if (waitForRegistration)
                await Task.Delay(1500, cancellationToken).ConfigureAwait(false);

            if (!ServiceExists(ServiceName64) && !ServiceExists(ServiceName32))
            {
                logger.LogError("Sysmon installer: Neither Sysmon64 nor Sysmon service exists.");
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

            logger.LogInformation("Sysmon installer: Verified Sysmon service is running.");
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

    private async Task<int> RunSysmonAsync(
        string exePath,
        string arguments,
        string workingDirectory,
        string action,
        CancellationToken cancellationToken)
    {
        logger.LogInformation("Sysmon installer: Starting {Exe} {Args} ({Action}).", exePath, arguments, action);

        var psi = new ProcessStartInfo
        {
            FileName = exePath,
            Arguments = arguments,
            WorkingDirectory = workingDirectory,
            UseShellExecute = false,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            CreateNoWindow = true
        };

        using var process = new Process { StartInfo = psi, EnableRaisingEvents = true };
        if (!process.Start())
        {
            logger.LogError("Sysmon installer: Failed to start {Exe}.", exePath);
            return -1;
        }

        using var timeout = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        timeout.CancelAfter(TimeSpan.FromMinutes(3));
        using var registration = timeout.Token.Register(() =>
        {
            try
            {
                if (!process.HasExited)
                    process.Kill(entireProcessTree: true);
            }
            catch (Exception)
            {
                // Process may already have exited.
            }
        });

        var stdoutTask = process.StandardOutput.ReadToEndAsync();
        var stderrTask = process.StandardError.ReadToEndAsync();

        var timedOut = false;
        try
        {
            await process.WaitForExitAsync(timeout.Token).ConfigureAwait(false);
        }
        catch (OperationCanceledException) when (!cancellationToken.IsCancellationRequested)
        {
            timedOut = true;
        }

        var stdout = await stdoutTask.ConfigureAwait(false);
        var stderr = await stderrTask.ConfigureAwait(false);

        if (!string.IsNullOrWhiteSpace(stdout))
            logger.LogDebug("Sysmon installer stdout: {Out}", stdout.Trim());
        if (!string.IsNullOrWhiteSpace(stderr))
            logger.LogDebug("Sysmon installer stderr: {Err}", stderr.Trim());

        if (timedOut)
        {
            logger.LogError("Sysmon installer: {Exe} timed out during {Action}.", exePath, action);
            return -1;
        }

        return process.ExitCode;
    }

    private sealed record BundledConfig(string Path, string Sha256);
}
