using Microsoft.AspNetCore.Mvc.Filters;
using Microsoft.AspNetCore.Mvc.ViewFeatures;

namespace Xepa.Web;

/// <summary>
/// Token antifalsificação recusado (formulário aberto antes de entrar ou sair, ou trazido de volta pelo "Voltar" do
/// navegador): em vez da página em branco com erro 400, volta para a mesma tela com um aviso para tentar de novo.
/// </summary>
public class TokenExpirado(ITempDataDictionaryFactory tempData) : IAlwaysRunResultFilter
{
    public void OnResultExecuting(ResultExecutingContext context)
    {
        if (context.Result is not Microsoft.AspNetCore.Mvc.Core.Infrastructure.IAntiforgeryValidationFailedResult)
            return;

        var http = context.HttpContext;
        tempData.GetTempData(http)["Erro"] = "A página ficou desatualizada. Confira os dados e tente de novo.";
        // Volta para a página que enviou o formulário (o POST pode não ter tela própria, como o Sair).
        var origem = Uri.TryCreate(http.Request.Headers.Referer.ToString(), UriKind.Absolute, out var r) && r.Host == http.Request.Host.Host
            ? r.PathAndQuery
            : "/";
        context.Result = new Microsoft.AspNetCore.Mvc.RedirectResult(origem);
    }

    public void OnResultExecuted(ResultExecutedContext context)
    {
    }
}
