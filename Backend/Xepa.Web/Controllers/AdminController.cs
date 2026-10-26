using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Xepa.Application;
using Xepa.Application.Administracao;
using Xepa.Application.Indicadores;
using Xepa.Domain;
using Xepa.Domain.Entities;

namespace Xepa.Web.Controllers;

/// <summary>Área administrativa da XEPA (RF12): lojas, denúncias, usuários e repasses.</summary>
[Route("admin")]
[Authorize(Roles = nameof(TipoUsuario.Administrador))]
public class AdminController(AdminService admin) : Controller
{
    private int AdministradorId => int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

    [HttpGet("")]
    public async Task<IActionResult> Painel(CancellationToken ct) => View(await admin.PainelAsync(ct));

    // ---------- Lojas ----------

    [HttpGet("lojas")]
    public async Task<IActionResult> Lojas(StatusCadastro? status, CancellationToken ct)
    {
        ViewData["Filtro"] = status;
        return View(await admin.ListarLojasAsync(status, ct));
    }

    [HttpPost("lojas/{id:int}/avaliar")]
    public Task<IActionResult> AvaliarLoja(int id, bool aprovar, CancellationToken ct) =>
        Executar(() => admin.AvaliarLojaAsync(id, aprovar, ct),
            aprovar ? "Loja aprovada: as ofertas dela já podem aparecer no app." : "Cadastro rejeitado.",
            nameof(Lojas));

    [HttpPost("lojas/{id:int}/ativa")]
    public Task<IActionResult> AlterarLoja(int id, bool ativa, CancellationToken ct) =>
        Executar(() => admin.AlterarAtivaAsync(id, ativa, ct),
            ativa ? "Loja reativada." : "Loja suspensa e ofertas tiradas do ar.", nameof(Lojas));

    // ---------- Denúncias ----------

    [HttpGet("denuncias")]
    public async Task<IActionResult> Denuncias(bool todas, CancellationToken ct)
    {
        ViewData["Todas"] = todas;
        return View(await admin.ListarDenunciasAsync(!todas, ct));
    }

    [HttpPost("denuncias/{id:int}/tratar")]
    public Task<IActionResult> TratarDenuncia(int id, StatusDenuncia decisao, string? resposta, bool suspenderLoja,
        CancellationToken ct) =>
        Executar(() => admin.TratarDenunciaAsync(id, decisao, resposta ?? "", suspenderLoja, AdministradorId, ct),
            decisao == StatusDenuncia.Procedente
                ? (suspenderLoja ? "Denúncia procedente; loja suspensa." : "Denúncia marcada como procedente.")
                : "Denúncia marcada como improcedente.",
            nameof(Denuncias));

    // ---------- Usuários ----------

    [HttpGet("usuarios")]
    public async Task<IActionResult> Usuarios(string? busca, CancellationToken ct)
    {
        ViewData["Busca"] = busca;
        return View(await admin.ListarUsuariosAsync(busca, ct));
    }

    [HttpPost("usuarios/{id:int}/bloqueio")]
    public Task<IActionResult> AlterarBloqueio(int id, bool bloqueado, string? voltar, CancellationToken ct) =>
        Executar(() => admin.AlterarBloqueioAsync(id, bloqueado, AdministradorId, ct),
            bloqueado ? "Conta suspensa; as sessões abertas foram encerradas." : "Conta liberada.",
            voltar == nameof(Denuncias) ? nameof(Denuncias) : nameof(Usuarios));

    // ---------- Repasses ----------

    [HttpGet("repasses")]
    public async Task<IActionResult> Repasses(CancellationToken ct) =>
        View((await admin.ListarPendentesDeRepasseAsync(ct), await admin.ListarRepassesAsync(null, ct)));

    [HttpPost("repasses/fechar/{estabelecimentoId:int}")]
    public Task<IActionResult> FecharRepasse(int estabelecimentoId, CancellationToken ct) =>
        Executar(() => admin.FecharRepasseAsync(estabelecimentoId, ct), "Repasse fechado. Marque como pago depois da transferência.",
            nameof(Repasses));

    [HttpPost("repasses/{id:int}/pago")]
    public Task<IActionResult> MarcarPago(int id, CancellationToken ct) =>
        Executar(() => admin.MarcarRepassePagoAsync(id, ct), "Repasse marcado como pago.", nameof(Repasses));

    private async Task<IActionResult> Executar(Func<Task> acao, string sucesso, string voltarPara)
    {
        try
        {
            await acao();
            TempData["Mensagem"] = sucesso;
        }
        catch (Exception e) when (e is RegraDeNegocioException or NaoEncontradoException)
        {
            TempData["Erro"] = e.Message;
        }
        return RedirectToAction(voltarPara);
    }
}

/// <summary>Indicadores de vendas e de impacto do estabelecimento (RF11).</summary>
[Route("impacto")]
[Authorize(Roles = nameof(TipoUsuario.Estabelecimento))]
public class ImpactoController(IndicadoresService indicadores, AdminService admin) : Controller
{
    private int EstabelecimentoId => int.Parse(User.FindFirst(ContaController.ClaimEstabelecimentoId)!.Value);

    [HttpGet("")]
    public async Task<IActionResult> Index(int dias = 30, CancellationToken ct = default)
    {
        ViewData["Repasses"] = await admin.ListarRepassesAsync(EstabelecimentoId, ct);
        return View(await indicadores.DaLojaAsync(EstabelecimentoId, dias, ct));
    }
}
