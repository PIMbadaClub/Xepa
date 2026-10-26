using System.ComponentModel.DataAnnotations;
using Microsoft.EntityFrameworkCore;
using Xepa.Domain;
using Xepa.Domain.Entities;

namespace Xepa.Application.Pedidos;

public class CriarDenunciaRequest
{
    [Required]
    public MotivoDenuncia Motivo { get; init; }

    [Required(ErrorMessage = "Conte o que aconteceu."), StringLength(1000, MinimumLength = 10, ErrorMessage = "Conte o que aconteceu (de 10 a 1000 caracteres).")]
    public required string Descricao { get; init; }
}

public record DenunciaDto(int Id, int PedidoId, string Loja, MotivoDenuncia Motivo, string Descricao, string? FotoUrl,
    StatusDenuncia Status, string? Resposta, DateTimeOffset CriadoEm, DateTimeOffset? TratadaEm);

/// <summary>Canal de denúncia em cada pedido (seção de ética do PIM); a equipe trata no portal administrativo.</summary>
public class DenunciaService(IXepaDb db, IArmazenamento armazenamento)
{
    public async Task<DenunciaDto> CriarAsync(int clienteId, int pedidoId, CriarDenunciaRequest request, Foto? foto,
        CancellationToken ct)
    {
        var pedido = await db.Pedidos.Include(p => p.Oferta).ThenInclude(o => o.Estabelecimento)
                         .FirstOrDefaultAsync(p => p.Id == pedidoId && p.ClienteId == clienteId, ct)
                     ?? throw new NaoEncontradoException("Pedido não encontrado.");
        if (pedido.Status == StatusPedido.AguardandoPagamento)
            throw new RegraDeNegocioException("Só dá para denunciar pedidos pagos.");
        if (await db.Denuncias.AnyAsync(d => d.PedidoId == pedidoId && d.Status == StatusDenuncia.Aberta, ct))
            throw new RegraDeNegocioException("Já existe uma denúncia em análise para este pedido.");

        var denuncia = new Denuncia
        {
            PedidoId = pedidoId,
            AutorId = clienteId,
            EstabelecimentoId = pedido.Oferta.EstabelecimentoId,
            Motivo = request.Motivo,
            Descricao = request.Descricao.Trim()
        };
        if (foto is not null)
            denuncia.FotoUrl = await Fotos.SalvarAsync(armazenamento, foto, ct);
        db.Denuncias.Add(denuncia);
        await db.SaveChangesAsync(ct);
        return new DenunciaDto(denuncia.Id, denuncia.PedidoId, pedido.Oferta.Estabelecimento.Nome, denuncia.Motivo,
            denuncia.Descricao, denuncia.FotoUrl, denuncia.Status, denuncia.Resposta, denuncia.CriadoEm, denuncia.TratadaEm);
    }

    public Task<List<DenunciaDto>> ListarDoPedidoAsync(int clienteId, int pedidoId, CancellationToken ct) =>
        Consultar(clienteId, pedidoId).ToListAsync(ct);

    /// <summary>Todas as denúncias do cliente (tela "Minhas denúncias" do perfil).</summary>
    public Task<List<DenunciaDto>> ListarDoClienteAsync(int clienteId, CancellationToken ct) =>
        Consultar(clienteId, null).Take(100).ToListAsync(ct);

    private IQueryable<DenunciaDto> Consultar(int clienteId, int? pedidoId) =>
        db.Denuncias.AsNoTracking()
            .Where(d => d.AutorId == clienteId && (pedidoId == null || d.PedidoId == pedidoId))
            .OrderByDescending(d => d.CriadoEm)
            .Select(d => new DenunciaDto(d.Id, d.PedidoId, d.Estabelecimento.Nome, d.Motivo, d.Descricao, d.FotoUrl,
                d.Status, d.Resposta, d.CriadoEm, d.TratadaEm));
}
