using Microsoft.EntityFrameworkCore;
using Xepa.Domain.Entities;

namespace Xepa.Application.Indicadores;

public record VendaDiaDto(DateOnly Dia, int Pedidos, decimal Vendas);

public record OfertaDestaqueDto(string Titulo, int Unidades, decimal Vendas);

/// <summary>Indicadores de vendas e de impacto da loja (RF11).</summary>
public record IndicadoresLojaDto(int Dias, int Pedidos, int Unidades, decimal Vendas, decimal TicketMedio,
    decimal KgSalvos, decimal EconomiaClientes, int Cancelados, decimal RepasseAReceber,
    IReadOnlyList<VendaDiaDto> PorDia, IReadOnlyList<OfertaDestaqueDto> MaisVendidas);

public record AvaliacaoLojaDto(int PedidoId, int Nota, string? Comentario, string Cliente, string Oferta, DateTimeOffset Em);

/// <summary>Nota média dada pelos clientes à loja e às sacolas, quantas de cada estrela e as últimas avaliações.</summary>
public record ReputacaoLojaDto(double? Nota, int Avaliacoes, IReadOnlyList<int> Estrelas, IReadOnlyList<AvaliacaoLojaDto> Ultimas);

/// <summary>Impacto do cliente, mostrado no perfil do app.</summary>
public record ImpactoClienteDto(int Pedidos, decimal KgSalvos, decimal Economia);

public class IndicadoresService(IXepaDb db)
{
    public static readonly TimeZoneInfo FusoBrasilia = TimeZoneInfo.FindSystemTimeZoneById("America/Sao_Paulo");

    /// <summary>Considera pedidos entregues nos últimos <paramref name="dias"/> dias.</summary>
    public async Task<IndicadoresLojaDto> DaLojaAsync(int estabelecimentoId, int dias, CancellationToken ct)
    {
        dias = Math.Clamp(dias, 1, 365);
        var inicio = DateTimeOffset.UtcNow.AddDays(-dias);
        var daLoja = db.Pedidos.AsNoTracking().Where(p => p.Oferta.EstabelecimentoId == estabelecimentoId && p.CriadoEm >= inicio);

        var entregues = await daLoja.Where(p => p.Status == StatusPedido.Entregue)
            .Select(p => new
            {
                p.CriadoEm,
                p.Quantidade,
                Vendas = p.PrecoUnitario * p.Quantidade,
                Kg = (p.Oferta.PesoEstimadoKg ?? 0) * p.Quantidade,
                Economia = (p.Oferta.PrecoOriginal - p.PrecoUnitario) * p.Quantidade,
                p.Oferta.Titulo
            })
            .ToListAsync(ct);

        // Cancelado depois de pago (recusado pela loja ou pelo cliente antes do aceite).
        var cancelados = await daLoja.CountAsync(p => p.Status == StatusPedido.Cancelado
                                                      && p.Historico.Any(h => h.StatusAnterior == StatusPedido.Pendente), ct);
        var aReceber = await db.Repasses.Where(r => r.EstabelecimentoId == estabelecimentoId && r.PagoEm == null)
            .SumAsync(r => (decimal?)r.ValorLiquido, ct) ?? 0;

        var vendas = entregues.Sum(e => e.Vendas);
        var hoje = DateOnly.FromDateTime(TimeZoneInfo.ConvertTime(DateTimeOffset.UtcNow, FusoBrasilia).Date);
        var porDia = Enumerable.Range(0, Math.Min(dias, 30)).Reverse()
            .Select(i => hoje.AddDays(-i))
            .Select(dia =>
            {
                var doDia = entregues.Where(e => DateOnly.FromDateTime(TimeZoneInfo.ConvertTime(e.CriadoEm, FusoBrasilia).Date) == dia).ToList();
                return new VendaDiaDto(dia, doDia.Count, doDia.Sum(e => e.Vendas));
            })
            .ToList();
        var maisVendidas = entregues.GroupBy(e => e.Titulo)
            .Select(g => new OfertaDestaqueDto(g.Key, g.Sum(e => e.Quantidade), g.Sum(e => e.Vendas)))
            .OrderByDescending(o => o.Unidades).Take(5).ToList();

        return new IndicadoresLojaDto(dias, entregues.Count, entregues.Sum(e => e.Quantidade), vendas,
            entregues.Count == 0 ? 0 : Math.Round(vendas / entregues.Count, 2),
            entregues.Sum(e => e.Kg), entregues.Sum(e => e.Economia), cancelados, aReceber, porDia, maisVendidas);
    }

    public async Task<ReputacaoLojaDto> ReputacaoLojaAsync(int estabelecimentoId, CancellationToken ct)
    {
        var notas = await db.Pedidos.AsNoTracking()
            .Where(p => p.Oferta.EstabelecimentoId == estabelecimentoId && p.NotaLoja != null)
            .OrderByDescending(p => p.LojaAvaliadaEm)
            .Select(p => new { p.Id, Nota = p.NotaLoja!.Value, p.ComentarioLoja, Cliente = p.Cliente.Nome, p.Oferta.Titulo, Em = p.LojaAvaliadaEm!.Value })
            .ToListAsync(ct);

        return new ReputacaoLojaDto(
            notas.Count == 0 ? null : Math.Round(notas.Average(n => n.Nota), 1),
            notas.Count,
            Enumerable.Range(1, 5).Reverse().Select(e => notas.Count(n => n.Nota == e)).ToList(),
            notas.Take(8).Select(n => new AvaliacaoLojaDto(n.Id, n.Nota, n.ComentarioLoja, n.Cliente.Split(' ')[0], n.Titulo, n.Em)).ToList());
    }

    public async Task<ImpactoClienteDto> DoClienteAsync(int clienteId, CancellationToken ct)
    {
        var entregues = db.Pedidos.AsNoTracking().Where(p => p.ClienteId == clienteId && p.Status == StatusPedido.Entregue);
        return new ImpactoClienteDto(
            await entregues.CountAsync(ct),
            await entregues.SumAsync(p => (decimal?)(p.Oferta.PesoEstimadoKg * p.Quantidade), ct) ?? 0,
            await entregues.SumAsync(p => (decimal?)((p.Oferta.PrecoOriginal - p.PrecoUnitario) * p.Quantidade), ct) ?? 0);
    }
}
