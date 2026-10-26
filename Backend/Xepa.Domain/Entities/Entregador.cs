namespace Xepa.Domain.Entities;

/// <summary>Vínculo entre um usuário do tipo Entregador e a loja para a qual ele entrega.</summary>
public class Entregador
{
    public int EstabelecimentoId { get; set; }
    public Estabelecimento Estabelecimento { get; set; } = null!;

    public int UsuarioId { get; set; }
    public Usuario Usuario { get; set; } = null!;

    public bool Ativo { get; set; } = true;
    public DateTimeOffset CriadoEm { get; set; } = DateTimeOffset.UtcNow;
}
