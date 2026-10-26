using Microsoft.EntityFrameworkCore;
using Xepa.Domain;
using Xepa.Domain.Entities;

namespace Xepa.Application.Pedidos;

public class PedidoService(IXepaDb db, IReservaPedidos reserva, IServicoMapas mapas)
{
    /// <summary>
    /// Cria o pedido com o estoque reservado (RN03). Na entrega, calcula a rota e a taxa (RN07) antes de reservar.
    /// </summary>
    public async Task<PedidoDto> CriarAsync(int clienteId, CriarPedidoRequest request, CancellationToken ct)
    {
        decimal taxa = 0;
        if (request.TipoEntrega == TipoEntrega.Entrega)
        {
            var endereco = await db.Enderecos.AsNoTracking()
                               .FirstOrDefaultAsync(e => e.Id == request.EnderecoId && e.UsuarioId == clienteId, ct)
                           ?? throw new RegraDeNegocioException("Endereço de entrega inválido.");
            var loja = await db.Ofertas.AsNoTracking()
                           .Where(o => o.Id == request.OfertaId)
                           .Select(o => o.Estabelecimento.Endereco)
                           .FirstOrDefaultAsync(ct)
                       ?? throw new NaoEncontradoException("Oferta não encontrada.");

            if (endereco.Endereco.Latitude is null || endereco.Endereco.Longitude is null
                || loja.Latitude is null || loja.Longitude is null)
                throw new RegraDeNegocioException("Não foi possível localizar o endereço para calcular a entrega.");

            var rota = await mapas.CalcularRotaAsync(
                new Coordenada(loja.Latitude.Value, loja.Longitude.Value),
                new Coordenada(endereco.Endereco.Latitude.Value, endereco.Endereco.Longitude.Value), ct);
            taxa = RegrasEntrega.CalcularTaxa(rota.DistanciaKm);
        }

        var id = await reserva.CriarAsync(clienteId, request.OfertaId, request.Quantidade, request.TipoEntrega, taxa,
            request.EnderecoId, ct);

        if (!string.IsNullOrWhiteSpace(request.Observacao))
        {
            await db.Pedidos.Where(p => p.Id == id)
                .ExecuteUpdateAsync(s => s.SetProperty(p => p.Observacao, request.Observacao.Trim()), ct);
        }

        return await ObterDoClienteAsync(clienteId, id, ct);
    }

    public async Task<IReadOnlyList<PedidoDto>> ListarDoClienteAsync(int clienteId, CancellationToken ct) =>
        await Projetar(db.Pedidos.Where(p => p.ClienteId == clienteId))
            .OrderByDescending(p => p.CriadoEm)
            .ToListAsync(ct);

    public async Task<PedidoDto> ObterDoClienteAsync(int clienteId, int pedidoId, CancellationToken ct) =>
        await Projetar(db.Pedidos.Where(p => p.Id == pedidoId && p.ClienteId == clienteId)).FirstOrDefaultAsync(ct)
        ?? throw new NaoEncontradoException("Pedido não encontrado.");

    /// <summary>Cancelamento pelo cliente (RN05). O trigger do banco devolve o estoque à oferta.</summary>
    public async Task<PedidoDto> CancelarAsync(int clienteId, int pedidoId, CancellationToken ct)
    {
        var pedido = await db.Pedidos.FirstOrDefaultAsync(p => p.Id == pedidoId && p.ClienteId == clienteId, ct)
                     ?? throw new NaoEncontradoException("Pedido não encontrado.");

        // Estorno no gateway entra com a integração do Mercado Pago (Sprint 2).
        pedido.Cancelar();
        await db.SaveChangesAsync(ct);
        return await ObterDoClienteAsync(clienteId, pedidoId, ct);
    }

    /// <summary>
    /// Só em desenvolvimento: aprova o pedido como se o gateway tivesse confirmado o pagamento,
    /// para testar o app antes da integração com o Mercado Pago.
    /// </summary>
    public async Task<PedidoDto> SimularPagamentoAsync(int clienteId, int pedidoId, CancellationToken ct)
    {
        var pedido = await db.Pedidos.FirstOrDefaultAsync(p => p.Id == pedidoId && p.ClienteId == clienteId, ct)
                     ?? throw new NaoEncontradoException("Pedido não encontrado.");
        if (pedido.Status != StatusPedido.AguardandoPagamento)
            throw new RegraDeNegocioException("O pedido não está aguardando pagamento.");

        db.Pagamentos.Add(new Pagamento
        {
            PedidoId = pedido.Id,
            Provedor = "Simulado",
            IdExterno = Guid.NewGuid().ToString("N"),
            Metodo = MetodoPagamento.Pix,
            Status = StatusPagamento.Aprovado,
            Valor = pedido.ValorTotal,
            PagoEm = DateTimeOffset.UtcNow
        });
        pedido.ConfirmarPagamento();
        await db.SaveChangesAsync(ct);
        return await ObterDoClienteAsync(clienteId, pedidoId, ct);
    }

    private static IQueryable<PedidoDto> Projetar(IQueryable<Pedido> pedidos) =>
        pedidos.Select(p => new PedidoDto
        {
            Id = p.Id,
            Status = p.Status,
            TipoEntrega = p.TipoEntrega,
            Quantidade = p.Quantidade,
            PrecoUnitario = p.PrecoUnitario,
            TaxaEntrega = p.TaxaEntrega,
            ValorTotal = p.ValorTotal,
            CodigoRetirada = p.CodigoRetirada,
            CriadoEm = p.CriadoEm,
            EnderecoEntrega = p.EnderecoEntrega,
            Oferta = new PedidoOfertaDto(p.Oferta.Id, p.Oferta.Titulo, p.Oferta.FotoUrl, p.Oferta.EstabelecimentoId,
                p.Oferta.Estabelecimento.Nome, p.Oferta.RetiradaInicio, p.Oferta.RetiradaFim)
        });
}
