using Azure;
using Azure.Communication.Email;
using Microsoft.Extensions.Logging;
using Xepa.Application;

namespace Xepa.Infrastructure.Integracoes;

/// <summary>E-mail pelo Azure Communication Services (remetente do domínio gerenciado pela Azure).</summary>
public class EnvioEmailAzure(EmailClient cliente, string remetente) : IEnvioEmail
{
    public async Task EnviarAsync(string para, string nome, string assunto, string html, string texto, CancellationToken ct)
    {
        var mensagem = new EmailMessage(remetente, new EmailRecipients([new EmailAddress(para, nome)]),
            new EmailContent(assunto) { Html = html, PlainText = texto });
        // Started: a Azure aceitou o envio; não espera a entrega para não segurar a resposta do app.
        await cliente.SendAsync(WaitUntil.Started, mensagem, ct);
    }
}

/// <summary>Sem serviço de e-mail configurado (desenvolvimento): o conteúdo vai para o log.</summary>
public class EnvioEmailLog(ILogger<EnvioEmailLog> log) : IEnvioEmail
{
    public Task EnviarAsync(string para, string nome, string assunto, string html, string texto, CancellationToken ct)
    {
        log.LogWarning("E-mail não enviado (sem Email:ConnectionString). Para {Para}: {Assunto} | {Texto}", para, assunto, texto);
        return Task.CompletedTask;
    }
}
