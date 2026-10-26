namespace Xepa.Domain.Entities;

/// <summary>Estabelecimento favoritado pelo cliente. Chave composta (UsuarioId, EstabelecimentoId).</summary>
public class Favorito
{
    public int UsuarioId { get; set; }
    public Usuario Usuario { get; set; } = null!;

    public int EstabelecimentoId { get; set; }
    public Estabelecimento Estabelecimento { get; set; } = null!;

    public DateTimeOffset CriadoEm { get; set; } = DateTimeOffset.UtcNow;
}
