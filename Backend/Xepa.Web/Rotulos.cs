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
}
