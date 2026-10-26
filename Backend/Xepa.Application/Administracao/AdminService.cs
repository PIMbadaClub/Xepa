using Microsoft.EntityFrameworkCore;
using Xepa.Domain;
using Xepa.Domain.Entities;

namespace Xepa.Application.Administracao;

public record PainelAdminDto(int LojasPendentes, int DenunciasAbertas, int PedidosHoje, decimal VendasHoje,
    decimal KgSalvos30Dias, decimal RepassesAPagar);

public record LojaAdminDto(int Id, string Nome, CategoriaEstabelecimento Categoria, string? Cnpj, string? Telefone,
    string Responsavel, string Email, string Bairro, string Cidade, bool TemCoordenadas, StatusCadastro Status,
    bool Ativa, DateTimeOffset CriadoEm, int Pedidos, int DenunciasProcedentes);

public record DenunciaAdminDto(int Id, int PedidoId, string Cliente, int ClienteId, bool ClienteBloqueado,
    string Loja, int LojaId, bool LojaAtiva, MotivoDenuncia Motivo, string Descricao, StatusDenuncia Status,
    string? Resposta, DateTimeOffset CriadoEm, DateTimeOffset? TratadaEm);

public record UsuarioAdminDto(int Id, string Nome, string Email, TipoUsuario Tipo, bool Bloqueado, DateTimeOffset CriadoEm,
    int Pedidos);

/// <summary>Prévia do repasse de uma loja: pedidos entregues ainda não repassados.</summary>
public record RepassePendenteDto(int EstabelecimentoId, string Loja, int Pedidos, decimal ValorVendas, decimal Comissao,
    decimal TaxasEntrega, decimal ValorLiquido);

public record RepasseDto(int Id, int EstabelecimentoId, string Loja, int Pedidos, decimal ValorVendas, decimal Comissao,
    decimal TaxasEntrega, decimal ValorLiquido, DateTimeOffset CriadoEm, DateTimeOffset? PagoEm);

/// <summary>Área administrativa da XEPA: aprovação de lojas, denúncias, usuários e repasses (RF12).</summary>
public class AdminService(IXepaDb db, IServicoMapas mapas)
{
    public async Task<PainelAdminDto> PainelAsync(CancellationToken ct)
    {
        var agora = DateTimeOffset.UtcNow;
        var inicioHoje = agora.AddHours(-24);
        var inicio30 = agora.AddDays(-30);
        var pagos = new[] { StatusPedido.Pendente, StatusPedido.Confirmado, StatusPedido.EmPreparo,
            StatusPedido.ProntoParaRetirada, StatusPedido.SaiuParaEntrega, StatusPedido.Entregue };

        var pendentes = await db.Estabelecimentos.CountAsync(e => e.StatusCadastro == StatusCadastro.Pendente, ct);
        var denuncias = await db.Denuncias.CountAsync(d => d.Status == StatusDenuncia.Aberta, ct);
        var hoje = db.Pedidos.Where(p => p.CriadoEm >= inicioHoje && pagos.Contains(p.Status));
        var pedidosHoje = await hoje.CountAsync(ct);
        var vendasHoje = await hoje.SumAsync(p => (decimal?)p.ValorTotal, ct) ?? 0;
        var kg = await db.Pedidos
            .Where(p => p.Status == StatusPedido.Entregue && p.CriadoEm >= inicio30)
            .SumAsync(p => (decimal?)(p.Oferta.PesoEstimadoKg * p.Quantidade), ct) ?? 0;
        var aPagar = await db.Repasses.Where(r => r.PagoEm == null).SumAsync(r => (decimal?)r.ValorLiquido, ct) ?? 0;

        return new PainelAdminDto(pendentes, denuncias, pedidosHoje, vendasHoje, kg, aPagar);
    }

    // ---------- Lojas ----------

    public async Task<IReadOnlyList<LojaAdminDto>> ListarLojasAsync(StatusCadastro? status, CancellationToken ct)
    {
        var lojas = db.Estabelecimentos.AsNoTracking();
        if (status is { } s)
            lojas = lojas.Where(e => e.StatusCadastro == s);

        return await lojas
            .OrderBy(e => e.StatusCadastro == StatusCadastro.Pendente ? 0 : 1).ThenByDescending(e => e.CriadoEm)
            .Select(e => new LojaAdminDto(e.Id, e.Nome, e.Categoria, e.Cnpj, e.Telefone, e.Usuario.Nome, e.Usuario.Email,
                e.Endereco.Bairro, e.Endereco.Cidade, e.Endereco.Latitude != null && e.Endereco.Longitude != null,
                e.StatusCadastro, e.Ativo, e.CriadoEm,
                db.Pedidos.Count(p => p.Oferta.EstabelecimentoId == e.Id && p.Status == StatusPedido.Entregue),
                db.Denuncias.Count(d => d.EstabelecimentoId == e.Id && d.Status == StatusDenuncia.Procedente)))
            .ToListAsync(ct);
    }

