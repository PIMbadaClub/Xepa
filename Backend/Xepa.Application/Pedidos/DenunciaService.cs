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

public record DenunciaDto(int Id, int PedidoId, MotivoDenuncia Motivo, string Descricao, StatusDenuncia Status,
    string? Resposta, DateTimeOffset CriadoEm, DateTimeOffset? TratadaEm);

/// <summary>Canal de denúncia em cada pedido (seção de ética do PIM); a equipe trata no portal administrativo.</summary>
public class DenunciaService(IXepaDb db)
{
    public async Task<DenunciaDto> CriarAsync(int clienteId, int pedidoId, CriarDenunciaRequest request, CancellationToken ct)
    {
        var pedido = await db.Pedidos.Include(p => p.Oferta)
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
        db.Denuncias.Add(denuncia);
        await db.SaveChangesAsync(ct);
        return Dto(denuncia);
    }

    public async Task<IReadOnlyList<DenunciaDto>> ListarDoPedidoAsync(int clienteId, int pedidoId, CancellationToken ct) =>
        (await db.Denuncias.AsNoTracking()
            .Where(d => d.PedidoId == pedidoId && d.AutorId == clienteId)
            .OrderByDescending(d => d.CriadoEm)
            .ToListAsync(ct))
        .Select(Dto).ToList();

    private static DenunciaDto Dto(Denuncia d) =>
        new(d.Id, d.PedidoId, d.Motivo, d.Descricao, d.Status, d.Resposta, d.CriadoEm, d.TratadaEm);
}
