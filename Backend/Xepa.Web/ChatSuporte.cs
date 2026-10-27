using Xepa.Application.Suporte;

namespace Xepa.Web;

/// <summary>Mensagens do chat de suporte já formatadas para a tela (o JavaScript só desenha).</summary>
public static class ChatSuporte
{
    public static object Item(MensagemSuporteDto m) => new
    {
        m.Id,
        m.DoSuporte,
        m.Automatica,
        m.Autor,
        m.Texto,
        Hora = Rotulos.Data(m.Em),
        Pedido = m.Pedido is not { } p
            ? null
            : new
            {
                p.Id,
                p.Loja,
                p.Oferta,
                Valor = Rotulos.Dinheiro(p.ValorTotal),
                Status = Rotulos.Pedido(p.Status, p.TipoEntrega),
                Classe = Rotulos.ClassePedido(p.Status)
            }
    };

    public static IEnumerable<object> Itens(IEnumerable<MensagemSuporteDto> mensagens) => mensagens.Select(Item);
}

/// <summary>Chat de suporte compartilhado pela tela da equipe (admin) e pela da loja.</summary>
public record ChatVm(IReadOnlyList<MensagemSuporteDto> Mensagens, string UrlNovas, string UrlEnviar, bool LadoEquipe,
    IReadOnlyList<PedidoAnexoDto>? Anexaveis = null, IReadOnlyList<string>? RespostasProntas = null);
