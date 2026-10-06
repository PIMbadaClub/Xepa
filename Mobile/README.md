# Xepa

App para salvar comida de restaurantes, padarias, mercados e feiras que seria jogada fora.

## Como rodar

1. Crie um projeto Flutter vazio: `flutter create xepa`
2. Substitua a pasta `lib/` e o arquivo `pubspec.yaml` pelos deste pacote.
3. Instale as dependências: `flutter pub get`
4. Rode o app: `flutter run`

Requer Flutter 3.22 ou mais recente (usa `WidgetStateProperty` e Dart 3).

## Estrutura

- `lib/main.dart`: ponto de entrada.
- `lib/theme.dart`: cores da marca, tema e formatadores de preço e distância.
- `lib/models/oferta.dart`: modelo de oferta, categorias e dados de exemplo.
- `lib/widgets/xepa_logo.dart`: logo do tomate com x, desenhado em código.
- `lib/widgets/oferta_widgets.dart`: banner "Hora da xepa", card de oferta e selo de restantes.
- `lib/screens/home_shell.dart`: barra de navegação inferior.
- `lib/screens/home_screen.dart`: tela inicial com busca, filtro por categoria e lista.
- `lib/screens/detalhe_screen.dart`: detalhe da sacola com quantidade e reserva.

## Próximos passos

- Trocar `ofertasExemplo` por dados vindos de uma API ou do Firebase.
- Gerar o ícone do app com o pacote `flutter_launcher_icons`.
- Criar as telas de mapa, pedidos, favoritos e perfil.
