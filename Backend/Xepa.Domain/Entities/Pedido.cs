namespace Xepa.Domain.Entities;

public class Pedido : Entidade
{
    public int ClienteId { get; set; }
    public Usuario Cliente { get; set; } = null!;

    public int OfertaId { get; set; }
    public Oferta Oferta { get; set; } = null!;

    /// <summary>Entregador da loja que leva o pedido (só quando TipoEntrega = Entrega).</summary>
    public int? EntregadorId { get; set; }
    public Usuario? Entregador { get; set; }

    public int Quantidade { get; set; }

    /// <summary>Preço da oferta no momento do pedido; não muda se a loja alterar a oferta depois (RN04).</summary>
    public decimal PrecoUnitario { get; set; }
    public decimal TaxaEntrega { get; set; }

    /// <summary>Distância da rota loja → cliente, calculada na criação do pedido (mostrada ao entregador).</summary>
    public double? DistanciaEntregaKm { get; set; }
    public decimal ValorTotal { get; set; }

    public TipoEntrega TipoEntrega { get; set; }

    /// <summary>
    /// Cópia do endereço no momento do pedido (só quando TipoEntrega = Entrega),
    /// para o histórico não mudar se o cliente editar ou apagar o endereço.
    /// </summary>
    public Endereco? EnderecoEntrega { get; set; }

    public StatusPedido Status { get; set; } = StatusPedido.AguardandoPagamento;

    /// <summary>Código de 4 dígitos que o cliente mostra na retirada (RN08).</summary>
    public string CodigoRetirada { get; set; } = "0000";

    public string? Observacao { get; set; }

    /// <summary>Repasse em que o pedido entrou; vazio enquanto a XEPA não acertou com a loja.</summary>
    /// <summary>Nota de 1 a 5 que o cliente dá ao entregador depois de receber o pedido.</summary>
    public int? NotaEntregador { get; set; }
    public string? ComentarioEntregador { get; set; }
    public DateTimeOffset? EntregadorAvaliadoEm { get; set; }

    public int? RepasseId { get; set; }
    public Repasse? Repasse { get; set; }

    public List<Pagamento> Pagamentos { get; set; } = [];
    public List<RastreioEntrega> Rastreios { get; set; } = [];
    public List<PedidoHistoricoStatus> Historico { get; set; } = [];

    /// <summary>Próximos status permitidos a partir de cada status (ciclo de vida do pedido).</summary>
    private static readonly Dictionary<StatusPedido, StatusPedido[]> Transicoes = new()
    {
        [StatusPedido.AguardandoPagamento] = [StatusPedido.Pendente, StatusPedido.Cancelado],
        [StatusPedido.Pendente] = [StatusPedido.Confirmado, StatusPedido.Cancelado],
        [StatusPedido.Confirmado] = [StatusPedido.EmPreparo],
        // A loja sempre marca "pronto" (na entrega, pronto para o entregador coletar).
        [StatusPedido.EmPreparo] = [StatusPedido.ProntoParaRetirada],
        [StatusPedido.ProntoParaRetirada] = [StatusPedido.Entregue, StatusPedido.SaiuParaEntrega],
        [StatusPedido.SaiuParaEntrega] = [StatusPedido.Entregue],
        [StatusPedido.Entregue] = [],
        [StatusPedido.Cancelado] = [],
    };

    public bool PodeIrPara(StatusPedido novo) =>
        Transicoes[Status].Contains(novo)
        && !(novo == StatusPedido.SaiuParaEntrega && TipoEntrega == TipoEntrega.Retirada)
        // Na entrega, "Entregue" só vem depois de o entregador coletar.
        && !(novo == StatusPedido.Entregue && Status == StatusPedido.ProntoParaRetirada && TipoEntrega == TipoEntrega.Entrega);

    public void AvancarStatus(StatusPedido novo)
    {
        if (novo == StatusPedido.Cancelado)
        {
            Cancelar();
            return;
        }
        if (!PodeIrPara(novo))
            throw new RegraDeNegocioException($"O pedido não pode passar de {Status} para {novo}.");

        Status = novo;
    }

    /// <summary>Chamado quando o gateway aprova o pagamento; notificação repetida não muda nada.</summary>
    public void ConfirmarPagamento()
    {
        if (Status == StatusPedido.AguardandoPagamento)
            Status = StatusPedido.Pendente;
    }

    /// <summary>Cancela antes da confirmação da loja (RN05). O estoque volta pelo trigger do banco.</summary>
    public void Cancelar()
    {
        if (!PodeIrPara(StatusPedido.Cancelado))
            throw new RegraDeNegocioException("O pedido já foi confirmado pela loja e não pode mais ser cancelado.");

        Status = StatusPedido.Cancelado;
    }

    /// <summary>Confirma a retirada na loja conferindo o código do cliente (RN08).</summary>
    public void ConfirmarRetirada(string codigo)
    {
        if (TipoEntrega == TipoEntrega.Entrega)
            throw new RegraDeNegocioException("Pedido de entrega: quem confirma com o código é o entregador, na casa do cliente.");
        if (codigo != CodigoRetirada)
            throw new RegraDeNegocioException("Código de retirada incorreto.");

        AvancarStatus(StatusPedido.Entregue);
    }

    /// <summary>O cliente avalia o entregador uma vez, depois de receber a entrega.</summary>
    public void AvaliarEntregador(int nota, string? comentario)
    {
        if (TipoEntrega != TipoEntrega.Entrega || EntregadorId is null)
            throw new RegraDeNegocioException("Só dá para avaliar o entregador em pedidos com entrega.");
        if (Status != StatusPedido.Entregue)
            throw new RegraDeNegocioException("Avalie o entregador depois de receber o pedido.");
        if (NotaEntregador is not null)
            throw new RegraDeNegocioException("Você já avaliou esta entrega.");
        if (nota is < 1 or > 5)
            throw new RegraDeNegocioException("A nota vai de 1 a 5.");

        NotaEntregador = nota;
        ComentarioEntregador = string.IsNullOrWhiteSpace(comentario) ? null : comentario.Trim();
        EntregadorAvaliadoEm = DateTimeOffset.UtcNow;
    }
}
