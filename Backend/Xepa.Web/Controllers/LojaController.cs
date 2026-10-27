using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Xepa.Application;
using Xepa.Application.Administracao;
using Xepa.Application.Ofertas;
using Xepa.Application.Suporte;
using Xepa.Domain;
using Xepa.Domain.Entities;

namespace Xepa.Web.Controllers;

/// <summary>Tela de configurações da loja: dados e endereço, horários, funcionamento e senha.</summary>
public class ConfiguracoesLojaVm
{
    public required LojaDetalheAdminDto Loja { get; init; }
    public string? LogoUrl { get; init; }
    public bool Pausada { get; init; }
    public EditarLojaAdminForm Dados { get; set; } = new();
    public List<HorarioForm> Horarios { get; set; } = [];
    public AlterarSenhaLojaForm Senha { get; set; } = new();
}

/// <summary>Início (painel do dia) e configurações do estabelecimento.</summary>
[Route("loja")]
[Authorize(Roles = nameof(TipoUsuario.Estabelecimento))]
public class LojaController(LojaPainelService painel, AdminCadastrosService cadastros, SuporteService suporte, IXepaDb db) : Controller
{
    private int EstabelecimentoId => int.Parse(User.FindFirst(ContaController.ClaimEstabelecimentoId)!.Value);
    private int UsuarioId => int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

    [HttpGet("")]
    public async Task<IActionResult> Inicio(CancellationToken ct) => View(await painel.PainelAsync(EstabelecimentoId, ct));

    [HttpPost("repetir-ofertas")]
    public async Task<IActionResult> RepetirOfertas(CancellationToken ct)
    {
        try
        {
            var n = await painel.RepetirOfertasAsync(EstabelecimentoId, ct);
            TempData["Mensagem"] = n == 1 ? "1 oferta de ontem publicada de novo." : $"{n} ofertas de ontem publicadas de novo.";
        }
        catch (RegraDeNegocioException e)
        {
            TempData["Erro"] = e.Message;
        }
        return RedirectToAction(nameof(Inicio));
    }

    [HttpPost("pausa")]
    public async Task<IActionResult> Pausa(bool pausada, string? voltar, CancellationToken ct)
    {
        await painel.DefinirPausaAsync(EstabelecimentoId, pausada, ct);
        TempData["Mensagem"] = pausada
            ? "Loja pausada: as ofertas saíram do app até você reabrir. Pedidos em andamento continuam."
            : "Loja reaberta: as ofertas no ar voltaram a aparecer no app.";
        return voltar == nameof(Configuracoes) ? RedirectToAction(nameof(Configuracoes), null, null, "funcionamento") : RedirectToAction(nameof(Inicio));
    }

    // ---------- Suporte ----------

    [HttpGet("suporte")]
    public async Task<IActionResult> Suporte(CancellationToken ct)
    {
        ViewData["Pedidos"] = await suporte.PedidosParaAnexarAsync(UsuarioId, ct);
        return View(await suporte.ConversaAsync(UsuarioId, null, ct));
    }

    [HttpGet("suporte/mensagens")]
    public async Task<IActionResult> MensagensSuporte(int depois, CancellationToken ct) =>
        Json(ChatSuporte.Itens((await suporte.ConversaAsync(UsuarioId, depois, ct)).Mensagens));

    [HttpPost("suporte/enviar")]
    public async Task<IActionResult> EnviarSuporte(EnviarMensagemSuporteRequest request, CancellationToken ct)
    {
        try
        {
            await suporte.EnviarAsync(UsuarioId, request, ct);
            return NoContent();
        }
        catch (RegraDeNegocioException e)
        {
            return BadRequest(new { erro = e.Message });
        }
    }

    // ---------- Configurações ----------

    [HttpGet("configuracoes")]
    public async Task<IActionResult> Configuracoes(CancellationToken ct) => View(await MontarAsync(null, null, ct));

