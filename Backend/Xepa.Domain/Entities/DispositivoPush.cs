namespace Xepa.Domain.Entities;

/// <summary>Celular que recebe notificação push (token do Firebase Cloud Messaging). Um usuário pode ter vários.</summary>
public class DispositivoPush : Entidade
{
    public int UsuarioId { get; set; }
    public Usuario Usuario { get; set; } = null!;

    public required string Token { get; set; }

    /// <summary>android, ios ou web.</summary>
    public required string Plataforma { get; set; }
}
