using Microsoft.EntityFrameworkCore;
using Xepa.Domain;
using Xepa.Domain.Entities;

namespace Xepa.Application.Administracao;

public record EntregadorAdminDto(int Id, string Nome, string Email, string? Telefone, string? Placa, string? ModeloMoto,
    StatusCadastro Cadastro, bool Bloqueado, bool Online, bool EmCorrida, int Corridas, decimal Ganhos, decimal ARepassar,
    double? Nota, int Avaliacoes, DateTimeOffset CriadoEm);

/// <summary>Taxas de entrega já ganhas por um entregador e ainda fora de repasse.</summary>
public record RepasseEntregadorPendenteDto(int EntregadorId, string Nome, string? Placa, int Corridas, double Km, decimal Valor);

public record RepasseEntregadorDto(int Id, int EntregadorId, string Nome, int Corridas, double Km, decimal Valor,
    DateTimeOffset CriadoEm, DateTimeOffset? PagoEm);

/// <summary>Entregadores parceiros na administração: aprovação do cadastro, desempenho e repasse das taxas de entrega.</summary>
public class AdminEntregadoresService(IXepaDb db)
{
    private static readonly StatusPedido[] EmAndamento =
        [StatusPedido.Confirmado, StatusPedido.EmPreparo, StatusPedido.ProntoParaRetirada, StatusPedido.SaiuParaEntrega];

    public async Task<IReadOnlyList<EntregadorAdminDto>> ListarAsync(StatusCadastro? cadastro, string? busca, CancellationToken ct)
    {
        var entregadores = db.Usuarios.AsNoTracking().Where(u => u.Tipo == TipoUsuario.Entregador);
        if (cadastro is { } c)
            entregadores = entregadores.Where(u => u.CadastroEntregador == c);
        if (!string.IsNullOrWhiteSpace(busca))
        {
            var termo = busca.Trim();
            entregadores = entregadores.Where(u => u.Nome.Contains(termo) || u.Email.Contains(termo) || (u.Placa != null && u.Placa.Contains(termo)));
        }

        var lista = await entregadores
            .OrderBy(u => u.CadastroEntregador == StatusCadastro.Pendente ? 0 : 1).ThenBy(u => u.Nome)
            .Select(u => new
            {
                u.Id, u.Nome, u.Email, u.Telefone, u.Placa, u.ModeloMoto, u.CadastroEntregador, u.Bloqueado, u.Online, u.CriadoEm,
                EmCorrida = db.Pedidos.Any(p => p.EntregadorId == u.Id && EmAndamento.Contains(p.Status)),
                Corridas = db.Pedidos.Count(p => p.EntregadorId == u.Id && p.Status == StatusPedido.Entregue),
                Ganhos = db.Pedidos.Where(p => p.EntregadorId == u.Id && p.Status == StatusPedido.Entregue).Sum(p => (decimal?)p.TaxaEntrega) ?? 0,
                ARepassar = db.Pedidos.Where(p => p.EntregadorId == u.Id && p.Status == StatusPedido.Entregue && p.RepasseEntregadorId == null)
                    .Sum(p => (decimal?)p.TaxaEntrega) ?? 0,
                Nota = db.Pedidos.Where(p => p.EntregadorId == u.Id && p.NotaEntregador != null).Average(p => (double?)p.NotaEntregador),
                Avaliacoes = db.Pedidos.Count(p => p.EntregadorId == u.Id && p.NotaEntregador != null)
            })
            .ToListAsync(ct);

        return lista.Select(u => new EntregadorAdminDto(u.Id, u.Nome, u.Email, u.Telefone, u.Placa, u.ModeloMoto,
                u.CadastroEntregador ?? StatusCadastro.Pendente, u.Bloqueado, u.Online, u.EmCorrida, u.Corridas, u.Ganhos, u.ARepassar,
                u.Nota is { } n ? Math.Round(n, 1) : null, u.Avaliacoes, u.CriadoEm))
            .ToList();
    }

    /// <summary>Aprova ou rejeita o cadastro. Rejeitar também tira o entregador do ar.</summary>
    public async Task AvaliarAsync(int entregadorId, bool aprovar, CancellationToken ct)
    {
        var entregador = await db.Usuarios.FirstOrDefaultAsync(u => u.Id == entregadorId && u.Tipo == TipoUsuario.Entregador, ct)
                         ?? throw new NaoEncontradoException("Entregador não encontrado.");
        entregador.CadastroEntregador = aprovar ? StatusCadastro.Aprovado : StatusCadastro.Rejeitado;
        if (!aprovar)
            entregador.Online = false;
        await db.SaveChangesAsync(ct);
    }

    // ---------- Repasses ----------

    public async Task<IReadOnlyList<RepasseEntregadorPendenteDto>> ListarPendentesAsync(CancellationToken ct)
    {
        var grupos = await db.Pedidos.AsNoTracking()
            .Where(p => p.EntregadorId != null && p.Status == StatusPedido.Entregue && p.RepasseEntregadorId == null)
            .GroupBy(p => new { Id = p.EntregadorId!.Value, p.Entregador!.Nome, p.Entregador.Placa })
            .Select(g => new { g.Key.Id, g.Key.Nome, g.Key.Placa, Corridas = g.Count(), Km = g.Sum(p => p.DistanciaEntregaKm ?? 0),
                Valor = g.Sum(p => p.TaxaEntrega) })
            .ToListAsync(ct);
        return grupos.OrderBy(g => g.Nome)
            .Select(g => new RepasseEntregadorPendenteDto(g.Id, g.Nome, g.Placa, g.Corridas, Math.Round(g.Km, 1), g.Valor))
            .ToList();
    }

    public async Task<IReadOnlyList<RepasseEntregadorDto>> ListarRepassesAsync(int? entregadorId, CancellationToken ct)
    {
        var repasses = db.RepassesEntregadores.AsNoTracking();
        if (entregadorId is { } id)
            repasses = repasses.Where(r => r.EntregadorId == id);
        return await repasses.OrderBy(r => r.PagoEm != null).ThenByDescending(r => r.CriadoEm).Take(100)
            .Select(r => new RepasseEntregadorDto(r.Id, r.EntregadorId, r.Entregador.Nome, r.QuantidadeCorridas, r.KmTotal, r.Valor,
                r.CriadoEm, r.PagoEm))
            .ToListAsync(ct);
    }

    /// <summary>Fecha o repasse com todas as corridas entregues que ainda não foram repassadas.</summary>
    public async Task<int> FecharRepasseAsync(int entregadorId, CancellationToken ct)
    {
        var corridas = await db.Pedidos
            .Where(p => p.EntregadorId == entregadorId && p.Status == StatusPedido.Entregue && p.RepasseEntregadorId == null)
            .ToListAsync(ct);
        var repasse = RepasseEntregador.Fechar(entregadorId, corridas);
        db.RepassesEntregadores.Add(repasse);
        await db.SaveChangesAsync(ct);
        return repasse.Id;
    }

    public async Task MarcarPagoAsync(int repasseId, CancellationToken ct)
    {
        var repasse = await db.RepassesEntregadores.FirstOrDefaultAsync(r => r.Id == repasseId, ct)
                      ?? throw new NaoEncontradoException("Repasse não encontrado.");
        repasse.MarcarPago(DateTimeOffset.UtcNow);
        await db.SaveChangesAsync(ct);
    }
}
