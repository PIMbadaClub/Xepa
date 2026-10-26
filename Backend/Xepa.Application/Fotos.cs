using Xepa.Domain;

namespace Xepa.Application;

/// <summary>Arquivo de imagem recebido num formulário (oferta, denúncia).</summary>
public record Foto(Stream Conteudo, string NomeArquivo, long Tamanho);

/// <summary>Regras comuns de upload de fotos: JPG, PNG ou WEBP de até 5 MB.</summary>
public static class Fotos
{
    public const long TamanhoMaximo = 5 * 1024 * 1024;

    private static readonly Dictionary<string, string> Tipos = new(StringComparer.OrdinalIgnoreCase)
    {
        [".jpg"] = "image/jpeg", [".jpeg"] = "image/jpeg", [".png"] = "image/png", [".webp"] = "image/webp"
    };

    /// <summary>Valida e grava a foto; devolve a URL pública.</summary>
    public static Task<string> SalvarAsync(IArmazenamento armazenamento, Foto foto, CancellationToken ct)
    {
        var extensao = Path.GetExtension(foto.NomeArquivo);
        if (!Tipos.TryGetValue(extensao, out var contentType))
            throw new RegraDeNegocioException("Envie a foto em JPG, PNG ou WEBP.");
        if (foto.Tamanho > TamanhoMaximo)
            throw new RegraDeNegocioException("A foto deve ter no máximo 5 MB.");

        return armazenamento.SalvarAsync(foto.Conteudo, extensao.ToLowerInvariant(), contentType, ct);
    }
}
