using Microsoft.EntityFrameworkCore;
using Xepa.Domain;
using Xepa.Domain.Entities;

namespace Xepa.Application.Administracao;

public record PedidoAdminDto(int Id, DateTimeOffset CriadoEm, StatusPedido Status, TipoEntrega Tipo, int ClienteId, string Cliente,
    int LojaId, string Loja, string Oferta, int Quantidade, decimal Total, int? EntregadorId, string? Entregador,
    int? NotaLoja, int? NotaEntregador);

public class FiltroPedidosAdmin
{
    public StatusPedido? Status { get; set; }
    public TipoEntrega? Tipo { get; set; }
    public int? LojaId { get; set; }
    public int? ClienteId { get; set; }
    public int? EntregadorId { get; set; }

    /// <summary>Número do pedido, nome ou e-mail do cliente, ou nome da loja.</summary>
    public string? Busca { get; set; }

    public DateOnly? De { get; set; }
    public DateOnly? Ate { get; set; }
    public int Pagina { get; set; } = 1;
}

public record PaginaPedidosAdmin(IReadOnlyList<PedidoAdminDto> Itens, int Total, int Pagina, int TamanhoPagina, decimal ValorTotal)
{
    public int Paginas => Math.Max(1, (int)Math.Ceiling(Total / (double)TamanhoPagina));
}

public record HistoricoAdminDto(StatusPedido? De, StatusPedido Para, DateTimeOffset Em);

public record PagamentoAdminDto(MetodoPagamento Metodo, StatusPagamento Status, decimal Valor, string Provedor, string IdExterno,
    DateTimeOffset CriadoEm, DateTimeOffset? PagoEm);

public record DenunciaResumoDto(int Id, MotivoDenuncia Motivo, StatusDenuncia Status, DateTimeOffset CriadoEm);

public record PedidoDetalheAdminDto(PedidoAdminDto Resumo, string ClienteEmail, string? ClienteTelefone, decimal PrecoUnitario,
    decimal TaxaEntrega, double? DistanciaKm, string CodigoRetirada, string? Observacao, string? Endereco,
    string? EntregadorTelefone, string? Placa, string? ComentarioLoja, string? ComentarioEntregador, int? RepasseId,
    int? RepasseEntregadorId, IReadOnlyList<HistoricoAdminDto> Historico, IReadOnlyList<PagamentoAdminDto> Pagamentos,
    IReadOnlyList<DenunciaResumoDto> Denuncias);

/// <summary>Todos os pedidos da plataforma, com filtros, e o detalhe de cada um (linha do tempo, pagamento, entregador).</summary>
public class AdminPedidosService(IXepaDb db)
{
    public const int TamanhoPagina = 30;

    public async Task<PaginaPedidosAdmin> ListarAsync(FiltroPedidosAdmin filtro, CancellationToken ct)
    {
        var pedidos = db.Pedidos.AsNoTracking();
        if (filtro.Status is { } s) pedidos = pedidos.Where(p => p.Status == s);
        if (filtro.Tipo is { } t) pedidos = pedidos.Where(p => p.TipoEntrega == t);
        if (filtro.LojaId is { } l) pedidos = pedidos.Where(p => p.Oferta.EstabelecimentoId == l);
        if (filtro.ClienteId is { } c) pedidos = pedidos.Where(p => p.ClienteId == c);
        if (filtro.EntregadorId is { } e) pedidos = pedidos.Where(p => p.EntregadorId == e);
        if (filtro.De is { } de)
        {
            var inicio = new DateTimeOffset(de.ToDateTime(TimeOnly.MinValue), TimeSpan.FromHours(-3));
            pedidos = pedidos.Where(p => p.CriadoEm >= inicio);
        }
        if (filtro.Ate is { } ate)
        {
            var fim = new DateTimeOffset(ate.AddDays(1).ToDateTime(TimeOnly.MinValue), TimeSpan.FromHours(-3));
            pedidos = pedidos.Where(p => p.CriadoEm < fim);
        }
        if (!string.IsNullOrWhiteSpace(filtro.Busca))
        {
            var termo = filtro.Busca.Trim().TrimStart('#');
            pedidos = int.TryParse(termo, out var numero)
                ? pedidos.Where(p => p.Id == numero)
                : pedidos.Where(p => p.Cliente.Nome.Contains(termo) || p.Cliente.Email.Contains(termo)
                                     || p.Oferta.Estabelecimento.Nome.Contains(termo));
        }

        var pagina = Math.Max(1, filtro.Pagina);
        var total = await pedidos.CountAsync(ct);
        var valor = await pedidos.SumAsync(p => (decimal?)p.ValorTotal, ct) ?? 0;
        var itens = await Projetar(pedidos.OrderByDescending(p => p.CriadoEm).Skip((pagina - 1) * TamanhoPagina).Take(TamanhoPagina))
            .ToListAsync(ct);
        return new PaginaPedidosAdmin(itens, total, pagina, TamanhoPagina, valor);
    }

