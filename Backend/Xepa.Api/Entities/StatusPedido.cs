namespace Xepa.Api.Entities;

public enum StatusPedido
{
    /// <summary>Aguardando o estabelecimento confirmar; só aqui o cliente pode cancelar (RF16).</summary>
    Pendente,
    Confirmado,
    EmPreparo,
    ProntoParaRetirada,
    SaiuParaEntrega,
    Entregue,
    Cancelado
}
