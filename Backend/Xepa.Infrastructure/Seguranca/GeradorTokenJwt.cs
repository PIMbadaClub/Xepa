using System.Security.Claims;
using System.Text;
using Microsoft.IdentityModel.JsonWebTokens;
using Microsoft.IdentityModel.Tokens;
using Xepa.Application;
using Xepa.Domain.Entities;

namespace Xepa.Infrastructure.Seguranca;

public class OpcoesJwt
{
    public const string Secao = "Jwt";

    public string Emissor { get; init; } = "xepa-api";
    public string Publico { get; init; } = "xepa-app";

    /// <summary>Chave HMAC de pelo menos 32 caracteres. Em produção vem do Key Vault.</summary>
    public string Chave { get; init; } = "";

    public int MinutosAcesso { get; init; } = 15;

    public SymmetricSecurityKey ChaveAssinatura() => new(Encoding.UTF8.GetBytes(Chave));
}

public class GeradorTokenJwt(OpcoesJwt opcoes) : IGeradorToken
{
    public const string ClaimEstabelecimento = "estabelecimento_id";

    public TimeSpan ValidadeAcesso => TimeSpan.FromMinutes(opcoes.MinutosAcesso);

    public string GerarAcesso(Usuario usuario, int? estabelecimentoId)
    {
        var claims = new List<Claim>
        {
            new(JwtRegisteredClaimNames.Sub, usuario.Id.ToString()),
            new(JwtRegisteredClaimNames.Email, usuario.Email),
            new(JwtRegisteredClaimNames.Name, usuario.Nome),
            new(ClaimTypes.Role, usuario.Tipo.ToString())
        };
        if (estabelecimentoId is { } id)
            claims.Add(new Claim(ClaimEstabelecimento, id.ToString()));

        return new JsonWebTokenHandler().CreateToken(new SecurityTokenDescriptor
        {
            Issuer = opcoes.Emissor,
            Audience = opcoes.Publico,
            Subject = new ClaimsIdentity(claims),
            Expires = DateTime.UtcNow + ValidadeAcesso,
            SigningCredentials = new SigningCredentials(opcoes.ChaveAssinatura(), SecurityAlgorithms.HmacSha256)
        });
    }
}

public static class ClaimsExtensions
{
    public static int UsuarioId(this ClaimsPrincipal user) =>
        int.Parse(user.FindFirstValue(JwtRegisteredClaimNames.Sub) ?? user.FindFirstValue(ClaimTypes.NameIdentifier)!);
}
