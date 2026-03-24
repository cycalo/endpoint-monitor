namespace EndpointMonitorService.Options;

public sealed class AuthOptions
{
    public string Token { get; set; } = "";
    public string JwtSigningKey { get; set; } = "";
    public int JwtExpiryDays { get; set; } = 30;
}
