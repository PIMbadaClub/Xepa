using System.ComponentModel.DataAnnotations;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Xepa.Domain.Entities;

namespace Xepa.Application.Notificacoes;

public class RegistrarDispositivoRequest
{
    [Required, MaxLength(512)]
    public required string Token { get; init; }

    [Required, RegularExpression("^(android|ios|web)$", ErrorMessage = "Plataforma inválida.")]
    public required string Plataforma { get; init; }
}

/// <summary>
/// Notificações push com o app fechado: mudança de status do pedido e resposta do suporte. O app registra o token do
/// Firebase ao entrar e apaga ao sair; tokens que o Firebase recusar são removidos.
/// </summary>
public class PushService(IXepaDb db, IEnvioPush envio, ILogger<PushService> log)
{
    public async Task RegistrarAsync(int usuarioId, RegistrarDispositivoRequest request, CancellationToken ct)
    {
        var dispositivo = await db.DispositivosPush.FirstOrDefaultAsync(d => d.Token == request.Token, ct);
        if (dispositivo is null)
            db.DispositivosPush.Add(new DispositivoPush { UsuarioId = usuarioId, Token = request.Token, Plataforma = request.Plataforma });
        else
        {
            // Mesmo aparelho, outra conta (ou só renovou): o token passa para quem entrou agora.
            dispositivo.UsuarioId = usuarioId;
            dispositivo.Plataforma = request.Plataforma;
            dispositivo.AtualizadoEm = DateTimeOffset.UtcNow;
        }
        await db.SaveChangesAsync(ct);
    }

    public async Task RemoverAsync(int usuarioId, string token, CancellationToken ct)
    {
        var dispositivo = await db.DispositivosPush.FirstOrDefaultAsync(d => d.Token == token && d.UsuarioId == usuarioId, ct);
        if (dispositivo is null)
            return;
        db.DispositivosPush.Remove(dispositivo);
        await db.SaveChangesAsync(ct);
    }

    /// <summary>Manda para todos os celulares do usuário. Falha de envio não derruba a operação que gerou o aviso.</summary>
    public async Task AvisarAsync(int usuarioId, string titulo, string texto, IReadOnlyDictionary<string, string> dados, CancellationToken ct)
    {
        try
        {
            var tokens = await db.DispositivosPush.Where(d => d.UsuarioId == usuarioId).Select(d => d.Token).ToListAsync(ct);
            if (tokens.Count == 0)
                return;

            var invalidos = await envio.EnviarAsync(tokens, titulo, texto, dados, ct);
            if (invalidos.Count > 0)
            {
                db.DispositivosPush.RemoveRange(await db.DispositivosPush.Where(d => invalidos.Contains(d.Token)).ToListAsync(ct));
                await db.SaveChangesAsync(ct);
            }
        }
        catch (Exception e) when (e is not OperationCanceledException)
        {
            log.LogWarning(e, "Falha ao enviar push para o usuário {Usuario}", usuarioId);
        }
    }

    /// <summary>Aviso de mudança de status para o cliente, com o mesmo texto da central de notificações.</summary>
    public async Task AvisarPedidoAsync(int pedidoId, CancellationToken ct)
    {
        var p = await db.Pedidos.AsNoTracking().Where(x => x.Id == pedidoId)
            .Select(x => new { x.ClienteId, x.Status, x.TipoEntrega, Loja = x.Oferta.Estabelecimento.Nome, x.CodigoRetirada })
            .FirstOrDefaultAsync(ct);
        if (p is null || p.Status == StatusPedido.AguardandoPagamento)
            return;

        var (titulo, texto) = NotificacaoService.TextoStatus(p.Status, p.TipoEntrega, p.Loja, p.CodigoRetirada);
        await AvisarAsync(p.ClienteId, titulo, texto,
            new Dictionary<string, string> { ["tipo"] = "pedido", ["pedidoId"] = pedidoId.ToString(), ["status"] = p.Status.ToString() }, ct);
    }
}
