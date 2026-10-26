# Build em dois estágios: o SDK compila e só o resultado vai para a imagem de execução.
# Contexto do build: a pasta Backend (docker build -f Xepa.Web/Dockerfile .)
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src
COPY Xepa.Domain/Xepa.Domain.csproj Xepa.Domain/
COPY Xepa.Application/Xepa.Application.csproj Xepa.Application/
COPY Xepa.Infrastructure/Xepa.Infrastructure.csproj Xepa.Infrastructure/
COPY Xepa.Web/Xepa.Web.csproj Xepa.Web/
RUN dotnet restore Xepa.Web/Xepa.Web.csproj
COPY . .
RUN dotnet publish Xepa.Web/Xepa.Web.csproj -c Release -o /app --no-restore

FROM mcr.microsoft.com/dotnet/aspnet:10.0
WORKDIR /app
COPY --from=build /app .
USER app
EXPOSE 8080
ENTRYPOINT ["dotnet", "Xepa.Web.dll"]
