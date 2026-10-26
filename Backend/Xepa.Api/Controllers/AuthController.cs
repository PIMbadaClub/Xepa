using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Xepa.Api.Seguranca;
using Xepa.Infrastructure.Seguranca;
using Xepa.Application.Contas;
using Xepa.Application.Indicadores;
using Xepa.Application.Notificacoes;
using Xepa.Application.Pedidos;

namespace Xepa.Api.Controllers;

[ApiController]
[Route("api/auth")]
[EnableRateLimiting(Program.LimiteLogin)]
public class AuthController(ContaService contas) : ControllerBase
{
    /// <summary>Cadastro de cliente pelo app; já devolve a sessão aberta.</summary>
    [HttpPost("registrar")]
    public async Task<ActionResult<SessaoDto>> Registrar(RegistrarRequest request, CancellationToken ct) =>
        StatusCode(StatusCodes.Status201Created, await contas.RegistrarAsync(request, ct));

    [HttpPost("login")]
    public Task<SessaoDto> Login(LoginRequest request, CancellationToken ct) => contas.LoginAsync(request, ct);

    /// <summary>Troca o token de renovação por um novo par de tokens; o antigo deixa de valer.</summary>
    [HttpPost("renovar")]
    public Task<SessaoDto> Renovar(RenovarRequest request, CancellationToken ct) =>
        contas.RenovarAsync(request.TokenRenovacao, ct);

    [HttpPost("sair")]
    public async Task<IActionResult> Sair(RenovarRequest request, CancellationToken ct)
    {
        await contas.SairAsync(request.TokenRenovacao, ct);
        return NoContent();
    }
}

[ApiController]
[Route("api/usuarios")]
[Authorize]
public class UsuariosController(ContaService contas, IndicadoresService indicadores, NotificacaoService notificacoes,
    DenunciaService denuncias) : ControllerBase
{
    [HttpGet("me")]
    public Task<UsuarioDto> Me(CancellationToken ct) => contas.ObterAsync(User.UsuarioId(), ct);

    [HttpPut("me")]
    public Task<UsuarioDto> AtualizarPerfil(AtualizarPerfilRequest request, CancellationToken ct) =>
        contas.AtualizarPerfilAsync(User.UsuarioId(), request, ct);

    /// <summary>Troca a senha. Mande o token de renovação atual no cabeçalho X-Token-Renovacao para manter esta sessão.</summary>
    [HttpPost("me/senha")]
    public async Task<IActionResult> AlterarSenha(AlterarSenhaRequest request, [FromHeader(Name = "X-Token-Renovacao")] string? tokenAtual,
        CancellationToken ct)
    {
        await contas.AlterarSenhaAsync(User.UsuarioId(), request, tokenAtual, ct);
        return NoContent();
    }

    /// <summary>Central de notificações: status dos pedidos, respostas de denúncia e ofertas das lojas favoritas.</summary>
    [HttpGet("me/notificacoes")]
    [Authorize(Roles = "Cliente")]
    public Task<CaixaNotificacoesDto> Notificacoes(int limite = 50, CancellationToken ct = default) =>
        notificacoes.ListarAsync(User.UsuarioId(), limite, ct);

    [HttpPost("me/notificacoes/lidas")]
    [Authorize(Roles = "Cliente")]
    public async Task<IActionResult> MarcarLidas(CancellationToken ct)
    {
        await notificacoes.MarcarLidasAsync(User.UsuarioId(), ct);
        return NoContent();
    }

    [HttpGet("me/denuncias")]
    [Authorize(Roles = "Cliente")]
    public Task<List<DenunciaDto>> MinhasDenuncias(CancellationToken ct) => denuncias.ListarDoClienteAsync(User.UsuarioId(), ct);

    /// <summary>Quanto o cliente já salvou do lixo e economizou com pedidos entregues.</summary>
    [HttpGet("me/impacto")]
    [Authorize(Roles = "Cliente")]
    public Task<ImpactoClienteDto> Impacto(CancellationToken ct) => indicadores.DoClienteAsync(User.UsuarioId(), ct);
}
