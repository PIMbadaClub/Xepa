using Microsoft.EntityFrameworkCore;
using Xepa.Domain.Entities;

namespace Xepa.Application.Notificacoes;

public enum TipoNotificacao
{
    Pedido,
    Denuncia,
    OfertaFavorita
}

public record NotificacaoDto(string Id, TipoNotificacao Tipo, string Titulo, string Texto, DateTimeOffset Em, bool Lida,
    int? PedidoId, int? OfertaId, string? Status);

public record CaixaNotificacoesDto(int NaoLidas, IReadOnlyList<NotificacaoDto> Itens);

/// <summary>
/// Central de notificações do cliente. Não tem tabela própria: é montada a partir do histórico de status dos pedidos
/// (gravado pelo trigger, venha a mudança do app, do portal ou do webhook), das respostas de denúncia e das
/// ofertas novas das lojas favoritas. A marca de leitura é uma data no usuário.
/// </summary>
public class NotificacaoService(IXepaDb db)
{
    private static readonly TimeSpan Janela = TimeSpan.FromDays(14);

    public async Task<CaixaNotificacoesDto> ListarAsync(int usuarioId, int limite, CancellationToken ct)
    {
        limite = Math.Clamp(limite, 1, 100);
        var desde = DateTimeOffset.UtcNow - Janela;
        var lidasAte = await db.Usuarios.Where(u => u.Id == usuarioId).Select(u => u.NotificacoesLidasAte).FirstOrDefaultAsync(ct);

        var historico = await db.Pedidos.AsNoTracking()
            .Where(p => p.ClienteId == usuarioId)
            .SelectMany(p => p.Historico.Select(h => new
            {
                h.Id, h.StatusAnterior, h.StatusNovo, h.AlteradoEm, PedidoId = p.Id, p.TipoEntrega, Loja = p.Oferta.Estabelecimento.Nome,
                p.CodigoRetirada
            }))
            .Where(h => h.AlteradoEm >= desde && h.StatusNovo != StatusPedido.AguardandoPagamento)
            .OrderByDescending(h => h.AlteradoEm).Take(limite)
            .ToListAsync(ct);

        var denuncias = await db.Denuncias.AsNoTracking()
            .Where(d => d.AutorId == usuarioId && d.TratadaEm != null && d.TratadaEm >= desde)
            .OrderByDescending(d => d.TratadaEm).Take(limite)
            .Select(d => new { d.Id, d.PedidoId, d.Status, d.TratadaEm, Loja = d.Estabelecimento.Nome })
            .ToListAsync(ct);

        var agora = DateTimeOffset.UtcNow;
        var ofertas = await db.Favoritos.AsNoTracking()
            .Where(f => f.UsuarioId == usuarioId)
            .SelectMany(f => f.Estabelecimento.Ofertas
                .Where(o => o.CriadoEm >= desde && o.CriadoEm >= f.CriadoEm && o.Ativa && o.RetiradaFim > agora)
                .Select(o => new { o.Id, o.Titulo, o.Preco, o.CriadoEm, Loja = f.Estabelecimento.Nome }))
            .OrderByDescending(o => o.CriadoEm).Take(limite)
            .ToListAsync(ct);

        bool Lida(DateTimeOffset em) => lidasAte is { } l && em <= l;

        var itens = historico.Select(h =>
            {
                var (titulo, texto) = h is { StatusNovo: StatusPedido.Cancelado, StatusAnterior: StatusPedido.AguardandoPagamento }
                    ? ("Pedido expirou", $"O pagamento do pedido na {h.Loja} não foi confirmado a tempo e a sacola voltou para a vitrine.")
                    : TextoStatus(h.StatusNovo, h.TipoEntrega, h.Loja, h.CodigoRetirada);
                return new NotificacaoDto($"p{h.Id}", TipoNotificacao.Pedido, titulo, texto, h.AlteradoEm, Lida(h.AlteradoEm),
                    h.PedidoId, null, h.StatusNovo.ToString());
            })
            .Concat(denuncias.Select(d => new NotificacaoDto($"d{d.Id}", TipoNotificacao.Denuncia,
                "A XEPA respondeu sua denúncia",
                $"Pedido #{d.PedidoId} na {d.Loja}: denúncia {(d.Status == StatusDenuncia.Procedente ? "procedente" : "analisada")}. Toque para ver a resposta.",
                d.TratadaEm!.Value, Lida(d.TratadaEm!.Value), d.PedidoId, null, null)))
            .Concat(ofertas.Select(o => new NotificacaoDto($"o{o.Id}", TipoNotificacao.OfertaFavorita,
                $"{o.Loja} publicou uma oferta",
                $"{o.Titulo} por {o.Preco.ToString("C", Brasil)}. Corre antes que acabe!",
                o.CriadoEm, Lida(o.CriadoEm), null, o.Id, null)))
            .OrderByDescending(n => n.Em)
            .Take(limite)
            .ToList();

        return new CaixaNotificacoesDto(itens.Count(n => !n.Lida), itens);
    }

    /// <summary>Marca como lidas todas as notificações até agora.</summary>
    public async Task MarcarLidasAsync(int usuarioId, CancellationToken ct)
    {
        var usuario = await db.Usuarios.FirstOrDefaultAsync(u => u.Id == usuarioId, ct)
                      ?? throw new NaoEncontradoException("Usuário não encontrado.");
        usuario.NotificacoesLidasAte = DateTimeOffset.UtcNow;
        await db.SaveChangesAsync(ct);
    }

    private static readonly System.Globalization.CultureInfo Brasil = System.Globalization.CultureInfo.GetCultureInfo("pt-BR");

    /// <summary>Título e texto de cada mudança de status, do ponto de vista do cliente.</summary>
    public static (string Titulo, string Texto) TextoStatus(StatusPedido status, TipoEntrega tipo, string loja, string codigo) =>
        status switch
        {
            StatusPedido.Pendente => ("Pagamento confirmado", $"Seu pedido foi enviado para a {loja}. Agora é só aguardar o aceite."),
            StatusPedido.Confirmado => ("Pedido aceito!", $"A {loja} aceitou seu pedido."),
            StatusPedido.EmPreparo => ("Separando sua sacola", $"A {loja} está preparando seu pedido."),
            StatusPedido.ProntoParaRetirada when tipo == TipoEntrega.Entrega =>
                ("Pedido pronto", $"A {loja} terminou de preparar. O entregador vai buscar."),
            StatusPedido.ProntoParaRetirada => ("Pronto para retirada", $"Passe na {loja} e mostre o código {codigo}."),
            StatusPedido.SaiuParaEntrega => ("Saiu para entrega", "Seu pedido está a caminho. Acompanhe pelo mapa."),
            StatusPedido.Entregue => (tipo == TipoEntrega.Entrega ? "Pedido entregue" : "Retirada confirmada",
                "Bom apetite! Obrigado por salvar essa comida do lixo."),
            StatusPedido.Cancelado => ("Pedido cancelado", "Se houve pagamento, o estorno já foi solicitado."),
            _ => ("Pedido atualizado", $"Seu pedido na {loja} mudou de status.")
        };
}
