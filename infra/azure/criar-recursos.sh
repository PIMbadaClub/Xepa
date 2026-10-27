#!/usr/bin/env bash
# Cria (ou atualiza) os recursos da XEPA na Azure, no ambiente de homologação.
#
#   Grupo rg-xepa
#   ├─ App Service plan B1 Linux ─ xepa-api-<sufixo> (API + SignalR) e xepa-portal-<sufixo> (portal da loja)
#   ├─ Azure SQL (oferta gratuita, serverless, pausa ao esgotar a cota)
#   ├─ Storage Account: contêiner "fotos" (leitura pública) e site estático com o app Flutter compilado para web
#   └─ Azure Maps Gen2 (rotas e geocodificação)
#
# A assinatura Azure for Students só aceita algumas regiões (política "Allowed resource deployment regions"):
# chilecentral, francecentral, italynorth, spaincentral e southafricanorth. O Static Web Apps não existe
# em nenhuma delas, por isso o app web fica no site estático do Storage. O Chile Central recusa SQL
# para esta assinatura, então tudo fica no France Central.
#
# Uso (Git Bash, depois de "az login"):  bash infra/azure/criar-recursos.sh
# Pode rodar de novo: reaproveita os nomes e segredos gravados em infra/azure/xepa.env (fora do Git).
set -euo pipefail
export MSYS_NO_PATHCONV=1   # o Git Bash não pode converter argumentos que começam com "/"

DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="$DIR/xepa.env"

tsv() { az "$@" -o tsv | tr -d '\r'; }
aleatorio() { python -c "import secrets,sys; print(secrets.token_urlsafe(int(sys.argv[1])))" "$1"; }

# Nomes e segredos ficam fixos depois da primeira execução.
if [[ -f "$ENV_FILE" ]]; then
  source "$ENV_FILE"
else
  SUFIXO=$(python -c "import secrets; print(secrets.token_hex(3))")
  cat > "$ENV_FILE" <<EOF
SUFIXO=$SUFIXO
LOCAL=${LOCAL:-francecentral}
RG=rg-xepa
PLANO=plan-xepa
WEBAPP_API=xepa-api-$SUFIXO
WEBAPP_WEB=xepa-portal-$SUFIXO
SQL_SERVIDOR=sql-xepa-$SUFIXO
SQL_BANCO=xepa
SQL_USUARIO=xepaadmin
SQL_SENHA='Xp1!$(aleatorio 18)'
STORAGE=stxepa$SUFIXO
MAPAS=maps-xepa-$SUFIXO
EMAIL_SERVICO=xepa-email-$SUFIXO
COMUNICACAO=xepa-acs-$SUFIXO
JWT_CHAVE='$(aleatorio 48)'
EOF
  source "$ENV_FILE"
  echo "Nomes e segredos gravados em $ENV_FILE (não versionar)."
fi

# Recursos adicionados depois: xepa.env antigo não tem esses nomes.
EMAIL_SERVICO=${EMAIL_SERVICO:-xepa-email-$SUFIXO}
COMUNICACAO=${COMUNICACAO:-xepa-acs-$SUFIXO}

echo "Assinatura: $(tsv account show --query name)"

echo "== Provedores de recursos (assinatura nova vem sem eles)"
for ns in Microsoft.Sql Microsoft.Web Microsoft.Storage Microsoft.Maps Microsoft.Communication; do
  az provider register -n "$ns" --wait -o none
done

echo "== Grupo de recursos ($LOCAL)"
az group create -n "$RG" -l "$LOCAL" -o none

echo "== Azure SQL (oferta gratuita)"
if ! az sql server show -g "$RG" -n "$SQL_SERVIDOR" -o none 2>/dev/null; then
  az sql server create -g "$RG" -n "$SQL_SERVIDOR" -l "$LOCAL" \
    --admin-user "$SQL_USUARIO" --admin-password "$SQL_SENHA" -o none
fi
# 0.0.0.0 libera os serviços da Azure (App Service); o IP desta máquina, para aplicar as migrations.
az sql server firewall-rule create -g "$RG" -s "$SQL_SERVIDOR" -n AzureServices \
  --start-ip-address 0.0.0.0 --end-ip-address 0.0.0.0 -o none
