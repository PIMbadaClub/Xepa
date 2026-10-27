using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Xepa.Api.Seguranca;
using Xepa.Application.Suporte;
using Xepa.Infrastructure.Seguranca;

namespace Xepa.Api.Controllers;

/// <summary>Chat de suporte do app (cliente e entregador); a equipe responde pelo portal administrativo.</summary>
[ApiController]
[Route("api/suporte")]
[Authorize(Roles = PapeisCliente.Todos)]
public class SuporteController(SuporteService suporte) : ControllerBase
{
    /// <summary>A conversa; com <c>depois</c>, só as mensagens com id maior (o app consulta a cada poucos segundos).</summary>
    [HttpGet]
    public Task<ConversaSuporteDto> Conversa(int? depois, CancellationToken ct) => suporte.ConversaAsync(User.UsuarioId(), depois, ct);

    [HttpPost("mensagens")]
    public Task<ConversaSuporteDto> Enviar(EnviarMensagemSuporteRequest request, CancellationToken ct) =>
        suporte.EnviarAsync(User.UsuarioId(), request, ct);

    /// <summary>Respostas da equipe ainda não vistas (bolinha no perfil).</summary>
    [HttpGet("nao-lidas")]
    public async Task<object> NaoLidas(CancellationToken ct) => new { naoLidas = await suporte.NaoLidasAsync(User.UsuarioId(), ct) };

    /// <summary>Pedidos que dá para anexar na mensagem.</summary>
    [HttpGet("pedidos")]
    public Task<IReadOnlyList<PedidoAnexoDto>> Pedidos(CancellationToken ct) => suporte.PedidosParaAnexarAsync(User.UsuarioId(), ct);
}
