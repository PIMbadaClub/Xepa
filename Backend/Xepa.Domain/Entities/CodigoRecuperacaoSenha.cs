namespace Xepa.Domain.Entities;

/// <summary>
/// Código de 6 dígitos enviado por e-mail para redefinir a senha. Vale 15 minutos, aceita até 5 tentativas
/// e só o hash é gravado.
/// </summary>
public class CodigoRecuperacaoSenha
{
    public const int MaximoTentativas = 5;
    public static readonly TimeSpan Validade = TimeSpan.FromMinutes(15);

    public int Id { get; set; }
    public int UsuarioId { get; set; }
    public Usuario Usuario { get; set; } = null!;
    public required string CodigoHash { get; set; }
    public DateTimeOffset CriadoEm { get; set; } = DateTimeOffset.UtcNow;
    public DateTimeOffset ExpiraEm { get; set; }
    public DateTimeOffset? UsadoEm { get; set; }
    public int Tentativas { get; set; }

    public bool Valido(DateTimeOffset agora) => UsadoEm is null && ExpiraEm > agora && Tentativas < MaximoTentativas;
}
