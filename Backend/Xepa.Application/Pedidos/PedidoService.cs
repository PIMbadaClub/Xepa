using Microsoft.EntityFrameworkCore;
using Xepa.Application.Pagamentos;
using Xepa.Domain;
using Xepa.Domain.Entities;

namespace Xepa.Application.Pedidos;

public class PedidoService(IXepaDb db, IReservaPedidos reserva, IServicoMapas mapas, PagamentoService pagamentos,
    INotificadorPedidos notificador)
{
    /// <summary>
    /// Cria o pedido com o estoque reservado (RN03). Na entrega, calcula a rota e a taxa (RN07) antes de reservar.
    /// </summary>
    public async Task<PedidoDto> CriarAsync(int clienteId, CriarPedidoRequest request, CancellationToken ct)
    {
        decimal taxa = 0;
        double? distancia = null;
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
            distancia = rota.DistanciaKm;
        }

        var id = await reserva.CriarAsync(clienteId, request.OfertaId, request.Quantidade, request.TipoEntrega, taxa,
            request.EnderecoId, ct);

        if (distancia is { } km)
            await db.Pedidos.Where(p => p.Id == id).ExecuteUpdateAsync(s => s.SetProperty(p => p.DistanciaEntregaKm, km), ct);

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

    /// <summary>Cancelamento pelo cliente (RN05): o trigger devolve o estoque e o pagamento aprovado é estornado.</summary>
    public async Task<PedidoDto> CancelarAsync(int clienteId, int pedidoId, CancellationToken ct)
    {
        var pedido = await db.Pedidos.FirstOrDefaultAsync(p => p.Id == pedidoId && p.ClienteId == clienteId, ct)
                     ?? throw new NaoEncontradoException("Pedido não encontrado.");

        pedido.Cancelar();
        await db.SaveChangesAsync(ct);
        await pagamentos.EstornarAprovadosAsync(pedido, ct);
        await notificador.PedidoAlteradoAsync(pedido.Id, ct);
        return await ObterDoClienteAsync(clienteId, pedidoId, ct);
    }

    /// <summary>Última posição do entregador e os pontos de origem e destino, para o mapa do app.</summary>
    public async Task<RastreioDto> ObterRastreioAsync(int clienteId, int pedidoId, CancellationToken ct)
    {
        var dados = await db.Pedidos.AsNoTracking()
                        .Where(p => p.Id == pedidoId && p.ClienteId == clienteId)
                        .Select(p => new
                        {
                            p.Status,
                            Loja = p.Oferta.Estabelecimento.Endereco,
                            p.EnderecoEntrega,
                            Ultima = p.Rastreios.OrderByDescending(r => r.RegistradoEm).FirstOrDefault(),
                            Entregador = p.Entregador != null ? p.Entregador.Nome : null
                        })
                        .FirstOrDefaultAsync(ct)
                    ?? throw new NaoEncontradoException("Pedido não encontrado.");

        var loja = Ponto(dados.Loja.Latitude, dados.Loja.Longitude);
        var destino = dados.EnderecoEntrega is null ? null : Ponto(dados.EnderecoEntrega.Latitude, dados.EnderecoEntrega.Longitude);
        var rota = loja is not null && destino is not null ? (await mapas.CalcularRotaAsync(loja, destino, ct)).Pontos : null;

        return new RastreioDto(
            dados.Status,
            loja,
            destino,
            dados.Ultima is null ? null : new Coordenada(dados.Ultima.Latitude, dados.Ultima.Longitude),
            dados.Ultima?.RegistradoEm,
            rota,
            dados.Entregador?.Split(' ')[0]);
    }

    private static Coordenada? Ponto(double? lat, double? lng) =>
        lat is { } a && lng is { } b ? new Coordenada(a, b) : null;

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
