using Microsoft.AspNetCore.Html;

namespace Xepa.Web;

/// <summary>Ícones de traço do menu e dos botões (24 x 24, herdam a cor do texto).</summary>
public static class Icones
{
    private static readonly Dictionary<string, string> Caminhos = new()
    {
        ["painel"] = """<rect x="3" y="3" width="7" height="9" rx="1.5"/><rect x="14" y="3" width="7" height="5" rx="1.5"/><rect x="14" y="12" width="7" height="9" rx="1.5"/><rect x="3" y="16" width="7" height="5" rx="1.5"/>""",
        ["pedidos"] = """<path d="M5 2.5v19l2.3-1.5 2.4 1.5 2.3-1.5 2.3 1.5 2.4-1.5 2.3 1.5v-19l-2.3 1.5-2.4-1.5-2.3 1.5-2.3-1.5-2.4 1.5Z"/><path d="M8.5 8.5h7M8.5 12h7M8.5 15.5h4"/>""",
        ["lojas"] = """<path d="M3.5 9 5 4h14l1.5 5"/><path d="M3.5 9h17v1.5a2.8 2.8 0 0 1-5.7 0 2.8 2.8 0 0 1-5.6 0 2.8 2.8 0 0 1-5.7 0Z"/><path d="M5 13.5V20h14v-6.5"/><path d="M10 20v-4h4v4"/>""",
        ["entregadores"] = """<circle cx="5.5" cy="17" r="3"/><circle cx="18.5" cy="17" r="3"/><path d="M14.5 6H17l2.2 6.5"/><path d="M5.5 17 9 10.5h6.2l3.3 6.5"/><path d="M9 10.5 7.4 7H5"/>""",
        ["usuarios"] = """<circle cx="9" cy="8" r="3.5"/><path d="M2.5 20.5a6.5 6.5 0 0 1 13 0"/><path d="M16 4.6a3.5 3.5 0 0 1 0 6.8M21.5 20.5a6.5 6.5 0 0 0-3.7-5.9"/>""",
        ["denuncias"] = """<path d="M5 21.5V3.5"/><path d="M5 4h12.5l-2.2 4 2.2 4H5"/>""",
        ["repasses"] = """<rect x="2.5" y="5.5" width="19" height="14" rx="2.5"/><path d="M2.5 10h19"/><path d="M15.5 15h3"/>""",
        ["ofertas"] = """<path d="M20.3 13.3 13.3 20.3a1.9 1.9 0 0 1-2.7 0L3.5 13.2V3.5h9.7l7.1 7.1a1.9 1.9 0 0 1 0 2.7Z"/><circle cx="8" cy="8" r="1.5"/>""",
        ["impacto"] = """<path d="M3.5 3.5v17h17"/><path d="m7.5 14.5 3.8-4 3 3 5-6"/>""",
        ["sair"] = """<path d="M9.5 20.5h-4a2 2 0 0 1-2-2v-13a2 2 0 0 1 2-2h4"/><path d="m15.5 16.5 4.5-4.5-4.5-4.5M20 12H9.5"/>""",
        ["voltar"] = """<path d="M19 12H5M11 18l-6-6 6-6"/>""",
        ["editar"] = """<path d="M4 20h4L19 9a2.8 2.8 0 0 0-4-4L4 16v4Z"/><path d="m13.5 6.5 4 4"/>""",
        ["estrela"] = """<path d="m12 3.5 2.6 5.3 5.9.9-4.3 4.1 1 5.8L12 16.9l-5.2 2.7 1-5.8-4.3-4.1 5.9-.9Z"/>""",
        ["inicio"] = """<path d="M3.5 10.5 12 3.5l8.5 7"/><path d="M5.5 9v11h13V9"/><path d="M10 20v-5.5h4V20"/>""",
        ["config"] = """<circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.7 1.7 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-1.8-.3 1.7 1.7 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1a1.7 1.7 0 0 0-1.1-1.5 1.7 1.7 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.7 1.7 0 0 0 .3-1.8 1.7 1.7 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1a1.7 1.7 0 0 0 1.5-1.1 1.7 1.7 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.7 1.7 0 0 0 1.8.3H9a1.7 1.7 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1a1.7 1.7 0 0 0 1 1.5 1.7 1.7 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0-.3 1.8V9a1.7 1.7 0 0 0 1.5 1H21a2 2 0 1 1 0 4h-.1a1.7 1.7 0 0 0-1.5 1Z"/>""",
        ["relogio"] = """<circle cx="12" cy="12" r="8.5"/><path d="M12 7.5V12l3 2"/>""",
        ["repetir"] = """<path d="M4 12a8 8 0 0 1 13.7-5.7L20 8.5"/><path d="M20 4v4.5h-4.5"/><path d="M20 12a8 8 0 0 1-13.7 5.7L4 15.5"/><path d="M4 20v-4.5h4.5"/>""",
        ["pausa"] = """<circle cx="12" cy="12" r="8.5"/><path d="M10 9v6M14 9v6"/>""",
        ["mais"] = """<path d="M12 5v14M5 12h14"/>""",
        ["email"] = """<rect x="3" y="5" width="18" height="14" rx="2"/><path d="m3.5 6 8.5 7 8.5-7"/>""",
    };

    public static IHtmlContent Svg(string nome, int tamanho = 20) => new HtmlString(
        $"""<svg class="icone" width="{tamanho}" height="{tamanho}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">{Caminhos[nome]}</svg>""");

    /// <summary>Estrelas cheias de 1 a 5 (a nota arredondada), para tabelas e cartões.</summary>
    public static IHtmlContent Estrelas(double? nota)
    {
        if (nota is not { } n)
            return new HtmlString("""<span class="sem-nota">sem nota</span>""");
        var cheias = (int)Math.Round(n, MidpointRounding.AwayFromZero);
        return new HtmlString(
            $"""<span class="estrelas" title="{n.ToString("0.0", Rotulos.Br)} de 5"><span>{new string('★', cheias)}</span>{new string('★', 5 - cheias)}</span>""");
    }
}
