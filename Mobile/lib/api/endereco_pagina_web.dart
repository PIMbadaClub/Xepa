import 'package:web/web.dart' as web;

String? base() {
  final l = web.window.location;
  return '${l.origin}${l.pathname}';
}

void limparParametros() {
  final l = web.window.location;
  web.window.history.replaceState(null, '', '${l.origin}${l.pathname}${l.hash}');
}
