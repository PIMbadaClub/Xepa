using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.Mvc;
using Xepa.Application;
using Xepa.Domain;

namespace Xepa.Api.Seguranca;

/// <summary>Converte as exceções de regra em respostas HTTP com ProblemDetails.</summary>
public class TratadorErros(IProblemDetailsService problemDetails) : IExceptionHandler
{
    public async ValueTask<bool> TryHandleAsync(HttpContext http, Exception exception, CancellationToken ct)
    {
        var (status, titulo) = exception switch
        {
            RegraDeNegocioException => (StatusCodes.Status422UnprocessableEntity, "Regra de negócio"),
            NaoEncontradoException => (StatusCodes.Status404NotFound, "Não encontrado"),
            AcessoNegadoException => (StatusCodes.Status401Unauthorized, "Acesso negado"),
            _ => (0, "")
        };
        if (status == 0)
            return false;

        http.Response.StatusCode = status;
        return await problemDetails.TryWriteAsync(new ProblemDetailsContext
        {
            HttpContext = http,
            ProblemDetails = new ProblemDetails { Status = status, Title = titulo, Detail = exception.Message },
            Exception = exception
        });
    }
}
