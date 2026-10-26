#!/usr/bin/env bash
# Publica a versão desta máquina na Azure: migrations (com os dados de demonstração), API, portal e app web.
# Rode depois do criar-recursos.sh. O deploy automático pelo GitHub Actions (cd.yml) faz o mesmo sem os dados de demonstração.
#
# Uso (Git Bash):  bash infra/azure/publicar.sh [banco|api|portal|app]...   (sem argumentos publica tudo)
set -euo pipefail
export MSYS_NO_PATHCONV=1

DIR="$(cd "$(dirname "$0")" && pwd)"
# Caminho no formato C:/... (pwd -W): com MSYS_NO_PATHCONV o dotnet não entende /c/...
RAIZ="$(cd "$DIR/../.." && (pwd -W 2>/dev/null || pwd))"
source "$DIR/xepa.env"
source "$DIR/xepa.saida.env"
FLUTTER="${FLUTTER:-/c/Users/Hino/flutter/bin/flutter}"
SAIDA="$RAIZ/.publicar"

etapas=("$@")
[[ ${#etapas[@]} -eq 0 ]] && etapas=(banco api portal app)

zipar() { python -c "import shutil,sys; shutil.make_archive(sys.argv[1], 'zip', sys.argv[2])" "$1" "$2"; }

publicar_dotnet() { # projeto webapp
  local pasta="$SAIDA/$1"
  rm -rf "$pasta" "$pasta.zip"
  dotnet publish "$RAIZ/Backend/$1" -c Release -o "$pasta" --nologo -v q
  zipar "$pasta" "$pasta"
  az webapp deploy -g "$RG" -n "$2" --src-path "$pasta.zip" --type zip -o none
  echo "   aguardando https://$2.azurewebsites.net/health"
  for _ in $(seq 1 30); do
    curl -fsS "https://$2.azurewebsites.net/health" >/dev/null 2>&1 && { echo "   ok"; return; }
    sleep 10
  done
  echo "   o site não respondeu; veja os logs: az webapp log tail -g $RG -n $2" >&2
  return 1
}

for etapa in "${etapas[@]}"; do
  case "$etapa" in
    banco)
      echo "== Migrations no Azure SQL (com dados de demonstração)"
      # O IP da máquina muda; sem atualizar a regra o SQL recusa a conexão (erro 40615).
      MEU_IP=$(curl -fsS https://api.ipify.org)
      az sql server firewall-rule create -g "$RG" -s "$SQL_SERVIDOR" -n MaquinaLocal \
        --start-ip-address "$MEU_IP" --end-ip-address "$MEU_IP" -o none
      # Em Development o EF roda o seeding (usuários de teste, padaria e ofertas). Release para não
      # disputar os arquivos com uma API rodando localmente em Debug.
      (cd "$RAIZ/Backend" && ASPNETCORE_ENVIRONMENT=Development dotnet ef database update \
        --project Xepa.Infrastructure --startup-project Xepa.Api --configuration Release --connection "$CONEXAO")
      ;;
    api)    echo "== API";    publicar_dotnet Xepa.Api "$WEBAPP_API" ;;
    portal) echo "== Portal"; publicar_dotnet Xepa.Web "$WEBAPP_WEB" ;;
    app)
      echo "== App web (site estático do Storage)"
      (cd "$RAIZ/Mobile" && "$FLUTTER" build web --release --dart-define=API_URL="$URL_API" --dart-define=PORTAL_URL="$URL_WEB")
      az storage blob upload-batch -s "$RAIZ/Mobile/build/web" -d '$web' --overwrite \
        --connection-string "$BLOB" -o none
      ;;
    *) echo "Etapa desconhecida: $etapa (use banco, api, portal ou app)" >&2; exit 1 ;;
  esac
done

cat <<EOF

Publicado.
  API:     $URL_API/health
  Portal:  $URL_WEB      (padaria@xepa.test / Xepa@2026)
  App web: $URL_APP      (cliente@xepa.test e entregador@xepa.test / Xepa@2026)
EOF
