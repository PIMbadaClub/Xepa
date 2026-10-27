namespace Xepa.Api.Seguranca;

/// <summary>
/// Quem pode usar o app como cliente (pedir, favoritar, endereços). O entregador parceiro usa a mesma conta
/// para pedir comida no "modo cliente" do app.
/// </summary>
public static class PapeisCliente
{
    public const string Todos = "Cliente,Entregador";
}
