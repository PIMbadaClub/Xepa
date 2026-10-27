using System.Security.Claims;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Xepa.Domain.Entities;
using Xepa.Web.Controllers;

namespace Xepa.Web;

/// <summary>Sessão do portal por cookie. Usada no login e quando a loja muda o nome (o menu mostra o nome da loja).</summary>
public static class SessaoPortal
{
    public static Task EntrarAsync(HttpContext http, Usuario usuario)
    {
        var claims = new List<Claim>
        {
            new(ClaimTypes.NameIdentifier, usuario.Id.ToString()),
            new(ClaimTypes.Name, usuario.Nome),
            new(ClaimTypes.Email, usuario.Email),
            new(ClaimTypes.Role, usuario.Tipo.ToString())
        };
        if (usuario.Estabelecimento is { } loja)
        {
            claims.Add(new Claim(ContaController.ClaimEstabelecimentoId, loja.Id.ToString()));
            claims.Add(new Claim(ContaController.ClaimEstabelecimentoNome, loja.Nome));
            claims.Add(new Claim(ContaController.ClaimEstabelecimentoStatus, loja.StatusCadastro.ToString()));
        }

        return http.SignInAsync(CookieAuthenticationDefaults.AuthenticationScheme,
            new ClaimsPrincipal(new ClaimsIdentity(claims, CookieAuthenticationDefaults.AuthenticationScheme)));
    }
}
