import 'retorno_google.dart';

/// No celular não há página: o Google devolve para o link do app (xepa://login).
String? base() => RetornoGoogle.enderecoApp;

void limparParametros() {}
