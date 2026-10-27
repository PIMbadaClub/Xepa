using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Xepa.Api.Seguranca;
using Xepa.Application;
using Xepa.Domain;
using Xepa.Infrastructure.Seguranca;
using Xepa.Application.Contas;
using Xepa.Application.Indicadores;
using Xepa.Application.Notificacoes;
using Xepa.Application.Pedidos;

namespace Xepa.Api.Controllers;

public class TrocarCodigoGoogleRequest
{
    [System.ComponentModel.DataAnnotations.Required]
    public required string Codigo { get; init; }
}

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

    /// <summary>Envia o código de 6 dígitos por e-mail. Responde igual exista ou não a conta.</summary>
    [HttpPost("recuperar-senha")]
    public async Task<IActionResult> RecuperarSenha(SolicitarRecuperacaoRequest request, [FromServices] RecuperacaoSenhaService recuperacao,
        CancellationToken ct)
    {
        await recuperacao.SolicitarAsync(request.Email, ct);
        return NoContent();
    }

    /// <summary>Troca a senha com o código recebido por e-mail e abre a sessão.</summary>
    [HttpPost("redefinir-senha")]
    public Task<SessaoDto> RedefinirSenha(RedefinirSenhaRequest request, CancellationToken ct) =>
        contas.RedefinirSenhaAsync(request, ct);

    /// <summary>Começa o "Continuar com Google": manda o navegador para o Google e depois de volta ao app.</summary>
    /// <param name="retorno">Endereço do app que recebe o resultado (precisa ser uma origem liberada no CORS).</param>
    [HttpGet("google")]
    public IActionResult Google(string retorno, [FromServices] LoginGoogle google, [FromServices] IConfiguration config)
    {
        if (!google.Configurado)
            return Problem("O login com Google não está configurado.", statusCode: StatusCodes.Status503ServiceUnavailable);
        if (!RetornoPermitido(retorno, config))
            return Problem("Endereço de retorno não permitido.", statusCode: StatusCodes.Status400BadRequest);
        return Redirect(google.UrlAutorizacao(retorno, UrlCallbackGoogle()));
    }

    [HttpGet("google/retorno")]
    [ApiExplorerSettings(IgnoreApi = true)]
    public async Task<IActionResult> GoogleRetorno(string? state, string? code, string? error, [FromServices] LoginGoogle google,
        CancellationToken ct)
    {
        string? retorno = null;
        try
        {
            if (state is null || code is null)
                throw new RegraDeNegocioException(error == "access_denied" ? "Login com Google cancelado." : "O Google não confirmou o login.");
            var (destino, conta) = await google.ConcluirAsync(state, code, UrlCallbackGoogle(), ct);
            retorno = destino;
            var sessao = await contas.EntrarComGoogleAsync(conta, ct);
            return Redirect(ComParametro(retorno, "google", google.GuardarSessao(sessao)));
        }
        catch (Exception e) when (e is RegraDeNegocioException or AcessoNegadoException)
        {
            return retorno is null
                ? Problem(e.Message, statusCode: StatusCodes.Status400BadRequest)
                : Redirect(ComParametro(retorno, "google_erro", e.Message));
        }
    }

    /// <summary>O app troca o código de uso único (2 min) pela sessão.</summary>
    [HttpPost("google/sessao")]
    public SessaoDto GoogleSessao(TrocarCodigoGoogleRequest request, [FromServices] LoginGoogle google) =>
        google.TrocarCodigo(request.Codigo);

    private string UrlCallbackGoogle()
    {
        var local = Request.Host.Host is "localhost" or "127.0.0.1";
        return $"{(local ? Request.Scheme : "https")}://{Request.Host}/api/auth/google/retorno";
    }

    /// <summary>Retorno do app Android: o navegador abre xepa://login e o sistema devolve o código ao app.</summary>
    public const string RetornoAppAndroid = "xepa://login";

    private static bool RetornoPermitido(string retorno, IConfiguration config)
    {
        if (retorno == RetornoAppAndroid)
            return true;
        if (!Uri.TryCreate(retorno, UriKind.Absolute, out var uri) || uri.Scheme is not ("https" or "http"))
            return false;
        var origem = uri.GetLeftPart(UriPartial.Authority);
        var origens = config.GetSection("Cors:Origens").Get<string[]>() ?? [];
        return origens.Any(o => string.Equals(o.TrimEnd('/'), origem, StringComparison.OrdinalIgnoreCase))
               || uri.Host is "localhost" or "127.0.0.1";
    }

    private static string ComParametro(string url, string nome, string valor)
    {
        // Tira um resultado antigo e coloca o novo na query (antes do # das rotas do app web).
        var semFragmento = url.Split('#')[0];
        var partes = semFragmento.Split('?', 2);
        var query = partes.Length > 1
            ? string.Join('&', partes[1].Split('&').Where(p => !p.StartsWith("google=") && !p.StartsWith("google_erro=")))
            : "";
        var novo = $"{nome}={Uri.EscapeDataString(valor)}";
        return $"{partes[0]}?{(query.Length > 0 ? query + "&" : "")}{novo}";
    }

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
    DenunciaService denuncias, PushService push, ExclusaoContaService exclusao) : ControllerBase
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
    [Authorize(Roles = PapeisCliente.Todos)]
    public Task<CaixaNotificacoesDto> Notificacoes(int limite = 50, CancellationToken ct = default) =>
        notificacoes.ListarAsync(User.UsuarioId(), limite, ct);

    [HttpPost("me/notificacoes/lidas")]
    [Authorize(Roles = PapeisCliente.Todos)]
    public async Task<IActionResult> MarcarLidas(CancellationToken ct)
    {
        await notificacoes.MarcarLidasAsync(User.UsuarioId(), ct);
        return NoContent();
    }

    /// <summary>Registra o celular para receber notificações push (token do Firebase). Chamado a cada entrada no app.</summary>
    [HttpPost("me/dispositivos")]
    public async Task<IActionResult> RegistrarDispositivo(RegistrarDispositivoRequest request, CancellationToken ct)
    {
        await push.RegistrarAsync(User.UsuarioId(), request, ct);
        return NoContent();
    }

    /// <summary>Para de mandar push para este celular (ao sair da conta).</summary>
    [HttpDelete("me/dispositivos/{token}")]
    public async Task<IActionResult> RemoverDispositivo(string token, CancellationToken ct)
    {
        await push.RemoverAsync(User.UsuarioId(), token, ct);
        return NoContent();
    }

    /// <summary>Exclui a conta (LGPD): apaga os dados pessoais e encerra todas as sessões. Não dá para desfazer.</summary>
    [HttpPost("me/excluir")]
    [Authorize(Roles = PapeisCliente.Todos)]
    public async Task<IActionResult> Excluir(ExcluirContaRequest request, CancellationToken ct)
    {
        await exclusao.ExcluirAsync(User.UsuarioId(), request, ct);
        return NoContent();
    }

    [HttpGet("me/denuncias")]
    [Authorize(Roles = PapeisCliente.Todos)]
    public Task<List<DenunciaDto>> MinhasDenuncias(CancellationToken ct) => denuncias.ListarDoClienteAsync(User.UsuarioId(), ct);

    /// <summary>Quanto o cliente já salvou do lixo e economizou com pedidos entregues.</summary>
    [HttpGet("me/impacto")]
    [Authorize(Roles = PapeisCliente.Todos)]
    public Task<ImpactoClienteDto> Impacto(CancellationToken ct) => indicadores.DoClienteAsync(User.UsuarioId(), ct);
}
