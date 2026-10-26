# 🍽️ XEPA - Combate ao Desperdício de Alimentos

O **XEPA** é um aplicativo mobile que conecta restaurantes e consumidores para reduzir o desperdício de comida. Os estabelecimentos disponibilizam refeições excedentes, que seriam descartadas, e os usuários podem adquiri-las com desconto e recebê-las por delivery diretamente pelo app.

A proposta une impacto ambiental e social: menos comida no lixo, mais economia para o consumidor e uma nova fonte de receita para os restaurantes.

## 🚀 Tecnologias Utilizadas

O projeto utiliza uma arquitetura separada entre aplicativo mobile e API (Client-Server):

### Mobile

* **Flutter + Dart:** Framework para desenvolvimento do app multiplataforma (Android e iOS).
* **HTTP / Dio:** Consumo da API REST.
* **Gerenciamento de estado:** Provider, Bloc ou Riverpod (conforme definido no projeto).

### Backend

* **C#:** Linguagem principal da API.
* **ASP.NET Core Web API:** Criação dos endpoints REST.
* **Entity Framework Core:** ORM para comunicação com o banco de dados.
* **JWT:** Autenticação e autorização dos usuários.

## 📂 Estrutura do Repositório

O repositório está dividido em duas pastas principais:

1. `/Mobile`: Contém o aplicativo Flutter (telas, serviços, modelos e configurações).
2. `/Backend`: Contém a API, o portal web, as regras de negócio e o acesso a dados (.NET 10).

## 🛠️ Como Executar o Projeto

### Pré-requisitos

* SDK do .NET 10
* SQL Server LocalDB (vem com o Visual Studio) ou Docker
* Flutter SDK (versão estável mais recente), com Android Studio ou VS Code
* Emulador Android/iOS ou dispositivo físico

### Estrutura do Backend

| Projeto | Camada | Conteúdo |
|---|---|---|
| `Xepa.Domain` | Domínio | Entidades, enums e regras de negócio (sem dependências) |
| `Xepa.Application` | Aplicação | Serviços de caso de uso, DTOs e interfaces das integrações |
| `Xepa.Infrastructure` | Infraestrutura | EF Core, migrations, procedures/triggers, armazenamento de fotos, mapas |
| `Xepa.Api` | Apresentação | API REST do app (JWT, rate limit, health check) |
| `Xepa.Web` | Apresentação | Portal do estabelecimento e da administração (MVC, cookie) |
| `Xepa.Tests` | Testes | Testes de unidade das regras |

### Configurando o Backend

1. Navegue até a pasta: `cd Backend`
2. Restaure as ferramentas: `dotnet tool restore`
3. Crie o banco com dados de demonstração:
   `dotnet ef database update --project Xepa.Infrastructure --startup-project Xepa.Api`
4. Suba a API: `dotnet run --project Xepa.Api` → `http://localhost:5000/swagger`
5. Suba o portal: `dotnet run --project Xepa.Web` → `http://localhost:5148`
6. Testes: `dotnet test`

Usuários de demonstração (senha `Xepa@2026`): `cliente@xepa.test`, `padaria@xepa.test` (loja),
`admin@xepa.test` e `entregador@xepa.test`. Exemplos de chamadas em `Backend/Xepa.Api/Xepa.Api.http`.

Com Docker: `docker compose up --build` dentro de `Backend` (SQL Server, API e portal).

Para mudar o banco: altere as entidades, gere uma migration
(`dotnet ef migrations add Nome --project Xepa.Infrastructure --startup-project Xepa.Api --output-dir Data/Migrations`)
e nunca edite o banco à mão. Procedures e triggers também vão por migration.

### Integrações (Sprint 2)

Sem chaves, tudo funciona em modo de teste: o pagamento usa um **gateway simulado** (o app mostra o botão
"Simular pagamento aprovado") e o mapa usa estimativa de rota e imagens do OpenStreetMap.
Para usar os serviços reais, configure (de preferência com `dotnet user-secrets` ou no App Service):

| Chave | Para quê |
|---|---|
| `MercadoPago:AccessToken` | Credencial de teste ou produção do Mercado Pago (Pix e Checkout Pro) |
| `MercadoPago:SegredoWebhook` | Assinatura secreta do webhook (valida o cabeçalho `x-signature`) |
| `MercadoPago:UrlNotificacao` | URL pública de `POST /api/pagamentos/webhook` |
| `Mapas:AzureMapsChave` | Chave do Azure Maps (rotas, geocodificação e imagens do mapa) |
| `Cors:Origens` | Endereços do portal e do app web que podem chamar a API |
| `Api:UrlBase` e `Jwt:Chave` (portal) | O portal chama a API para os pedidos e assina o token com a mesma chave |

Tempo real: hub SignalR em `/hubs/pedidos` (status do pedido e posição do entregador).

### Administração e impacto (Sprint 3)