    public async Task<PedidoDetalheAdminDto> ObterAsync(int pedidoId, CancellationToken ct)
    {
        var resumo = await Projetar(db.Pedidos.AsNoTracking().Where(p => p.Id == pedidoId)).FirstOrDefaultAsync(ct)
                     ?? throw new NaoEncontradoException("Pedido não encontrado.");
        var p = await db.Pedidos.AsNoTracking().Where(x => x.Id == pedidoId)
            .Select(x => new
            {
                x.Cliente.Email, x.Cliente.Telefone, x.PrecoUnitario, x.TaxaEntrega, x.DistanciaEntregaKm, x.CodigoRetirada, x.Observacao,
                x.EnderecoEntrega, EntregadorTelefone = x.Entregador != null ? x.Entregador.Telefone : null,
                Placa = x.Entregador != null ? x.Entregador.Placa : null, x.ComentarioLoja, x.ComentarioEntregador, x.RepasseId,
                x.RepasseEntregadorId,
                Historico = x.Historico.OrderBy(h => h.AlteradoEm).Select(h => new HistoricoAdminDto(h.StatusAnterior, h.StatusNovo, h.AlteradoEm)).ToList(),
                Pagamentos = x.Pagamentos.OrderBy(g => g.CriadoEm)
                    .Select(g => new PagamentoAdminDto(g.Metodo, g.Status, g.Valor, g.Provedor, g.IdExterno, g.CriadoEm, g.PagoEm)).ToList()
            })
            .FirstAsync(ct);
        var denuncias = await db.Denuncias.AsNoTracking().Where(d => d.PedidoId == pedidoId).OrderBy(d => d.CriadoEm)
            .Select(d => new DenunciaResumoDto(d.Id, d.Motivo, d.Status, d.CriadoEm))
            .ToListAsync(ct);

        var endereco = p.EnderecoEntrega is { } e
            ? $"{e.Logradouro}, {e.Numero}{(string.IsNullOrWhiteSpace(e.Complemento) ? "" : " - " + e.Complemento)} · {e.Bairro}, {e.Cidade}/{e.Uf}"
            : null;
        return new PedidoDetalheAdminDto(resumo, p.Email, p.Telefone, p.PrecoUnitario, p.TaxaEntrega, p.DistanciaEntregaKm,
            p.CodigoRetirada, p.Observacao, endereco, p.EntregadorTelefone, p.Placa, p.ComentarioLoja, p.ComentarioEntregador,
            p.RepasseId, p.RepasseEntregadorId, p.Historico, p.Pagamentos, denuncias);
    }

    public static IQueryable<PedidoAdminDto> Projetar(IQueryable<Pedido> pedidos) =>
        pedidos.Select(p => new PedidoAdminDto(p.Id, p.CriadoEm, p.Status, p.TipoEntrega, p.ClienteId, p.Cliente.Nome,
            p.Oferta.EstabelecimentoId, p.Oferta.Estabelecimento.Nome, p.Oferta.Titulo, p.Quantidade, p.ValorTotal,
            p.EntregadorId, p.Entregador != null ? p.Entregador.Nome : null, p.NotaLoja, p.NotaEntregador));
}
