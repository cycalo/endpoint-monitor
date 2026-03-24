using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using EndpointMonitorService.Options;
using Microsoft.IdentityModel.Tokens;

namespace EndpointMonitorService.Services;

public static class JwtIssuer
{
    public static string CreateAccessToken(AuthOptions options)
    {
        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(options.JwtSigningKey));
        var creds = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);
        var token = new JwtSecurityToken(
            claims: [new Claim("role", "monitor")],
            expires: DateTime.UtcNow.AddDays(options.JwtExpiryDays),
            signingCredentials: creds);
        return new JwtSecurityTokenHandler().WriteToken(token);
    }
}