    /// <summary>Aprova ou rejeita uma loja pendente (RN10).</summary>
    public async Task AvaliarLojaAsync(int estabelecimentoId, bool aprovar, CancellationToken ct)
    {
        var loja = await ObterLojaAsync(estabelecimentoId, ct);
        if (loja.StatusCadastro != StatusCadastro.Pendente)
            throw new RegraDeNegocioException("Esta loja já foi avaliada.");
        if (aprovar && loja.Endereco.Latitude is null)
        {
            // O cadastro pode ter sido feito com o serviço de mapas fora do ar; tenta de novo antes de recusar.
            var ponto = await mapas.GeocodificarAsync(loja.Endereco, ct)
                        ?? throw new RegraDeNegocioException("Não foi possível localizar o endereço da loja no mapa. Confira o CEP e o endereço com a loja antes de aprovar.");
            loja.Endereco = loja.Endereco with { Latitude = ponto.Latitude, Longitude = ponto.Longitude };
        }

        loja.StatusCadastro = aprovar ? StatusCadastro.Aprovado : StatusCadastro.Rejeitado;
        await db.SaveChangesAsync(ct);
    }

    /// <summary>Suspende a loja (tira ela e as ofertas do ar) ou reativa.</summary>
    public async Task AlterarAtivaAsync(int estabelecimentoId, bool ativa, CancellationToken ct)
    {
        var loja = await db.Estabelecimentos.Include(e => e.Ofertas.Where(o => o.Ativa))
                       .FirstOrDefaultAsync(e => e.Id == estabelecimentoId, ct)
                   ?? throw new NaoEncontradoException("Loja não encontrada.");
        if (ativa)
            loja.Ativo = true;
        else
            loja.Desativar();
        await db.SaveChangesAsync(ct);
    }

    private async Task<Estabelecimento> ObterLojaAsync(int id, CancellationToken ct) =>
        await db.Estabelecimentos.FirstOrDefaultAsync(e => e.Id == id, ct)
        ?? throw new NaoEncontradoException("Loja não encontrada.");

    // ---------- Denúncias ----------

    public async Task<IReadOnlyList<DenunciaAdminDto>> ListarDenunciasAsync(bool somenteAbertas, CancellationToken ct)
    {
        var denuncias = db.Denuncias.AsNoTracking();
        if (somenteAbertas)
            denuncias = denuncias.Where(d => d.Status == StatusDenuncia.Aberta);

        return await denuncias
            .OrderBy(d => d.Status == StatusDenuncia.Aberta ? 0 : 1).ThenBy(d => d.CriadoEm)
            .Take(200)
            .Select(d => new DenunciaAdminDto(d.Id, d.PedidoId, d.Autor.Nome, d.AutorId, d.Autor.Bloqueado,
                d.Estabelecimento.Nome, d.EstabelecimentoId, d.Estabelecimento.Ativo, d.Motivo, d.Descricao, d.Status,
                d.Resposta, d.CriadoEm, d.TratadaEm))
            .ToListAsync(ct);
    }

    /// <summary>Registra a decisão; se procedente, pode suspender a loja na mesma ação.</summary>
    public async Task TratarDenunciaAsync(int denunciaId, StatusDenuncia decisao, string resposta, bool suspenderLoja,
        int administradorId, CancellationToken ct)
    {
        var denuncia = await db.Denuncias.Include(d => d.Estabelecimento).ThenInclude(e => e.Ofertas.Where(o => o.Ativa))
                           .FirstOrDefaultAsync(d => d.Id == denunciaId, ct)
                       ?? throw new NaoEncontradoException("Denúncia não encontrada.");

        denuncia.Tratar(decisao, resposta, administradorId, DateTimeOffset.UtcNow);
        if (suspenderLoja && decisao == StatusDenuncia.Procedente)
            denuncia.Estabelecimento.Desativar();
        await db.SaveChangesAsync(ct);
    }

    // ---------- Usuários ----------

