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

public class EsqueciSenhaForm
{
    [Required(ErrorMessage = "Informe o e-mail."), EmailAddress(ErrorMessage = "E-mail inválido.")]
    [Display(Name = "E-mail")]
    public string Email { get; set; } = "";
}

public class RedefinirSenhaForm
{
    [Required(ErrorMessage = "Informe o e-mail."), EmailAddress(ErrorMessage = "E-mail inválido.")]
    [Display(Name = "E-mail")]
    public string Email { get; set; } = "";

    [Required(ErrorMessage = "Informe o código."), RegularExpression(@"^\d{6}$", ErrorMessage = "O código tem 6 dígitos.")]
    [Display(Name = "Código do e-mail")]
    public string Codigo { get; set; } = "";

    [Required(ErrorMessage = "Informe a nova senha."), MinLength(8, ErrorMessage = "Mínimo de 8 caracteres.")]
    [Display(Name = "Nova senha"), DataType(DataType.Password)]
    public string NovaSenha { get; set; } = "";

    [Compare(nameof(NovaSenha), ErrorMessage = "As senhas não conferem.")]
    [Display(Name = "Confirmar nova senha"), DataType(DataType.Password)]
    public string Confirmacao { get; set; } = "";
}

[Route("conta")]
public class ContaController(CredenciaisService credenciais, CadastroLojaService cadastro, RecuperacaoSenhaService recuperacao)
    : Controller
{
    public const string ClaimEstabelecimentoId = "estabelecimento_id";
    public const string ClaimEstabelecimentoNome = "estabelecimento_nome";
    public const string ClaimEstabelecimentoStatus = "estabelecimento_status";

    [HttpGet("entrar"), AllowAnonymous]
    public IActionResult Entrar(string? returnUrl)
    {
        // Já entrou: vai para a tela inicial em vez de mostrar o login dentro do portal.
        if (User.Identity?.IsAuthenticated == true)
            return User.IsInRole(nameof(TipoUsuario.Administrador))
                ? RedirectToAction(nameof(AdminController.Painel), "Admin")
                : RedirectToAction(nameof(LojaController.Inicio), "Loja");
        return View(new EntrarForm { ReturnUrl = returnUrl });
    }

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

        if (Url.IsLocalUrl(form.ReturnUrl) && PodeVoltarPara(usuario.Tipo, form.ReturnUrl))
            return LocalRedirect(form.ReturnUrl);
        return usuario.Tipo == TipoUsuario.Administrador
            ? RedirectToAction(nameof(AdminController.Painel), "Admin")
            : RedirectToAction(nameof(LojaController.Inicio), "Loja");
    }

    /// <summary>
    /// O ReturnUrl só vale se o perfil pode abrir a página: o admin que entra pelo endereço principal
    /// recebe ReturnUrl=/loja e cairia em "Acesso negado". Fora da área do perfil, vai para o início dele.
    /// </summary>
    private static bool PodeVoltarPara(TipoUsuario tipo, string url)
    {
        var area = url.TrimStart('/').Split('/', '?', '#')[0].ToLowerInvariant();
        return tipo == TipoUsuario.Administrador
            ? area == "admin"
            : area is not ("admin" or "");
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
        return RedirectToAction(nameof(LojaController.Inicio), "Loja");
    }

    /// <summary>"Esqueci minha senha": manda o código por e-mail (a mesma resposta exista ou não a conta).</summary>
    [HttpGet("esqueci-senha"), AllowAnonymous]
    public IActionResult EsqueciSenha(string? email) => View(new EsqueciSenhaForm { Email = email ?? "" });

    [HttpPost("esqueci-senha"), AllowAnonymous]
    public async Task<IActionResult> EsqueciSenha(EsqueciSenhaForm form, CancellationToken ct)
    {
        if (!ModelState.IsValid)
            return View(form);
        await recuperacao.SolicitarAsync(form.Email, ct);
        return RedirectToAction(nameof(RedefinirSenha), new { email = form.Email.Trim() });
    }

    [HttpGet("redefinir-senha"), AllowAnonymous]
    public IActionResult RedefinirSenha(string? email) => View(new RedefinirSenhaForm { Email = email ?? "" });

    [HttpPost("redefinir-senha"), AllowAnonymous]
    public async Task<IActionResult> RedefinirSenha(RedefinirSenhaForm form, CancellationToken ct)
    {
        if (!ModelState.IsValid)
            return View(form);
        Usuario usuario;
        try
        {
            usuario = await recuperacao.RedefinirAsync(
                new RedefinirSenhaRequest { Email = form.Email, Codigo = form.Codigo, NovaSenha = form.NovaSenha }, ct);
        }
        catch (RegraDeNegocioException e)
        {
            ModelState.AddModelError("", e.Message);
            return View(form);
        }

        // Conta do app (cliente ou entregador): a senha muda, mas o acesso é pelo app.
        if (usuario.Tipo is not (TipoUsuario.Estabelecimento or TipoUsuario.Administrador))
        {
            ModelState.Clear();
            ViewData["Concluido"] = "Senha alterada! Entre no app da XEPA com a nova senha.";
            return View(new RedefinirSenhaForm { Email = form.Email });
        }

        await AbrirSessaoAsync(usuario);
        TempData["Mensagem"] = "Senha alterada. Bem-vindo de volta!";
        return usuario.Tipo == TipoUsuario.Administrador
            ? RedirectToAction(nameof(AdminController.Painel), "Admin")
            : RedirectToAction(nameof(LojaController.Inicio), "Loja");
    }

    private Task AbrirSessaoAsync(Usuario usuario) => SessaoPortal.EntrarAsync(HttpContext, usuario);

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
            : RedirectToAction(nameof(LojaController.Inicio), "Loja");

    [HttpGet("/erro"), AllowAnonymous]
    public IActionResult Erro() => View();
}
