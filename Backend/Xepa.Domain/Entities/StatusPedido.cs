namespace Xepa.Domain.Entities;

public enum StatusPedido
{
    /// <summary>Pedido criado e estoque reservado; sem pagamento em 15 minutos, é cancelado (RN03).</summary>
    AguardandoPagamento,

    /// <summary>Pago e aguardando a loja confirmar; só até aqui o cliente pode cancelar (RN05).</summary>
    Pendente,
    Confirmado,
    EmPreparo,
    ProntoParaRetirada,
    SaiuParaEntrega,
    Entregue,
    Cancelado
}
