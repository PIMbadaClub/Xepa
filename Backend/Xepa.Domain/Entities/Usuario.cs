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

    /// <summary>Conta Google vinculada ("Continuar com Google"): o "sub" do Google, que não muda.</summary>
    public string? GoogleId { get; set; }

    /// <summary>Modelo da moto do entregador (ex.: Honda CG 160), só para exibição.</summary>
    public string? ModeloMoto { get; set; }

    /// <summary>Entregador online recebe corridas; offline, só termina a que já aceitou.</summary>
    public bool Online { get; set; }

    /// <summary>Distância máxima até a loja para o entregador ver a corrida.</summary>
    public int RaioCorridasKm { get; set; } = 8;

    /// <summary>Até quando o usuário já viu as notificações do app (as mais novas aparecem como não lidas).</summary>
    public DateTimeOffset? NotificacoesLidasAte { get; set; }

    /// <summary>Preenchido só quando Tipo = Estabelecimento.</summary>
    public Estabelecimento? Estabelecimento { get; set; }

    public List<EnderecoUsuario> Enderecos { get; set; } = [];
    public List<Pedido> Pedidos { get; set; } = [];
    public List<Favorito> Favoritos { get; set; } = [];
    public List<TokenRenovacao> TokensRenovacao { get; set; } = [];
}
