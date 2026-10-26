using System.ComponentModel.DataAnnotations;
using System.Security.Claims;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Xepa.Application;
using Xepa.Application.Contas;
using Xepa.Domain;
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
public class ContaController(CredenciaisService credenciais, CadastroLojaService cadastro) : Controller
{
    public const string ClaimEstabelecimentoId = "estabelecimento_id";
    public const string ClaimEstabelecimentoNome = "estabelecimento_nome";
    public const string ClaimEstabelecimentoStatus = "estabelecimento_status";

    [HttpGet("entrar"), AllowAnonymous]
    public IActionResult Entrar(string? returnUrl) => View(new EntrarForm { ReturnUrl = returnUrl });

    [HttpPost("entrar"), AllowAnonymous]
    public async Task<IActionResult> Entrar(EntrarForm form, CancellationToken ct)
    {
        if (!ModelState.IsValid)
            return View(form);

        Usuario? usuario;
        try
        {
            usuario = await credenciais.ValidarAsync(form.Email, form.Senha, ct);
        }
        catch (AcessoNegadoException e)
        {
            ModelState.AddModelError("", e.Message);
            return View(form);
        }
        if (usuario is null || usuario.Tipo is not (TipoUsuario.Estabelecimento or TipoUsuario.Administrador))
        {
            ModelState.AddModelError("", "E-mail ou senha incorretos, ou a conta não tem acesso ao portal.");
            return View(form);
        }

        await AbrirSessaoAsync(usuario);

        if (Url.IsLocalUrl(form.ReturnUrl))
            return LocalRedirect(form.ReturnUrl);
        return usuario.Tipo == TipoUsuario.Administrador
            ? RedirectToAction(nameof(AdminController.Painel), "Admin")
            : RedirectToAction(nameof(PedidosController.Index), "Pedidos");
    }

    /// <summary>"Cadastre sua loja": a loja entra pendente e só aparece no app depois de aprovada (RN10).</summary>
    [HttpGet("cadastrar"), AllowAnonymous]
    public IActionResult Cadastrar() => View(new CadastroLojaForm());

    [HttpPost("cadastrar"), AllowAnonymous]
    public async Task<IActionResult> Cadastrar(CadastroLojaForm form, CancellationToken ct)
    {
        if (!ModelState.IsValid)
            return View(form);
        try
        {
            var usuario = await cadastro.RegistrarAsync(form, ct);
            await AbrirSessaoAsync(usuario);
        }
        catch (RegraDeNegocioException e)
        {
            ModelState.AddModelError("", e.Message);
            return View(form);
        }

        TempData["Mensagem"] = "Cadastro recebido! Já dá para preparar as ofertas; elas aparecem no app assim que a equipe da XEPA aprovar a loja.";
        return RedirectToAction(nameof(OfertasController.Index), "Ofertas");
    }

    private Task AbrirSessaoAsync(Usuario usuario)
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
            claims.Add(new Claim(ClaimEstabelecimentoId, loja.Id.ToString()));
            claims.Add(new Claim(ClaimEstabelecimentoNome, loja.Nome));
            claims.Add(new Claim(ClaimEstabelecimentoStatus, loja.StatusCadastro.ToString()));
        }

        return HttpContext.SignInAsync(CookieAuthenticationDefaults.AuthenticationScheme,
            new ClaimsPrincipal(new ClaimsIdentity(claims, CookieAuthenticationDefaults.AuthenticationScheme)));
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
            ? RedirectToAction(nameof(AdminController.Painel), "Admin")
            : RedirectToAction(nameof(OfertasController.Index), "Ofertas");

    [HttpGet("/erro"), AllowAnonymous]
    public IActionResult Erro() => View();
}
