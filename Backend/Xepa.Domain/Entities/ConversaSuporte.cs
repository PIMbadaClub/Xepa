namespace Xepa.Domain.Entities;

public enum StatusConversa
{
    Aberta,
    Resolvida
}

/// <summary>
/// Chat do usuário (cliente, entregador ou loja) com a equipe da XEPA. Cada conta tem uma conversa só, como o chat de
/// atendimento dos marketplaces: o histórico fica todo junto e reabre quando o usuário escreve de novo.
/// </summary>
public class ConversaSuporte : Entidade
{
    public int UsuarioId { get; set; }
    public Usuario Usuario { get; set; } = null!;

    public StatusConversa Status { get; set; } = StatusConversa.Aberta;
    public DateTimeOffset UltimaMensagemEm { get; set; }

    /// <summary>Respostas da equipe que o usuário ainda não viu (bolinha no app).</summary>
    public int NaoLidasUsuario { get; set; }

    /// <summary>Mensagens do usuário que a equipe ainda não leu (fila do atendimento).</summary>
    public int NaoLidasSuporte { get; set; }

    public List<MensagemSuporte> Mensagens { get; set; } = [];
}

public class MensagemSuporte : Entidade
{
    public int ConversaId { get; set; }
    public ConversaSuporte Conversa { get; set; } = null!;

    /// <summary>Quem escreveu: o próprio usuário ou o atendente. Nulo nas respostas automáticas.</summary>
    public int? AutorId { get; set; }
    public Usuario? Autor { get; set; }

    public bool DoSuporte { get; set; }
    public bool Automatica { get; set; }
    public required string Texto { get; set; }

    /// <summary>Pedido anexado à mensagem (aparece como cartão no chat).</summary>
    public int? PedidoId { get; set; }
    public Pedido? Pedido { get; set; }
}
