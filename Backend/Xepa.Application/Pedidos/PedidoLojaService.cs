using System.ComponentModel.DataAnnotations;
using Microsoft.EntityFrameworkCore;
using Xepa.Application.Pagamentos;
using Xepa.Domain;
using Xepa.Domain.Entities;

namespace Xepa.Application.Pedidos;

public record PedidoLojaDto(int Id, StatusPedido Status, TipoEntrega TipoEntrega, string Cliente, string Oferta,
    int Quantidade, decimal ValorTotal, DateTimeOffset CriadoEm, DateTimeOffset RetiradaFim, string? Bairro,
    double? DistanciaKm, string? Entregador, string? Observacao);

public class AlterarStatusRequest
{
    [Required]
    public StatusPedido Status { get; init; }
}

public class ConfirmarRetiradaRequest
{
    [Required, RegularExpression(@"^\d{4}$", ErrorMessage = "O código tem 4 dígitos.")]
    public required string Codigo { get; init; }
}

/// <summary>Pedidos recebidos pelo estabelecimento: aceitar, recusar, avançar e confirmar a retirada.</summary>
public class PedidoLojaService(IXepaDb db, PagamentoService pagamentos, INotificadorPedidos notificador)
{
    /// <summary>Pedidos pagos ainda em andamento e os concluídos nas últimas 24 horas.</summary>
    public async Task<IReadOnlyList<PedidoLojaDto>> ListarAsync(int estabelecimentoId, CancellationToken ct)
    {
        var desde = DateTimeOffset.UtcNow.AddHours(-24);
        var abertos = new[] { StatusPedido.Pendente, StatusPedido.Confirmado, StatusPedido.EmPreparo,
            StatusPedido.ProntoParaRetirada, StatusPedido.SaiuParaEntrega };

        var pedidos = await db.Pedidos.AsNoTracking()
            .Where(p => p.Oferta.EstabelecimentoId == estabelecimentoId
                        && (abertos.Contains(p.Status)
                            || ((p.Status == StatusPedido.Entregue || p.Status == StatusPedido.Cancelado) && p.CriadoEm >= desde
                                && p.Historico.Any(h => h.StatusAnterior == StatusPedido.Pendente || h.StatusNovo == StatusPedido.Entregue))))
            .OrderBy(p => p.CriadoEm)
            .Select(p => new
            {
                p.Id, p.Status, p.TipoEntrega, Cliente = p.Cliente.Nome, Oferta = p.Oferta.Titulo, p.Quantidade,
                p.ValorTotal, p.CriadoEm, p.Oferta.RetiradaFim, p.EnderecoEntrega, Loja = p.Oferta.Estabelecimento.Endereco,
                Entregador = p.Entregador != null ? p.Entregador.Nome : null, p.Observacao
            })
            .ToListAsync(ct);

        return pedidos.Select(p => new PedidoLojaDto(p.Id, p.Status, p.TipoEntrega, PrimeiroNome(p.Cliente), p.Oferta,
            p.Quantidade, p.ValorTotal, p.CriadoEm, p.RetiradaFim, p.EnderecoEntrega?.Bairro,
            Distancia(p.Loja, p.EnderecoEntrega), p.Entregador, p.Observacao)).ToList();
    }

    /// <summary>Muda o status (ciclo de vida do pedido). Recusar = cancelar com estorno.</summary>
    public async Task AlterarStatusAsync(int estabelecimentoId, int pedidoId, StatusPedido novo, CancellationToken ct)
    {
        var pedido = await BuscarAsync(estabelecimentoId, pedidoId, ct);
        if (novo is StatusPedido.SaiuParaEntrega)
            throw new RegraDeNegocioException("A saída para entrega é registrada pelo entregador no app.");

        pedido.AvancarStatus(novo);
        await db.SaveChangesAsync(ct);
        if (novo == StatusPedido.Cancelado)
            await pagamentos.EstornarAprovadosAsync(pedido, ct);
        await notificador.PedidoAlteradoAsync(pedido.Id, ct);
    }

    public async Task ConfirmarRetiradaAsync(int estabelecimentoId, int pedidoId, string codigo, CancellationToken ct)
    {
        var pedido = await BuscarAsync(estabelecimentoId, pedidoId, ct);
        pedido.ConfirmarRetirada(codigo);
        await db.SaveChangesAsync(ct);
        await notificador.PedidoAlteradoAsync(pedido.Id, ct);
    }

    private async Task<Pedido> BuscarAsync(int estabelecimentoId, int pedidoId, CancellationToken ct) =>
        await db.Pedidos.FirstOrDefaultAsync(p => p.Id == pedidoId && p.Oferta.EstabelecimentoId == estabelecimentoId, ct)
        ?? throw new NaoEncontradoException("Pedido não encontrado.");

    private static string PrimeiroNome(string nome)
    {
        var partes = nome.Split(' ', StringSplitOptions.RemoveEmptyEntries);
        return partes.Length > 1 ? $"{partes[0]} {partes[^1][0]}." : nome;
    }

    private static double? Distancia(Endereco loja, Endereco? destino) =>
        destino is { Latitude: { } la, Longitude: { } lo } && loja is { Latitude: { } lb, Longitude: { } lob }
            ? Math.Round(Geo.DistanciaKm(new Coordenada(lb, lob), new Coordenada(la, lo)), 1)
            : null;
}