    public async Task<IReadOnlyList<UsuarioAdminDto>> ListarUsuariosAsync(string? busca, CancellationToken ct)
    {
        var usuarios = db.Usuarios.AsNoTracking();
        if (!string.IsNullOrWhiteSpace(busca))
        {
            var termo = busca.Trim();
            usuarios = usuarios.Where(u => u.Nome.Contains(termo) || u.Email.Contains(termo));
        }

        return await usuarios.OrderByDescending(u => u.CriadoEm).Take(100)
            .Select(u => new UsuarioAdminDto(u.Id, u.Nome, u.Email, u.Tipo, u.Bloqueado, u.CriadoEm, u.Pedidos.Count))
            .ToListAsync(ct);
    }

    /// <summary>Suspende ou libera o acesso; as sessões abertas do app caem na próxima renovação.</summary>
    public async Task AlterarBloqueioAsync(int usuarioId, bool bloqueado, int administradorId, CancellationToken ct)
    {
        if (usuarioId == administradorId)
            throw new RegraDeNegocioException("Você não pode suspender a própria conta.");
        var usuario = await db.Usuarios.FirstOrDefaultAsync(u => u.Id == usuarioId, ct)
                      ?? throw new NaoEncontradoException("Usuário não encontrado.");
        if (usuario.Tipo == TipoUsuario.Administrador)
            throw new RegraDeNegocioException("Administradores não são suspensos por aqui.");

        usuario.Bloqueado = bloqueado;
        if (bloqueado)
        {
            var agora = DateTimeOffset.UtcNow;
            await foreach (var token in db.TokensRenovacao.Where(t => t.UsuarioId == usuarioId && t.RevogadoEm == null).AsAsyncEnumerable().WithCancellation(ct))
                token.RevogadoEm = agora;
        }
        await db.SaveChangesAsync(ct);
    }

    // ---------- Repasses ----------

    public async Task<IReadOnlyList<RepassePendenteDto>> ListarPendentesDeRepasseAsync(CancellationToken ct)
    {
        var grupos = await db.Pedidos.AsNoTracking()
            .Where(p => p.Status == StatusPedido.Entregue && p.RepasseId == null)
            .GroupBy(p => new { p.Oferta.EstabelecimentoId, p.Oferta.Estabelecimento.Nome })
            .Select(g => new
            {
                g.Key.EstabelecimentoId,
                g.Key.Nome,
                Pedidos = g.Count(),
                Vendas = g.Sum(p => p.PrecoUnitario * p.Quantidade),
                Taxas = g.Sum(p => p.TaxaEntrega)
            })
            .ToListAsync(ct);

        return grupos.OrderBy(g => g.Nome).Select(g =>
        {
            var comissao = Math.Round(g.Vendas * Repasse.PercentualComissao, 2, MidpointRounding.AwayFromZero);
            return new RepassePendenteDto(g.EstabelecimentoId, g.Nome, g.Pedidos, g.Vendas, comissao, g.Taxas,
                g.Vendas - comissao + g.Taxas);
        }).ToList();
    }

    public async Task<IReadOnlyList<RepasseDto>> ListarRepassesAsync(int? estabelecimentoId, CancellationToken ct)
    {
        var repasses = db.Repasses.AsNoTracking();
        if (estabelecimentoId is { } id)
            repasses = repasses.Where(r => r.EstabelecimentoId == id);
        return await repasses.OrderBy(r => r.PagoEm != null).ThenByDescending(r => r.CriadoEm).Take(100)
            .Select(r => new RepasseDto(r.Id, r.EstabelecimentoId, r.Estabelecimento.Nome, r.QuantidadePedidos, r.ValorVendas,
                r.Comissao, r.TaxasEntrega, r.ValorLiquido, r.CriadoEm, r.PagoEm))
            .ToListAsync(ct);
    }

    /// <summary>Fecha o repasse de uma loja com todos os pedidos entregues que ainda não foram repassados.</summary>
    public async Task<int> FecharRepasseAsync(int estabelecimentoId, CancellationToken ct)
    {
        var pedidos = await db.Pedidos
            .Where(p => p.Oferta.EstabelecimentoId == estabelecimentoId && p.Status == StatusPedido.Entregue && p.RepasseId == null)
            .ToListAsync(ct);

        var repasse = Repasse.Fechar(estabelecimentoId, pedidos);
        db.Repasses.Add(repasse);
        await db.SaveChangesAsync(ct);
        return repasse.Id;
    }

    public async Task MarcarRepassePagoAsync(int repasseId, CancellationToken ct)
    {
        var repasse = await db.Repasses.FirstOrDefaultAsync(r => r.Id == repasseId, ct)
                      ?? throw new NaoEncontradoException("Repasse não encontrado.");
        repasse.MarcarPago(DateTimeOffset.UtcNow);
        await db.SaveChangesAsync(ct);
    }
}
