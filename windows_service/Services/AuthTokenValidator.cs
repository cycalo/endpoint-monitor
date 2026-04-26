namespace EndpointMonitorService.Services;

public sealed class AuthTokenValidator(PairingAuthService pairingAuthService)
{
    public async Task<(bool Valid, string? FailureReason)> TryValidateAuthorizationAsync(
        string? authorizationHeader,
        CancellationToken cancellationToken)
    {
        string? failureReason = null;
        if (string.IsNullOrWhiteSpace(authorizationHeader) ||
            !authorizationHeader.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase))
        {
            failureReason = "missing_bearer";
            return (false, failureReason);
        }

        var token = authorizationHeader["Bearer ".Length..].Trim();
        if (string.IsNullOrEmpty(token))
        {
            failureReason = "empty_token";
            return (false, failureReason);
        }

        var ok = await pairingAuthService.ValidateDeviceTokenAsync(token, cancellationToken).ConfigureAwait(false);
        if (ok) return (true, null);

        failureReason = "auth_invalid";
        return (false, failureReason);
    }
}
