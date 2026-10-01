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
2. `/BackEnd`: Contém a API em C#, incluindo a lógica de negócio, acesso a dados e as rotas da aplicação.

## 🛠️ Como Executar o Projeto

### Pré-requisitos

* SDK do .NET (v8.0 ou superior)
* Flutter SDK (versão estável mais recente)
* Android Studio ou VS Code com as extensões de Flutter/Dart
* Emulador Android/iOS ou dispositivo físico
* Banco de dados configurado (ex: SQL Server ou PostgreSQL)

### Configurando o Backend

1. Navegue até a pasta: `cd BackEnd`
2. Configure a string de conexão do banco em `appsettings.json`
3. Restaure as dependências: `dotnet restore`
4. Aplique as migrations: `dotnet ef database update`
5. Execute a aplicação: `dotnet run`
   * A API estará disponível em `http://localhost:5000` (ou na porta configurada em `appsettings.json`).

### Configurando o App Mobile

1. Navegue até a pasta: `cd Mobile`
2. Instale as dependências: `flutter pub get`
3. Configure a URL base da API no projeto (em emulador Android, use `http://10.0.2.2:5000`)
4. Execute o app: `flutter run`

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
