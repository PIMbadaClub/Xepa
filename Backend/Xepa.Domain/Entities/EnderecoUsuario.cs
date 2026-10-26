namespace Xepa.Domain.Entities;

/// <summary>Endereço de entrega cadastrado pelo cliente (RF17).</summary>
public class EnderecoUsuario : Entidade
{
    public int UsuarioId { get; set; }
    public Usuario Usuario { get; set; } = null!;

    /// <summary>Ex.: "Casa", "Trabalho".</summary>
    public required string Apelido { get; set; }
    public bool Principal { get; set; }
    public required Endereco Endereco { get; set; }
}
