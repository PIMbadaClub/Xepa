using Microsoft.EntityFrameworkCore;
using Xepa.Domain.Entities;

namespace Xepa.Application.Ofertas;

public record LojaFavoritaDto(int Id, string Nome, CategoriaEstabelecimento Categoria, string? LogoUrl, string Bairro,
    int OfertasAgora, decimal? PrecoMinimo);

/// <summary>Lojas favoritas do cliente (RF10). Só lojas visíveis no app podem ser favoritadas.</summary>
public class FavoritoService(IXepaDb db)
{
    public async Task<IReadOnlyList<LojaFavoritaDto>> ListarAsync(int usuarioId, CancellationToken ct)
    {
        var agora = DateTimeOffset.UtcNow;
        return await db.Favoritos.AsNoTracking()
            .Where(f => f.UsuarioId == usuarioId)
            .OrderByDescending(f => f.CriadoEm)
            .Select(f => f.Estabelecimento)
            .Select(e => new
            {
                e.Id, e.Nome, e.Categoria, e.LogoUrl, e.Endereco.Bairro,
                Disponiveis = e.Ofertas.Where(o => o.Ativa && e.Ativo && !e.Pausada && e.StatusCadastro == StatusCadastro.Aprovado
                                                   && o.QuantidadeDisponivel > 0 && o.RetiradaFim > agora)
            })
            .Select(e => new LojaFavoritaDto(e.Id, e.Nome, e.Categoria, e.LogoUrl, e.Bairro,
                e.Disponiveis.Count(), e.Disponiveis.Min(o => (decimal?)o.Preco)))
            .ToListAsync(ct);
    }

    public async Task<IReadOnlyList<int>> IdsAsync(int usuarioId, CancellationToken ct) =>
        await db.Favoritos.Where(f => f.UsuarioId == usuarioId).Select(f => f.EstabelecimentoId).ToListAsync(ct);

    public async Task AdicionarAsync(int usuarioId, int estabelecimentoId, CancellationToken ct)
    {
        if (await db.Favoritos.AnyAsync(f => f.UsuarioId == usuarioId && f.EstabelecimentoId == estabelecimentoId, ct))
            return;
        if (!await db.Estabelecimentos.AnyAsync(e => e.Id == estabelecimentoId && e.Ativo && e.StatusCadastro == StatusCadastro.Aprovado, ct))
            throw new NaoEncontradoException("Loja não encontrada.");

        db.Favoritos.Add(new Favorito { UsuarioId = usuarioId, EstabelecimentoId = estabelecimentoId });
        await db.SaveChangesAsync(ct);
    }

    public async Task RemoverAsync(int usuarioId, int estabelecimentoId, CancellationToken ct)
    {
        var favorito = await db.Favoritos.FirstOrDefaultAsync(f => f.UsuarioId == usuarioId && f.EstabelecimentoId == estabelecimentoId, ct);
        if (favorito is null)
            return;
        db.Favoritos.Remove(favorito);
        await db.SaveChangesAsync(ct);
    }
}
