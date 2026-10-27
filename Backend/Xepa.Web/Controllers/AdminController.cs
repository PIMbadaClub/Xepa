using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Xepa.Application;
using Xepa.Application.Administracao;
using Xepa.Application.Contas;
using Xepa.Application.Indicadores;
using Xepa.Application.Suporte;
using Xepa.Domain;
using Xepa.Domain.Entities;

namespace Xepa.Web.Controllers;

/// <summary>Área administrativa da XEPA (RF12): pedidos, lojas, entregadores, usuários, denúncias e repasses.</summary>
[Route("admin")]
[Authorize(Roles = nameof(TipoUsuario.Administrador))]
public class AdminController(AdminService admin, AdminEntregadoresService entregadores, AdminPedidosService pedidos,
    AdminCadastrosService cadastros, RecuperacaoSenhaService recuperacao, SuporteService suporte) : Controller
{
    private int AdministradorId => int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

    [HttpGet("")]
    public async Task<IActionResult> Painel(CancellationToken ct) => View(await admin.PainelAsync(ct));

    // ---------- Pedidos ----------

    [HttpGet("pedidos")]
    public async Task<IActionResult> Pedidos([FromQuery] FiltroPedidosAdmin filtro, CancellationToken ct)
    {
        ViewData["Filtro"] = filtro;
        return View(await pedidos.ListarAsync(filtro, ct));
    }

    [HttpGet("pedidos/{id:int}")]
    public async Task<IActionResult> Pedido(int id, CancellationToken ct)
    {
        try
        {
            return View(await pedidos.ObterAsync(id, ct));
        }
        catch (NaoEncontradoException)
        {
            return NotFound();
        }
    }

    // ---------- Lojas ----------

    [HttpGet("lojas")]
    public async Task<IActionResult> Lojas(StatusCadastro? status, CancellationToken ct)
    {
        ViewData["Filtro"] = status;
        return View(await admin.ListarLojasAsync(status, ct));
    }

    [HttpGet("lojas/{id:int}")]
    public async Task<IActionResult> Loja(int id, CancellationToken ct)
    {
        try
        {
            var loja = await cadastros.ObterLojaAsync(id, ct);
            return View((loja, AdminCadastrosService.FormDe(loja)));
        }
        catch (NaoEncontradoException)
        {
            return NotFound();
        }
    }

    [HttpPost("lojas/{id:int}")]
    public async Task<IActionResult> Loja(int id, [Bind(Prefix = "Item2")] EditarLojaAdminForm form, CancellationToken ct)
    {
        if (ModelState.IsValid)
        {
            try
            {
                await cadastros.AtualizarLojaAsync(id, form, ct);
                TempData["Mensagem"] = "Dados da loja atualizados.";
                return RedirectToAction(nameof(Loja), new { id });
            }
            catch (RegraDeNegocioException e)
            {
                ModelState.AddModelError("", e.Message);
            }
        }
        return View((await cadastros.ObterLojaAsync(id, ct), form));
    }

    [HttpPost("lojas/{id:int}/avaliar")]
    public Task<IActionResult> AvaliarLoja(int id, bool aprovar, string? voltar, CancellationToken ct) =>
        Executar(() => admin.AvaliarLojaAsync(id, aprovar, ct),
            aprovar ? "Loja aprovada: as ofertas dela já podem aparecer no app." : "Cadastro rejeitado.",
            voltar == nameof(Loja) ? nameof(Loja) : nameof(Lojas), voltar == nameof(Loja) ? new { id } : null);

    [HttpPost("lojas/{id:int}/ativa")]
    public Task<IActionResult> AlterarLoja(int id, bool ativa, string? voltar, CancellationToken ct) =>
        Executar(() => admin.AlterarAtivaAsync(id, ativa, ct),
            ativa ? "Loja reativada." : "Loja suspensa e ofertas tiradas do ar.",
            voltar == nameof(Loja) ? nameof(Loja) : nameof(Lojas), voltar == nameof(Loja) ? new { id } : null);

    // ---------- Entregadores ----------

    [HttpGet("entregadores")]
    public async Task<IActionResult> Entregadores(StatusCadastro? status, string? busca, CancellationToken ct)
    {
        ViewData["Filtro"] = status;
        ViewData["Busca"] = busca;
        return View(await entregadores.ListarAsync(status, busca, ct));
    }

    [HttpPost("entregadores/{id:int}/avaliar")]
    public Task<IActionResult> AvaliarEntregador(int id, bool aprovar, string? voltar, CancellationToken ct) =>
        Executar(() => entregadores.AvaliarAsync(id, aprovar, ct),
            aprovar ? "Entregador aprovado: ele já pode ficar online." : "Cadastro do entregador rejeitado.",
            voltar == nameof(Usuario) ? nameof(Usuario) : nameof(Entregadores), voltar == nameof(Usuario) ? new { id } : null);

    // ---------- Usuários ----------

    [HttpGet("usuarios")]
    public async Task<IActionResult> Usuarios(string? busca, TipoUsuario? tipo, CancellationToken ct)
    {
        ViewData["Busca"] = busca;
        ViewData["Tipo"] = tipo;
        return View(await admin.ListarUsuariosAsync(busca, tipo, ct));
    }

    [HttpGet("usuarios/{id:int}")]
    public async Task<IActionResult> Usuario(int id, CancellationToken ct)
    {
        try
        {
            var u = await cadastros.ObterUsuarioAsync(id, ct);
            return View((u, new EditarUsuarioAdminForm { Nome = u.Nome, Email = u.Email, Telefone = u.Telefone, Placa = u.Placa, ModeloMoto = u.ModeloMoto }));
        }
        catch (NaoEncontradoException)
        {
            return NotFound();
        }
    }

    [HttpPost("usuarios/{id:int}")]
    public async Task<IActionResult> Usuario(int id, [Bind(Prefix = "Item2")] EditarUsuarioAdminForm form, CancellationToken ct)
    {
        if (ModelState.IsValid)
        {
            try
            {
                await cadastros.AtualizarUsuarioAsync(id, form, ct);
                TempData["Mensagem"] = "Dados da conta atualizados.";
                return RedirectToAction(nameof(Usuario), new { id });
            }
            catch (RegraDeNegocioException e)
            {
                ModelState.AddModelError("", e.Message);
            }
        }
        return View((await cadastros.ObterUsuarioAsync(id, ct), form));
    }

    /// <summary>Manda à pessoa o código de "Esqueci minha senha" (a equipe nunca vê nem define a senha).</summary>
    [HttpPost("usuarios/{id:int}/recuperar-senha")]
    public async Task<IActionResult> EnviarRecuperacao(int id, CancellationToken ct)
    {
        var u = await cadastros.ObterUsuarioAsync(id, ct);
        await recuperacao.SolicitarAsync(u.Email, ct);
        TempData["Mensagem"] = $"Código para criar uma nova senha enviado para {u.Email}.";
        return RedirectToAction(nameof(Usuario), new { id });
    }

    [HttpPost("usuarios/{id:int}/bloqueio")]
    public Task<IActionResult> AlterarBloqueio(int id, bool bloqueado, string? voltar, CancellationToken ct) =>
        Executar(() => admin.AlterarBloqueioAsync(id, bloqueado, AdministradorId, ct),
            bloqueado ? "Conta suspensa; as sessões abertas foram encerradas." : "Conta liberada.",
            voltar is nameof(Denuncias) or nameof(Entregadores) or nameof(Usuario) ? voltar : nameof(Usuarios),
            voltar == nameof(Usuario) ? new { id } : null);

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

    // ---------- Suporte ----------

    [HttpGet("suporte")]
    public async Task<IActionResult> Suporte(StatusConversa? status, string? busca, CancellationToken ct)
    {
        ViewData["Status"] = status;
        ViewData["Busca"] = busca;
        return View(await suporte.ListarAsync(status, busca, ct));
    }

    [HttpGet("suporte/{id:int}")]
    public async Task<IActionResult> Conversa(int id, CancellationToken ct)
    {
        try
        {
            return View(await suporte.ObterAdminAsync(id, ct));
        }
        catch (NaoEncontradoException)
        {
            return NotFound();
        }
    }

    /// <summary>Mensagens novas da conversa aberta (a tela consulta a cada poucos segundos).</summary>
    [HttpGet("suporte/{id:int}/mensagens")]
    public async Task<IActionResult> MensagensConversa(int id, int depois, CancellationToken ct) =>
        Json(ChatSuporte.Itens(await suporte.NovasAdminAsync(id, depois, ct)));

    [HttpPost("suporte/{id:int}/responder")]
    public async Task<IActionResult> ResponderConversa(int id, string? texto, CancellationToken ct)
    {
        try
        {
            await suporte.ResponderAsync(id, AdministradorId, texto ?? "", ct);
            return NoContent();
        }
        catch (RegraDeNegocioException e)
        {
            return BadRequest(new { erro = e.Message });
        }
    }

    [HttpPost("suporte/{id:int}/resolver")]
    public Task<IActionResult> ResolverConversa(int id, CancellationToken ct) =>
        Executar(() => suporte.ResolverAsync(id, ct), "Atendimento encerrado. Se o usuário escrever de novo, a conversa reabre.",
            nameof(Suporte));

    // ---------- Repasses ----------

    [HttpGet("repasses")]
    public async Task<IActionResult> Repasses(string? aba, CancellationToken ct)
    {
        ViewData["Aba"] = aba == "entregadores" ? "entregadores" : "lojas";
        ViewData["Entregadores"] = (await entregadores.ListarPendentesAsync(ct), await entregadores.ListarRepassesAsync(null, ct));
        return View((await admin.ListarPendentesDeRepasseAsync(ct), await admin.ListarRepassesAsync(null, ct)));
    }

    [HttpPost("repasses/fechar/{estabelecimentoId:int}")]
    public Task<IActionResult> FecharRepasse(int estabelecimentoId, CancellationToken ct) =>
        Executar(() => admin.FecharRepasseAsync(estabelecimentoId, ct), "Repasse fechado. Marque como pago depois da transferência.",
            nameof(Repasses));

    [HttpPost("repasses/{id:int}/pago")]
    public Task<IActionResult> MarcarPago(int id, CancellationToken ct) =>
        Executar(() => admin.MarcarRepassePagoAsync(id, ct), "Repasse marcado como pago.", nameof(Repasses));

    [HttpPost("repasses/entregadores/fechar/{entregadorId:int}")]
    public Task<IActionResult> FecharRepasseEntregador(int entregadorId, CancellationToken ct) =>
        Executar(() => entregadores.FecharRepasseAsync(entregadorId, ct),
            "Repasse do entregador fechado. Marque como pago depois da transferência.", nameof(Repasses), new { aba = "entregadores" });

    [HttpPost("repasses/entregadores/{id:int}/pago")]
    public Task<IActionResult> MarcarPagoEntregador(int id, CancellationToken ct) =>
        Executar(() => entregadores.MarcarPagoAsync(id, ct), "Repasse do entregador marcado como pago.", nameof(Repasses),
            new { aba = "entregadores" });

    private async Task<IActionResult> Executar(Func<Task> acao, string sucesso, string voltarPara, object? rota = null)
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
        return RedirectToAction(voltarPara, rota);
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
        ViewData["Reputacao"] = await indicadores.ReputacaoLojaAsync(EstabelecimentoId, ct);
        return View(await indicadores.DaLojaAsync(EstabelecimentoId, dias, ct));
    }
}
