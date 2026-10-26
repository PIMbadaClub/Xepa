using System.ComponentModel.DataAnnotations;
using System.Security.Claims;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Xepa.Application.Contas;
using Xepa.Domain.Entities;

namespace Xepa.Web.Controllers;

public class EntrarForm
{
    [Required(ErrorMessage = "Informe o e-mail."), EmailAddress(ErrorMessage = "E-mail inválido.")]
    [Display(Name = "E-mail")]
    public string Email { get; set; } = "";

    [Required(ErrorMessage = "Informe a senha.")]
    [Display(Name = "Senha"), DataType(DataType.Password)]
    public string Senha { get; set; } = "";

    public string? ReturnUrl { get; set; }
}

[Route("conta")]
public class ContaController(CredenciaisService credenciais) : Controller
{
    public const string ClaimEstabelecimentoId = "estabelecimento_id";
    public const string ClaimEstabelecimentoNome = "estabelecimento_nome";

    [HttpGet("entrar"), AllowAnonymous]
    public IActionResult Entrar(string? returnUrl) => View(new EntrarForm { ReturnUrl = returnUrl });

    [HttpPost("entrar"), AllowAnonymous]
    public async Task<IActionResult> Entrar(EntrarForm form, CancellationToken ct)
    {
        if (!ModelState.IsValid)
            return View(form);

        var usuario = await credenciais.ValidarAsync(form.Email, form.Senha, ct);
        if (usuario is null || usuario.Tipo is not (TipoUsuario.Estabelecimento or TipoUsuario.Administrador))
        {
            ModelState.AddModelError("", "E-mail ou senha incorretos, ou a conta não tem acesso ao portal.");
            return View(form);
        }

        var claims = new List<Claim>
        {
            new(ClaimTypes.NameIdentifier, usuario.Id.ToString()),
            new(ClaimTypes.Name, usuario.Nome),
            new(ClaimTypes.Role, usuario.Tipo.ToString())
        };
        if (usuario.Estabelecimento is { } loja)
        {
            claims.Add(new Claim(ClaimEstabelecimentoId, loja.Id.ToString()));
            claims.Add(new Claim(ClaimEstabelecimentoNome, loja.Nome));
        }

        await HttpContext.SignInAsync(CookieAuthenticationDefaults.AuthenticationScheme,
            new ClaimsPrincipal(new ClaimsIdentity(claims, CookieAuthenticationDefaults.AuthenticationScheme)));

        if (Url.IsLocalUrl(form.ReturnUrl))
            return LocalRedirect(form.ReturnUrl);
        return usuario.Tipo == TipoUsuario.Administrador
            ? RedirectToAction(nameof(InicioController.Administracao), "Inicio")
            : RedirectToAction(nameof(OfertasController.Index), "Ofertas");
    }

    [HttpPost("sair")]
    public async Task<IActionResult> Sair()
    {
        await HttpContext.SignOutAsync(CookieAuthenticationDefaults.AuthenticationScheme);
        return RedirectToAction(nameof(Entrar));
    }

    [HttpGet("acesso-negado"), AllowAnonymous]
    public IActionResult AcessoNegado() => View();
}

public class InicioController : Controller
{
    [HttpGet("/")]
    public IActionResult Index() =>
        User.IsInRole(nameof(TipoUsuario.Administrador))
            ? RedirectToAction(nameof(Administracao))
            : RedirectToAction(nameof(OfertasController.Index), "Ofertas");

    /// <summary>Área administrativa: aprovação de lojas e denúncias entram na Sprint 3.</summary>
    [HttpGet("/admin"), Authorize(Roles = nameof(TipoUsuario.Administrador))]
    public IActionResult Administracao() => View();

    [HttpGet("/erro"), AllowAnonymous]
    public IActionResult Erro() => View();
}
