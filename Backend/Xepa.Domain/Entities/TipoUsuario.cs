namespace Xepa.Domain.Entities;

public enum TipoUsuario
{
    Cliente,
    Estabelecimento,

    /// <summary>Entregador de um estabelecimento (a entrega é feita pela própria loja).</summary>
    Entregador,

    /// <summary>Equipe da XEPA: aprova lojas, trata denúncias e acompanha repasses.</summary>
    Administrador
}