    [HttpPost("configuracoes/dados")]
    [RequestSizeLimit(OfertaGestaoService.TamanhoMaximoFoto + 1024 * 1024)]
    public async Task<IActionResult> SalvarDados([Bind(Prefix = "Dados")] EditarLojaAdminForm dados, IFormFile? logo, CancellationToken ct)
    {
        if (ModelState.IsValid)
        {
            try
            {
                // O CNPJ só a equipe da XEPA altera (foi conferido na aprovação).
                var atual = await cadastros.ObterLojaAsync(EstabelecimentoId, ct);
                dados.Cnpj = atual.Cnpj;
                await cadastros.AtualizarLojaAsync(EstabelecimentoId, dados, ct);
                if (logo is { Length: > 0 })
                    await painel.AtualizarLogoAsync(EstabelecimentoId, new Foto(logo.OpenReadStream(), logo.FileName, logo.Length), ct);
                await RenovarSessaoAsync(ct);
                TempData["Mensagem"] = "Dados da loja salvos.";
                return RedirectToAction(nameof(Configuracoes), null, null, "dados");
            }
            catch (RegraDeNegocioException e)
            {
                ModelState.AddModelError("", e.Message);
            }
        }
        return View(nameof(Configuracoes), await MontarAsync(dados, null, ct));
    }

    [HttpPost("configuracoes/horarios")]
    public async Task<IActionResult> SalvarHorarios([Bind(Prefix = "Horarios")] List<HorarioForm> horarios, CancellationToken ct)
    {
        try
        {
            await painel.SalvarHorariosAsync(EstabelecimentoId, horarios, ct);
            TempData["Mensagem"] = "Horário de funcionamento salvo. Ele já aparece no app.";
        }
        catch (RegraDeNegocioException e)
        {
            TempData["Erro"] = e.Message;
        }
        return RedirectToAction(nameof(Configuracoes), null, null, "horarios");
    }

    [HttpPost("configuracoes/senha")]
    public async Task<IActionResult> SalvarSenha([Bind(Prefix = "Senha")] AlterarSenhaLojaForm senha, CancellationToken ct)
    {
        if (ModelState.IsValid)
        {
            try
            {
                await painel.AlterarSenhaAsync(UsuarioId, senha, ct);
                TempData["Mensagem"] = "Senha alterada.";
                return RedirectToAction(nameof(Configuracoes), null, null, "senha");
            }
            catch (RegraDeNegocioException e)
            {
                ModelState.AddModelError("Senha.SenhaAtual", e.Message);
            }
        }
        return View(nameof(Configuracoes), await MontarAsync(null, new AlterarSenhaLojaForm(), ct));
    }

    private async Task<ConfiguracoesLojaVm> MontarAsync(EditarLojaAdminForm? dados, AlterarSenhaLojaForm? senha, CancellationToken ct)
    {
        var loja = await cadastros.ObterLojaAsync(EstabelecimentoId, ct);
        var extra = await db.Estabelecimentos.AsNoTracking().Where(e => e.Id == EstabelecimentoId)
            .Select(e => new { e.LogoUrl, e.Pausada }).FirstAsync(ct);
        return new ConfiguracoesLojaVm
        {
            Loja = loja,
            LogoUrl = extra.LogoUrl,
            Pausada = extra.Pausada,
            Dados = dados ?? AdminCadastrosService.FormDe(loja),
            Horarios = (await painel.HorariosAsync(EstabelecimentoId, ct)).ToList(),
            Senha = senha ?? new AlterarSenhaLojaForm()
        };
    }

    /// <summary>O nome da loja aparece no menu (vem do cookie): depois de trocar, a sessão é renovada.</summary>
    private async Task RenovarSessaoAsync(CancellationToken ct)
    {
        var usuario = await db.Usuarios.Include(u => u.Estabelecimento).FirstAsync(u => u.Id == UsuarioId, ct);
        await SessaoPortal.EntrarAsync(HttpContext, usuario);
    }
}
