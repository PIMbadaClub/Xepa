namespace Xepa.Domain;

/// <summary>Violação de uma regra de negócio; a API devolve 422 com a mensagem.</summary>
public class RegraDeNegocioException(string mensagem) : Exception(mensagem);
