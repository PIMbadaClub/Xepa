using Azure.Storage.Blobs;
using Azure.Storage.Blobs.Models;
using Xepa.Application;

namespace Xepa.Infrastructure;

/// <summary>Grava as fotos num contêiner do Azure Blob Storage com leitura pública dos blobs.</summary>
public class ArmazenamentoBlob(BlobContainerClient container) : IArmazenamento
{
    public async Task<string> SalvarAsync(Stream conteudo, string extensao, string contentType, CancellationToken ct)
    {
        var blob = container.GetBlobClient($"{DateTime.UtcNow:yyyy/MM}/{Guid.NewGuid():N}{extensao}");
        await blob.UploadAsync(conteudo, new BlobUploadOptions { HttpHeaders = new BlobHttpHeaders { ContentType = contentType } }, ct);
        return blob.Uri.ToString();
    }
}

/// <summary>Desenvolvimento: grava as fotos numa pasta servida como arquivo estático.</summary>
public class ArmazenamentoLocal(string pasta, string urlBase) : IArmazenamento
{
    public async Task<string> SalvarAsync(Stream conteudo, string extensao, string contentType, CancellationToken ct)
    {
        Directory.CreateDirectory(pasta);
        var nome = $"{Guid.NewGuid():N}{extensao}";
        await using (var arquivo = File.Create(Path.Combine(pasta, nome)))
            await conteudo.CopyToAsync(arquivo, ct);

        return $"{urlBase.TrimEnd('/')}/{nome}";
    }
}
