using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using Xepa.Application;
using Xepa.Application.Pagamentos;
using Xepa.Domain.Entities;
using Xepa.Infrastructure.Seguranca;

namespace Xepa.Api.TempoReal;

/// <summary>
/// Canal em tempo real. Grupos: "usuario-{id}" (cliente), "loja-{id}" (portal e entregadores da loja)
/// e "pedido-{id}" (quem acompanha um pedido no mapa).
/// </summary>
[Authorize]
public class PedidosHub(IXepaDb db) : Hub
{
    public const string Rota = "/hubs/pedidos";
    public const string GrupoEntregadores = "entregadores";

    public override async Task OnConnectedAsync()
    {
        var usuarioId = Context.User!.UsuarioId();
        await Groups.AddToGroupAsync(Context.ConnectionId, $"usuario-{usuarioId}");

        if (Context.User!.FindFirst(GeradorTokenJwt.ClaimEstabelecimento)?.Value is { } loja)
            await Groups.AddToGroupAsync(Context.ConnectionId, $"loja-{loja}");

        // Entregadores parceiros recebem as mudanças de todos os pedidos com entrega (corridas novas e aceitas).
        if (Context.User!.IsInRole(nameof(TipoUsuario.Entregador)))
            await Groups.AddToGroupAsync(Context.ConnectionId, GrupoEntregadores);

        await base.OnConnectedAsync();
    }

    /// <summary>Entra no grupo do pedido para receber status e posição do entregador.</summary>
    public async Task AcompanharPedido(int pedidoId)
    {
        var usuarioId = Context.User!.UsuarioId();
        var lojaClaim = Context.User!.FindFirst(GeradorTokenJwt.ClaimEstabelecimento)?.Value;
        var podeVer = await db.Pedidos.AnyAsync(p => p.Id == pedidoId
            && (p.ClienteId == usuarioId
                || p.EntregadorId == usuarioId
                || (lojaClaim != null && p.Oferta.EstabelecimentoId.ToString() == lojaClaim)));
        if (!podeVer)
            throw new HubException("Pedido não encontrado.");

        await Groups.AddToGroupAsync(Context.ConnectionId, $"pedido-{pedidoId}");
    }
}

public class NotificadorSignalR(IHubContext<PedidosHub> hub, IServiceScopeFactory scopes) : INotificadorPedidos
{
    public async Task PedidoAlteradoAsync(int pedidoId, CancellationToken ct)
    {
        using var scope = scopes.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<IXepaDb>();
        var p = await db.Pedidos.AsNoTracking()
            .Where(x => x.Id == pedidoId)
            .Select(x => new { x.Status, x.ClienteId, x.Oferta.EstabelecimentoId, x.TipoEntrega })
            .FirstOrDefaultAsync(ct);
        if (p is null)
            return;

        var evento = new { pedidoId, status = p.Status.ToString(), em = DateTimeOffset.UtcNow };
        var grupos = new List<string> { $"pedido-{pedidoId}", $"usuario-{p.ClienteId}", $"loja-{p.EstabelecimentoId}" };
        if (p.TipoEntrega == TipoEntrega.Entrega)
            grupos.Add(PedidosHub.GrupoEntregadores);
        await hub.Clients.Groups(grupos).SendAsync("PedidoAlterado", evento, ct);
    }

    public Task PosicaoEntregadorAsync(int pedidoId, double latitude, double longitude, CancellationToken ct) =>
        hub.Clients.Group($"pedido-{pedidoId}")
            .SendAsync("PosicaoEntregador", new { pedidoId, latitude, longitude, em = DateTimeOffset.UtcNow }, ct);
}
