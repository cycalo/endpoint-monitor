using System.IdentityModel.Tokens.Jwt;
using System.Text;
using EndpointMonitorService.Options;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;

namespace EndpointMonitorService.Services;

public sealed class AuthTokenValidator(IOptions<AuthOptions> options)
{
    private readonly AuthOptions _opt = options.Value;

    public bool TryValidateAuthorization(string? authorizationHeader, out string? failureReason)
    {
        failureReason = null;
        if (string.IsNullOrWhiteSpace(authorizationHeader) ||
            !authorizationHeader.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase))
        {
            failureReason = "missing_bearer";
            return false;
        }

        var token = authorizationHeader["Bearer ".Length..].Trim();
        if (string.IsNullOrEmpty(token))
        {
            failureReason = "empty_token";
            return false;
        }

        if (string.Equals(token, _opt.Token, StringComparison.Ordinal))
            return true;

        if (string.IsNullOrWhiteSpace(_opt.JwtSigningKey) || _opt.JwtSigningKey.Length < 32)
        {
            failureReason = "invalid_static_or_jwt";
            return false;
        }

        try
        {
            var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_opt.JwtSigningKey));
            var handler = new JwtSecurityTokenHandler();
            handler.ValidateToken(token, new TokenValidationParameters
            {
                ValidateIssuerSigningKey = true,
                IssuerSigningKey = key,
                ValidateIssuer = false,
                ValidateAudience = false,
                ValidateLifetime = true,
                ClockSkew = TimeSpan.FromMinutes(2)
            }, out _);
            return true;
        }
        catch
        {
            failureReason = "jwt_invalid";
            return false;
        }
    }
}
