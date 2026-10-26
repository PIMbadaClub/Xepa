namespace Xepa.Domain.Entities;

/// <summary>
/// Token de renovação do app (7 dias). Só o hash é gravado; cada uso gera um novo token e revoga o anterior.
/// </summary>
public class TokenRenovacao
{
    public int Id { get; set; }
    public int UsuarioId { get; set; }
    public Usuario Usuario { get; set; } = null!;
    public required string TokenHash { get; set; }
    public DateTimeOffset ExpiraEm { get; set; }
    public DateTimeOffset? RevogadoEm { get; set; }
    public DateTimeOffset CriadoEm { get; set; } = DateTimeOffset.UtcNow;

    public bool Valido(DateTimeOffset agora) => RevogadoEm is null && ExpiraEm > agora;
}