MEU_IP=$(curl -fsS https://api.ipify.org)
az sql server firewall-rule create -g "$RG" -s "$SQL_SERVIDOR" -n MaquinaLocal \
  --start-ip-address "$MEU_IP" --end-ip-address "$MEU_IP" -o none
if ! az sql db show -g "$RG" -s "$SQL_SERVIDOR" -n "$SQL_BANCO" -o none 2>/dev/null; then
  az sql db create -g "$RG" -s "$SQL_SERVIDOR" -n "$SQL_BANCO" \
    -e GeneralPurpose -f Gen5 -c 2 --compute-model Serverless \
    --use-free-limit --free-limit-exhaustion-behavior AutoPause -o none
fi
CONEXAO="Server=tcp:$SQL_SERVIDOR.database.windows.net,1433;Database=$SQL_BANCO;User ID=$SQL_USUARIO;Password=$SQL_SENHA;Encrypt=True;TrustServerCertificate=False;Connection Timeout=60"

echo "== Storage (fotos)"
az storage account create -g "$RG" -n "$STORAGE" -l "$LOCAL" --sku Standard_LRS --kind StorageV2 \
  --allow-blob-public-access true --min-tls-version TLS1_2 -o none
BLOB=$(tsv storage account show-connection-string -g "$RG" -n "$STORAGE" --query connectionString)
az storage container create --name fotos --public-access blob --connection-string "$BLOB" -o none
az storage blob service-properties update --static-website --index-document index.html   --404-document index.html --connection-string "$BLOB" -o none
URL_APP=$(tsv storage account show -g "$RG" -n "$STORAGE" --query primaryEndpoints.web)
URL_APP=${URL_APP%/}

echo "== Azure Maps"
MAPAS_CHAVE=""
if az maps account create -g "$RG" -n "$MAPAS" -l global --kind Gen2 --sku G2 --accept-tos -o none 2>/dev/null \
   || az maps account show -g "$RG" -n "$MAPAS" -o none 2>/dev/null; then
  MAPAS_CHAVE=$(tsv maps account keys list -g "$RG" -n "$MAPAS" --query primaryKey)
else
  echo "   Azure Maps não foi criado; a API segue com a estimativa de rota (Haversine)."
fi

echo "== E-mail (Azure Communication Services, domínio gerenciado pela Azure)"
# Código de recuperação de senha. Sem o recurso, a API só registra o e-mail no log.
EMAIL_CONEXAO=""
EMAIL_REMETENTE=""
az extension add --name communication -y -o none 2>/dev/null || true
if (az communication email show -g "$RG" -n "$EMAIL_SERVICO" -o none 2>/dev/null \
      || az communication email create -g "$RG" -n "$EMAIL_SERVICO" --location global --data-location Brazil -o none) \
   && (az communication email domain show -g "$RG" --email-service-name "$EMAIL_SERVICO" --domain-name AzureManagedDomain -o none 2>/dev/null \
      || az communication email domain create -g "$RG" --email-service-name "$EMAIL_SERVICO" --domain-name AzureManagedDomain \
           --location global --domain-management AzureManaged -o none); then
  DOMINIO_EMAIL=$(tsv communication email domain show -g "$RG" --email-service-name "$EMAIL_SERVICO" --domain-name AzureManagedDomain --query id)
  az communication show -g "$RG" -n "$COMUNICACAO" -o none 2>/dev/null \
    || az communication create -g "$RG" -n "$COMUNICACAO" --location global --data-location Brazil --linked-domains "$DOMINIO_EMAIL" -o none
  EMAIL_CONEXAO=$(tsv communication list-key -g "$RG" -n "$COMUNICACAO" --query primaryConnectionString)
  EMAIL_REMETENTE="DoNotReply@$(tsv communication email domain show -g "$RG" --email-service-name "$EMAIL_SERVICO" \
    --domain-name AzureManagedDomain --query mailFromSenderDomain)"
else
  echo "   E-mail não foi criado; a recuperação de senha só aparece no log da API."
fi

echo "== App Service (B1 Linux)"
az appservice plan create -g "$RG" -n "$PLANO" -l "$LOCAL" --sku B1 --is-linux -o none
for app in "$WEBAPP_API" "$WEBAPP_WEB"; do
  az webapp show -g "$RG" -n "$app" -o none 2>/dev/null \
    || az webapp create -g "$RG" -p "$PLANO" -n "$app" --runtime "DOTNETCORE:10.0" -o none
  az webapp config set -g "$RG" -n "$app" --web-sockets-enabled true --always-on true \
    --http20-enabled true --min-tls-version 1.2 -o none
  az webapp update -g "$RG" -n "$app" --https-only true -o none
  # Perfil de publicação (usado pelo GitHub Actions) precisa da autenticação básica no SCM.
  az resource update -g "$RG" --namespace Microsoft.Web --resource-type basicPublishingCredentialsPolicies \
    --parent "sites/$app" -n scm --set properties.allow=true -o none
done

URL_API="https://$WEBAPP_API.azurewebsites.net"
URL_WEB="https://$WEBAPP_WEB.azurewebsites.net"

echo "== Configurações (homologação)"
az webapp config appsettings set -g "$RG" -n "$WEBAPP_API" -o none --settings \
  ASPNETCORE_ENVIRONMENT=Staging \
  "ConnectionStrings__Xepa=$CONEXAO" \
  "Jwt__Chave=$JWT_CHAVE" \
  "Cors__Origens__0=$URL_WEB" \
  "Cors__Origens__1=$URL_APP" \
  "Mapas__AzureMapsChave=$MAPAS_CHAVE" \
  "Armazenamento__BlobConnectionString=$BLOB" \
  "Email__ConnectionString=$EMAIL_CONEXAO" \
  "Email__Remetente=$EMAIL_REMETENTE" \
  "MercadoPago__UrlNotificacao=$URL_API/api/pagamentos/webhook"
# Mercado Pago: com MP_ACCESS_TOKEN no xepa.env a API usa o gateway real (credenciais de teste); sem ele, o simulado.
if [[ -n "${MP_ACCESS_TOKEN:-}" ]]; then
  az webapp config appsettings set -g "$RG" -n "$WEBAPP_API" -o none --settings \
    "MercadoPago__AccessToken=$MP_ACCESS_TOKEN" \
    "MercadoPago__SegredoWebhook=${MP_SEGREDO_WEBHOOK:-}" \
    "MercadoPago__UrlRetorno=$URL_APP" \
    "MercadoPago__PixSimulado=true"
fi
# Login com Google: com GOOGLE_CLIENT_ID e GOOGLE_CLIENT_SECRET no xepa.env (credencial OAuth "Aplicativo da Web",
# redirecionamento $URL_API/api/auth/google/retorno). Sem eles o botão do app avisa que não está configurado.
if [[ -n "${GOOGLE_CLIENT_ID:-}" && -n "${GOOGLE_CLIENT_SECRET:-}" ]]; then
  az webapp config appsettings set -g "$RG" -n "$WEBAPP_API" -o none --settings     "Google__ClientId=$GOOGLE_CLIENT_ID" "Google__ClientSecret=$GOOGLE_CLIENT_SECRET"
fi
az webapp config appsettings set -g "$RG" -n "$WEBAPP_WEB" -o none --settings \
  ASPNETCORE_ENVIRONMENT=Staging \
  "ConnectionStrings__Xepa=$CONEXAO" \
  "Jwt__Chave=$JWT_CHAVE" \
  "Api__UrlBase=$URL_API/" \
  "Api__UrlPublica=$URL_API" \
  "Mapas__AzureMapsChave=$MAPAS_CHAVE" \
  "Armazenamento__BlobConnectionString=$BLOB" \
  "Email__ConnectionString=$EMAIL_CONEXAO" \
  "Email__Remetente=$EMAIL_REMETENTE"

# Valores derivados, lidos pelo publicar.sh. Guardados junto dos segredos, fora do Git.
cat > "$DIR/xepa.saida.env" <<EOF
CONEXAO='$CONEXAO'
URL_API=$URL_API
URL_WEB=$URL_WEB
URL_APP=$URL_APP
BLOB='$BLOB'
EOF

cat <<EOF

Pronto.
  API:     $URL_API   (saúde: $URL_API/health)
  Portal:  $URL_WEB
  App web: $URL_APP

Próximo passo: bash infra/azure/publicar.sh

Para o deploy automático (GitHub > Settings > Secrets and variables > Actions):
  Variáveis: AZURE_DEPLOY=true  WEBAPP_API=$WEBAPP_API  WEBAPP_WEB=$WEBAPP_WEB  API_URL=$URL_API
  Secrets:   SQL_CONNECTION_STRING  (está em infra/azure/xepa.saida.env)
             AZURE_STORAGE_CONNECTION_STRING  (idem, BLOB)
             AZURE_PUBLISH_PROFILE_API / _WEB:
               az webapp deployment list-publishing-profiles -g $RG -n <app> --xml
EOF