- **Cadastro de loja** em `/conta/cadastrar` no portal (o app leva para lá): a loja entra **pendente** e só aparece no app depois de aprovada (RN10).
- **Portal administrativo** (`admin@xepa.test`): painel, aprovação de lojas (geocodifica o endereço na aprovação), denúncias, suspensão de lojas e de contas, e **repasses** (a XEPA retém 15% sobre os produtos e repassa o restante mais as taxas de entrega).
- **Impacto e vendas** no portal da loja: kg salvos, economia gerada para os clientes, vendas por dia, mais vendidas e repasses.
- **App:** favoritos (`/api/favoritos`), denúncia em cada pedido pago (`/api/pedidos/{id}/denuncias`) e "Sua xepa" no perfil (`/api/usuarios/me/impacto`).

### Configurando o App Mobile

1. `cd Mobile` e `flutter pub get`
2. Rodar apontando para a API (e, se quiser, para o portal com `--dart-define=PORTAL_URL=...`): `flutter run --dart-define=API_URL=http://10.0.2.2:5000` (emulador Android)
   ou `flutter run -d chrome --dart-define=API_URL=http://localhost:5000` (navegador)
3. Testes: `flutter analyze` e `flutter test`

Perfis: cliente (compra, paga e acompanha) e entregador (`entregador@xepa.test`: entregas do dia, posição a cada 15 s).

### Deploy

O GitHub Actions compila e testa a cada push (`ci.yml`). A publicação no Azure (`cd.yml`) roda na `main`
quando a variável `AZURE_DEPLOY` do repositório está `true`; os secrets e variáveis necessários estão no início do arquivo.

## 📝 Requisitos Funcionais

### 👤 Usuário

* **RF01:** O sistema deve permitir o cadastro de usuários (clientes e restaurantes)
* **RF02:** O sistema deve permitir o login de usuários
* **RF03:** O sistema deve permitir logout
* **RF04:** O sistema deve permitir editar os dados do perfil

### 🏪 Restaurantes

* **RF05:** O restaurante deve poder cadastrar refeições excedentes (nome, descrição, foto, preço com desconto e quantidade)
* **RF06:** O restaurante deve poder editar e remover ofertas cadastradas
* **RF07:** O restaurante deve poder definir o horário limite de retirada/entrega das ofertas
* **RF08:** O restaurante deve poder visualizar e gerenciar os pedidos recebidos

### 🍲 Ofertas

* **RF09:** O sistema deve permitir a listagem de ofertas disponíveis
* **RF10:** O sistema deve permitir visualizar detalhes da oferta
* **RF11:** O sistema deve permitir buscar ofertas por nome, restaurante ou categoria
* **RF12:** O sistema deve exibir ofertas próximas à localização do usuário

### 🛒 Pedidos

* **RF13:** O sistema deve permitir criar pedidos a partir de uma oferta
* **RF14:** O sistema deve permitir visualizar o histórico de pedidos
* **RF15:** O sistema deve atualizar o status do pedido (ex: confirmado, em preparo, saiu para entrega, entregue)
* **RF16:** O sistema deve permitir o cancelamento de pedidos antes da confirmação

### 🚚 Delivery

* **RF17:** O usuário deve poder informar e gerenciar endereços de entrega
* **RF18:** O usuário deve poder acompanhar o status da entrega

### 🔗 Integração

* **RF19:** O app deve consumir dados da API backend
* **RF20:** O sistema deve validar os dados enviados entre o app e a API

## ⚙️ Requisitos Não Funcionais

### 🚀 Performance

* **RNF01:** O sistema deve responder requisições em até 2 segundos
* **RNF02:** O app deve carregar as listagens de forma fluida (paginação e cache de imagens)

### 🔒 Segurança

* **RNF03:** O sistema deve garantir autenticação segura (JWT)
* **RNF04:** Senhas e dados sensíveis devem ser armazenados de forma protegida (hash)
* **RNF05:** A comunicação entre app e API deve utilizar HTTPS

### 🧱 Arquitetura

* **RNF06:** O sistema deve seguir arquitetura Client-Server
* **RNF07:** A API deve seguir o padrão REST
* **RNF08:** O sistema deve ser modular (app separado do backend)

### 📱 Usabilidade

* **RNF09:** O app deve ter interface intuitiva e de fácil navegação
* **RNF10:** O app deve ser compatível com Android e iOS (Flutter)
* **RNF11:** A interface deve se adaptar a diferentes tamanhos de tela

### 🔄 Escalabilidade

* **RNF12:** O backend deve suportar aumento de usuários e de ofertas
* **RNF13:** O sistema deve permitir futuras integrações (ex: pagamento, notificações push, mapas)

### 🧪 Manutenibilidade

* **RNF14:** O código deve ser tipado (C# e Dart)
* **RNF15:** O sistema deve ser de fácil manutenção (uso de ORM e separação de responsabilidades)

## 👥 Integrantes do Grupo

* Jean Campos
* João Pedro
* Gabriel Massari
* Ramon
* Alexandre
* João Vitor
* Luiz

## 📄 Licença

Este projeto foi desenvolvido para fins estritamente acadêmicos.
