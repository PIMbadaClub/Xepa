using System.Globalization;
using Xepa.Application.Ofertas;
using Xepa.Domain.Entities;

namespace Xepa.Web;

/// <summary>Textos das telas para enums e formatos usados no portal.</summary>
public static class Rotulos
{
    public static readonly CultureInfo Br = CultureInfo.GetCultureInfo("pt-BR");

    public static string Dinheiro(decimal valor) => valor.ToString("C", Br);

    public static string Kg(decimal valor) => $"{valor.ToString("0.#", Br)} kg";

    public static string Data(DateTimeOffset d) =>
        TimeZoneInfo.ConvertTime(d, OfertaGestaoService.FusoBrasilia).ToString("dd/MM/yyyy HH:mm", Br);

    public static string Categoria(CategoriaEstabelecimento c) => c switch
    {
        CategoriaEstabelecimento.Restaurante => "Restaurante",
        CategoriaEstabelecimento.Padaria => "Padaria",
        CategoriaEstabelecimento.Mercado => "Mercado",
        _ => "Feira"
    };

    public static string Cadastro(StatusCadastro s) => s switch
    {
        StatusCadastro.Pendente => "Aguardando aprovação",
        StatusCadastro.Aprovado => "Aprovada",
        _ => "Rejeitada"
    };

    public static string Motivo(MotivoDenuncia m) => m switch
    {
        MotivoDenuncia.ComidaImpropria => "Comida imprópria para consumo",
        MotivoDenuncia.PedidoNaoEntregue => "Pedido não entregue",
        MotivoDenuncia.DiferenteDoAnunciado => "Diferente do anunciado",
        MotivoDenuncia.MauAtendimento => "Mau atendimento",
        MotivoDenuncia.Discriminacao => "Discriminação",
        _ => "Outro"
    };

    public static string Denuncia(StatusDenuncia s) => s switch
    {
        StatusDenuncia.Aberta => "Em análise",
        StatusDenuncia.Procedente => "Procedente",
        _ => "Improcedente"
    };

    public static string Tipo(TipoUsuario t) => t switch
    {
        TipoUsuario.Cliente => "Cliente",
        TipoUsuario.Estabelecimento => "Loja",
        TipoUsuario.Entregador => "Entregador",
        _ => "Administrador"
    };

    /// <summary>Cadastro do entregador (o da loja usa o feminino: "Aprovada").</summary>
    public static string CadastroEntregador(StatusCadastro s) => s switch
    {
        StatusCadastro.Pendente => "Aguardando aprovação",
        StatusCadastro.Aprovado => "Aprovado",
        _ => "Rejeitado"
    };

    public static string Pedido(StatusPedido s, TipoEntrega tipo) => s switch
    {
        StatusPedido.AguardandoPagamento => "Aguardando pagamento",
        StatusPedido.Pendente => "Aguardando aceite",
        StatusPedido.Confirmado => "Aceito",
        StatusPedido.EmPreparo => "Em preparo",
        StatusPedido.ProntoParaRetirada when tipo == TipoEntrega.Entrega => "Pronto para coleta",
        StatusPedido.ProntoParaRetirada => "Aguardando retirada",
        StatusPedido.SaiuParaEntrega => "Em rota",
        StatusPedido.Entregue => "Entregue",
        _ => "Cancelado"
    };

    /// <summary>Classe do selo do status: verde entregue, vermelho cancelado, bege em andamento.</summary>
    public static string ClassePedido(StatusPedido s) => s switch
    {
        StatusPedido.Entregue => "ativa",
        StatusPedido.Cancelado => "perigo",
        StatusPedido.AguardandoPagamento => "inativa",
        _ => "sacola"
    };

    public static string Entrega(TipoEntrega t) => t == TipoEntrega.Entrega ? "Entrega" : "Retirada";

    public static string Metodo(MetodoPagamento m) => m == MetodoPagamento.Pix ? "Pix" : "Cartão";

    public static string Pagamento(StatusPagamento s) => s switch
    {
        StatusPagamento.Pendente => "Pendente",
        StatusPagamento.Aprovado => "Aprovado",
        StatusPagamento.Recusado => "Recusado",
        _ => "Estornado"
    };

    public static string Km(double km) => $"{km.ToString("0.0", Br)} km";

    public static string Nota(double? nota) => nota is { } n ? n.ToString("0.0", Br) : "—";
}
