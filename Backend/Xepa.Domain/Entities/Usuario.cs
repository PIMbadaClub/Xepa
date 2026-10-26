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

    /// <summary>Preenchido só quando Tipo = Estabelecimento.</summary>
    public Estabelecimento? Estabelecimento { get; set; }

    public List<EnderecoUsuario> Enderecos { get; set; } = [];
    public List<Pedido> Pedidos { get; set; } = [];
    public List<Favorito> Favoritos { get; set; } = [];
    public List<TokenRenovacao> TokensRenovacao { get; set; } = [];
}
