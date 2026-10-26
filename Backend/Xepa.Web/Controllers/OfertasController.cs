using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Xepa.Application;
using Xepa.Application.Ofertas;
using Xepa.Domain;
using Xepa.Domain.Entities;

namespace Xepa.Web.Controllers;

/// <summary>Cadastro de ofertas pelo estabelecimento.</summary>
[Route("ofertas")]
[Authorize(Roles = nameof(TipoUsuario.Estabelecimento))]
public class OfertasController(OfertaGestaoService ofertas) : Controller
{
    private int EstabelecimentoId => int.Parse(User.FindFirst(ContaController.ClaimEstabelecimentoId)!.Value);

    [HttpGet("")]
    public async Task<IActionResult> Index(CancellationToken ct) =>
        View(await ofertas.ListarAsync(EstabelecimentoId, ct));

    [HttpGet("nova")]
    public IActionResult Nova()
    {
        // Sugere a janela das 18h às 20h (Brasília); se ela já passou, a de amanhã.
        var agora = TimeZoneInfo.ConvertTime(DateTimeOffset.UtcNow, OfertaGestaoService.FusoBrasilia);
        var dia = agora.Hour >= 20 ? agora.Date.AddDays(1) : agora.Date;
        return View("Form", new OfertaForm { RetiradaInicio = dia.AddHours(18), RetiradaFim = dia.AddHours(20) });
    }

    [HttpPost("nova")]
    [RequestSizeLimit(OfertaGestaoService.TamanhoMaximoFoto + 1024 * 1024)]
    public async Task<IActionResult> Nova(OfertaForm form, IFormFile? foto, CancellationToken ct)
    {
        if (!ModelState.IsValid)
            return View("Form", form);
        try
        {
            await ofertas.CriarAsync(EstabelecimentoId, form, ParaFoto(foto), ct);
        }
        catch (RegraDeNegocioException e)
        {
            ModelState.AddModelError("", e.Message);
            return View("Form", form);
        }

        TempData["Mensagem"] = "Oferta publicada.";
        return RedirectToAction(nameof(Index));
    }

    [HttpGet("{id:int}")]
    public async Task<IActionResult> Editar(int id, CancellationToken ct)
    {
        try
        {
            ViewData["Id"] = id;
            return View("Form", await ofertas.ObterFormAsync(EstabelecimentoId, id, ct));
        }
        catch (NaoEncontradoException)
        {
            return NotFound();
        }
    }

    [HttpPost("{id:int}")]
    [RequestSizeLimit(OfertaGestaoService.TamanhoMaximoFoto + 1024 * 1024)]
    public async Task<IActionResult> Editar(int id, OfertaForm form, IFormFile? foto, CancellationToken ct)
    {
        ViewData["Id"] = id;
        if (!ModelState.IsValid)
            return View("Form", form);
        try
        {
            await ofertas.AtualizarAsync(EstabelecimentoId, id, form, ParaFoto(foto), ct);
        }
        catch (RegraDeNegocioException e)
        {
            ModelState.AddModelError("", e.Message);
            return View("Form", form);
        }
        catch (NaoEncontradoException)
        {
            return NotFound();
        }

        TempData["Mensagem"] = "Oferta atualizada.";
        return RedirectToAction(nameof(Index));
    }

    [HttpPost("{id:int}/ativa")]
    public async Task<IActionResult> AlterarAtiva(int id, bool ativa, CancellationToken ct)
    {
        await ofertas.AlterarAtivaAsync(EstabelecimentoId, id, ativa, ct);
        TempData["Mensagem"] = ativa ? "Oferta reativada." : "Oferta retirada do ar.";
        return RedirectToAction(nameof(Index));
    }

    private static Foto? ParaFoto(IFormFile? arquivo) =>
        arquivo is { Length: > 0 } ? new Foto(arquivo.OpenReadStream(), arquivo.FileName, arquivo.Length) : null;
}
