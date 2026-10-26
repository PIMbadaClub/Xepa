using System.ComponentModel.DataAnnotations;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Xepa.Domain;
using Xepa.Domain.Entities;

namespace Xepa.Application.Pagamentos;

public class IniciarPagamentoRequest
{
    [Required]
    public MetodoPagamento Metodo { get; init; } = MetodoPagamento.Pix;
}

public record PagamentoDto(int Id, int PedidoId, MetodoPagamento Metodo, StatusPagamento Status, decimal Valor,
    string? QrCodePix, string? UrlCheckout, DateTimeOffset? ExpiraEm, string Provedor, string IdExterno);

public class PagamentoService(IXepaDb db, IGatewayPagamento gateway, IConfirmacaoPagamento confirmacao,
    INotificadorPedidos notificador, ILogger<PagamentoService> log)
{
    /// <summary>
    /// Cria a cobrança do pedido no gateway. Se já existe uma cobrança vigente do mesmo método,
    /// devolve a mesma (o app pode chamar de novo ao reabrir a tela).
    /// </summary>
    public async Task<PagamentoDto> IniciarAsync(int clienteId, int pedidoId, MetodoPagamento metodo, CancellationToken ct)
    {
        var pedido = await db.Pedidos
                         .Include(p => p.Cliente)
                         .Include(p => p.Oferta)
                         .Include(p => p.Pagamentos)
                         .FirstOrDefaultAsync(p => p.Id == pedidoId && p.ClienteId == clienteId, ct)
                     ?? throw new NaoEncontradoException("Pedido não encontrado.");
        if (pedido.Status != StatusPedido.AguardandoPagamento)
            throw new RegraDeNegocioException("O pedido não está aguardando pagamento.");

        var agora = DateTimeOffset.UtcNow;
        var vigente = pedido.Pagamentos.FirstOrDefault(p => p.Metodo == metodo && p.Provedor == gateway.Provedor && p.Vigente(agora));
        if (vigente is not null)
            return ParaDto(vigente);

        var cobranca = await gateway.CriarCobrancaAsync(pedido, metodo, pedido.Cliente.Email, ct);
        var pagamento = new Pagamento
        {
            PedidoId = pedido.Id,
            Provedor = gateway.Provedor,
            IdExterno = cobranca.IdExterno,
            Metodo = metodo,
            Valor = pedido.ValorTotal,
            QrCodePix = cobranca.QrCodePix,
            UrlCheckout = cobranca.UrlCheckout,
            ExpiraEm = cobranca.ExpiraEm
        };
        db.Pagamentos.Add(pagamento);
        await db.SaveChangesAsync(ct);
        return ParaDto(pagamento);
    }

    public async Task<IReadOnlyList<PagamentoDto>> ListarDoPedidoAsync(int clienteId, int pedidoId, CancellationToken ct)
    {
        var pagamentos = await db.Pagamentos.AsNoTracking()
            .Where(p => p.PedidoId == pedidoId && p.Pedido.ClienteId == clienteId)
            .OrderByDescending(p => p.CriadoEm)
            .ToListAsync(ct);
        return pagamentos.Select(ParaDto).ToList();
    }

    /// <summary>
    /// Trata a notificação do gateway: consulta o pagamento na fonte, atualiza o registro e libera o pedido.
    /// Pagamento aprovado de um pedido que já expirou é estornado na hora.
    /// </summary>
    public async Task ProcessarNotificacaoAsync(string idExterno, CancellationToken ct)
    {
        var situacao = await gateway.ConsultarAsync(idExterno, ct);
        if (situacao is null)
        {
            log.LogWarning("Notificação de pagamento {IdExterno} desconhecido no gateway.", idExterno);
            return;
        }

        var pagamento = await LocalizarAsync(situacao, ct);
        if (pagamento is null)
        {
            log.LogWarning("Pagamento {IdExterno} sem pedido correspondente.", idExterno);
            return;
        }

        switch (situacao.Status)
        {
            case StatusPagamento.Aprovado:
                await db.SaveChangesAsync(ct); // grava o IdExterno definitivo antes da procedure
                await confirmacao.ConfirmarAsync(pagamento.Provedor, pagamento.IdExterno,
                    situacao.AprovadoEm ?? DateTimeOffset.UtcNow, ct);

                var pedido = await db.Pedidos.Include(p => p.Pagamentos).FirstAsync(p => p.Id == pagamento.PedidoId, ct);
                await db.Entry(pedido).ReloadAsync(ct);
                await db.Entry(pagamento).ReloadAsync(ct);
                if (pedido.Status == StatusPedido.Cancelado)
                    await EstornarAprovadosAsync(pedido, ct); // pagou depois de o pedido expirar
                break;

            case StatusPagamento.Recusado:
                pagamento.Recusar();
                break;

            case StatusPagamento.Estornado when pagamento.Status == StatusPagamento.Aprovado:
                pagamento.MarcarEstornado();
                break;
        }

        await db.SaveChangesAsync(ct);
        await notificador.PedidoAlteradoAsync(pagamento.PedidoId, ct);
    }

    /// <summary>Estorna no gateway os pagamentos aprovados de um pedido cancelado (RN05).</summary>
    public async Task EstornarAprovadosAsync(Pedido pedido, CancellationToken ct)
    {
        var aprovados = await db.Pagamentos
            .Where(p => p.PedidoId == pedido.Id && p.Status == StatusPagamento.Aprovado)
            .ToListAsync(ct);
        foreach (var pagamento in aprovados)
        {
            await gateway.EstornarAsync(pagamento.IdExterno, ct);
            pagamento.MarcarEstornado();
        }
        await db.SaveChangesAsync(ct);
    }

    private async Task<Pagamento?> LocalizarAsync(SituacaoPagamento situacao, CancellationToken ct)
    {
        var pagamento = await db.Pagamentos
            .FirstOrDefaultAsync(p => p.Provedor == gateway.Provedor && p.IdExterno == situacao.IdExterno, ct);
        if (pagamento is not null || situacao.PedidoId is not { } pedidoId)
            return pagamento;

        // Cartão: a cobrança foi criada com o id da preferência; agora chega o id do pagamento.
        pagamento = await db.Pagamentos
            .Where(p => p.PedidoId == pedidoId && p.Provedor == gateway.Provedor && p.Metodo == situacao.Metodo
                        && p.Status == StatusPagamento.Pendente)
            .OrderByDescending(p => p.CriadoEm)
            .FirstOrDefaultAsync(ct);
        if (pagamento is not null)
        {
            pagamento.IdExterno = situacao.IdExterno;
            return pagamento;
        }

        if (!await db.Pedidos.AnyAsync(p => p.Id == pedidoId, ct))
            return null;

        pagamento = new Pagamento
        {
            PedidoId = pedidoId,
            Provedor = gateway.Provedor,
            IdExterno = situacao.IdExterno,
            Metodo = situacao.Metodo,
            Valor = situacao.Valor
        };
        db.Pagamentos.Add(pagamento);
        return pagamento;
    }

    private static PagamentoDto ParaDto(Pagamento p) =>
        new(p.Id, p.PedidoId, p.Metodo, p.Status, p.Valor, p.QrCodePix, p.UrlCheckout, p.ExpiraEm, p.Provedor, p.IdExterno);
}
