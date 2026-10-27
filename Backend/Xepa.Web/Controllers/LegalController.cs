using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Xepa.Web.Controllers;

/// <summary>Termos de uso e política de privacidade (LGPD). Públicas: o app e o cadastro da loja apontam para cá.</summary>
[AllowAnonymous]
public class LegalController : Controller
{
    /// <summary>Data da versão em vigor; muda quando o texto mudar.</summary>
    public const string Versao = "27/10/2026";

    [HttpGet("termos")]
    public IActionResult Termos() => View();

    [HttpGet("privacidade")]
    public IActionResult Privacidade() => View();
}
