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

    public const string ExamplePepperPlaceholder =
        "CHANGE_THIS_TO_A_LONG_RANDOM_SECRET_AT_LEAST_32_CHARS";

    public string ResolvePepper()
    {
        if (!string.IsNullOrWhiteSpace(DeviceTokenPepper)) return DeviceTokenPepper;
        return JwtSigningKey ?? "";
    }

    /// <summary>Returns null when pepper is configured; otherwise a startup-blocking error message.</summary>
    public string? ValidatePepper()
    {
        var p = ResolvePepper();
        if (string.IsNullOrWhiteSpace(p))
            return "DeviceTokenPepper (or legacy JwtSigningKey) must be set in configuration.";
        if (p.Length < 32)
            return "DeviceTokenPepper must be at least 32 characters.";
        if (string.Equals(p, ExamplePepperPlaceholder, StringComparison.Ordinal))
            return "DeviceTokenPepper must be changed from the example placeholder.";
        return null;
    }
}
