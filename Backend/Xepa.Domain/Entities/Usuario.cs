namespace Xepa.Domain.Entities;

public class Usuario : Entidade
{
    public required string Nome { get; set; }
    public required string Email { get; set; }
    public required string SenhaHash { get; set; }
    public string? Telefone { get; set; }
    public TipoUsuario Tipo { get; set; }

    /// <summary>Conta suspensa pela equipe da XEPA (ex.: denúncia procedente); não consegue entrar.</summary>
    public bool Bloqueado { get; set; }

    /// <summary>Placa da moto do entregador parceiro (aparece para a loja e o cliente).</summary>
    public string? Placa { get; set; }

    /// <summary>Até quando o usuário já viu as notificações do app (as mais novas aparecem como não lidas).</summary>
    public DateTimeOffset? NotificacoesLidasAte { get; set; }

    /// <summary>Preenchido só quando Tipo = Estabelecimento.</summary>
    public Estabelecimento? Estabelecimento { get; set; }

    public List<EnderecoUsuario> Enderecos { get; set; } = [];
    public List<Pedido> Pedidos { get; set; } = [];
    public List<Favorito> Favoritos { get; set; } = [];
    public List<TokenRenovacao> TokensRenovacao { get; set; } = [];
}
