namespace EndpointMonitorService.Options;

/// <summary>
/// Authentication options. Only paired device tokens are accepted; this pepper hashes them at rest.
/// </summary>
public sealed class AuthOptions
{
    /// <summary>
    /// Secret used to pepper stored device-token hashes. Must be at least 32 characters.
    /// </summary>
    public string DeviceTokenPepper { get; set; } = "";

    /// <summary>
    /// Legacy appsettings key; used only when <see cref="DeviceTokenPepper"/> is empty.
    /// </summary>
    public string JwtSigningKey { get; set; } = "";

    public string ResolvePepper()
    {
        if (!string.IsNullOrWhiteSpace(DeviceTokenPepper)) return DeviceTokenPepper;
        return JwtSigningKey ?? "";
    }
}
