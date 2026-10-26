namespace Xepa.Application;

public record PaginaDto<T>(IReadOnlyList<T> Itens, int Pagina, int TamanhoPagina, int Total);
