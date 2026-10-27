"""
Gera infra/azure/dados-limeira.sql: lojas fictícias em endereços reais de Limeira-SP, com ofertas para hoje,
para testar o app na cidade. As coordenadas vêm do Azure Maps (geocodificação), então os pinos e as rotas
batem com as ruas de verdade.

Uso (Git Bash, com "az login" feito):  python infra/azure/gerar-dados-limeira.py
Depois aplique o SQL no banco (o script é idempotente e renova as ofertas a cada execução):
  sqlcmd -S tcp:<servidor>.database.windows.net -d xepa -U <usuario> -P <senha> -I -f 65001 -i infra/azure/dados-limeira.sql
"""
import json
import pathlib
import subprocess
import sys
import urllib.parse
import urllib.request

AQUI = pathlib.Path(__file__).resolve().parent
SAIDA = AQUI / "dados-limeira.sql"


def chave_azure_maps() -> str:
    env = dict(l.split("=", 1) for l in (AQUI / "xepa.env").read_text(encoding="utf-8").splitlines() if "=" in l)
    az = "az.cmd" if sys.platform == "win32" else "az"
    return subprocess.run([az, "maps", "account", "keys", "list", "-g", env["RG"], "-n", env["MAPAS"],
                           "--query", "primaryKey", "-o", "tsv"], capture_output=True, text=True, check=True).stdout.strip()


def geocodificar(chave: str, endereco: str):
    url = ("https://atlas.microsoft.com/search/address/json?api-version=1.0&countrySet=BR&limit=1&language=pt-BR"
           f"&query={urllib.parse.quote(endereco)}&subscription-key={chave}")
    with urllib.request.urlopen(url, timeout=30) as r:
        resultados = json.load(r).get("results", [])
    if not resultados:
        return None
    r = resultados[0]
    # Só aceita resultado em Limeira; o resto vira aviso.
    if "Limeira" not in json.dumps(r["address"], ensure_ascii=False):
        return None
    cep = r["address"].get("postalCode", "").replace("-", "")
    # O Azure Maps às vezes devolve só o prefixo ("13480"); sem os 8 dígitos usa o CEP geral de Limeira.
    return r["position"]["lat"], r["position"]["lon"], cep if len(cep) == 8 and cep.isdigit() else ""


def foto(id_, largura=800):
    return f"https://images.unsplash.com/photo-{id_}?w={largura}&q=75&auto=format&fit=crop"


# Nomes fictícios; endereços reais (rua e número aproximado) para a geocodificação cair no lugar certo.
LOJAS = [
    dict(email="laranjal@xepa.test", nome="Padaria Laranjal", cat="Padaria", rua="Rua Barão de Cascalho", num="455", bairro="Centro",
         logo="1517433670267-08bbd4be890f", ofertas=[
             ("SacolaSurpresa", "Sacola surpresa de pães", "Pães franceses, de forma e doces do dia.", 30, 11.90, 4, 1.6, "1509440159596-0249088772ff"),
             ("SacolaSurpresa", "Kit café da tarde", "Croissants, bolo e salgados assados que sobraram da vitrine.", 38, 14.90, 2, 1.2, "1555507036-ab1f4038808a")]),
    dict(email="morroazul@xepa.test", nome="Panificadora Morro Azul", cat="Padaria", rua="Rua Senador Vergueiro", num="1200", bairro="Centro",
         logo="1586444248902-2f64eddc13df", ofertas=[
             ("SacolaSurpresa", "Sacola surpresa", "Pães artesanais e de fermentação natural do dia.", 34, 12.90, 3, 1.5, "1586444248902-2f64eddc13df")]),
    dict(email="vilaclaudia@xepa.test", nome="Doceria Vila Claudia", cat="Padaria", rua="Avenida Campinas", num="900", bairro="Vila Claudia",
         logo="1550617931-e17a7b70dce2", ofertas=[
             ("SacolaSurpresa", "Caixa de doces", "Cupcakes, fatias de bolo e doces finos que não saíram hoje.", 45, 16.90, 3, 0.8, "1565958011703-44f9829ba187"),
             ("Prato", "Bolo inteiro do dia", "Bolo de festa de 1 kg feito hoje (sabor varia).", 70, 24.90, 1, 1.0, "1550617931-e17a7b70dce2")]),
    dict(email="bellalimeira@xepa.test", nome="Cantina Bella Limeira", cat="Restaurante", rua="Rua Santa Cruz", num="700", bairro="Centro",
         logo="1565299624946-b28f40a0ae38", ofertas=[
             ("Prato", "Massa do almoço", "Porção de massa com molho do dia, embalada para viagem.", 42, 15.90, 5, 0.6, "1621996346565-e3dbc646d9a9"),
             ("SacolaSurpresa", "Pizza de fim de noite", "Pizzas inteiras ou meias que sobraram do rodízio.", 60, 19.90, 2, 1.0, "1565299624946-b28f40a0ae38")]),
    dict(email="saborcaipira@xepa.test", nome="Sabor Caipira", cat="Restaurante", rua="Avenida Major José Levy Sobrinho", num="1500", bairro="Vila Cidade Jardim",
         logo="1504674900247-0877df9cc836", ofertas=[
             ("Prato", "Marmita caseira", "Arroz, feijão, mistura e salada do almoço.", 28, 11.90, 6, 0.7, "1504674900247-0877df9cc836")]),
    dict(email="sushicascalho@xepa.test", nome="Sushi do Cascalho", cat="Restaurante", rua="Rua Barão de Cascalho", num="1100", bairro="Centro",
         logo="1579584425555-c3ce17fd4351", ofertas=[
             ("SacolaSurpresa", "Combinado surpresa", "20 peças de sushi e hot roll do dia.", 75, 29.90, 2, 0.6, "1579584425555-c3ce17fd4351")]),
    dict(email="verdeleve@xepa.test", nome="Verde Leve Saladas", cat="Restaurante", rua="Avenida Comendador Agostinho Prada", num="2000", bairro="Jardim Nossa Senhora de Fátima",
         logo="1512621776951-a57141f2eefd", ofertas=[
             ("Prato", "Bowl do dia", "Bowl com grãos, legumes e proteína, montado hoje.", 36, 13.90, 4, 0.5, "1546069901-ba9599a7e63c"),
             ("Prato", "Salada completa", "Salada grande com molho à parte.", 30, 10.90, 3, 0.4, "1512621776951-a57141f2eefd")]),
    dict(email="bomjardim@xepa.test", nome="Mercado Bom Jardim", cat="Mercado", rua="Rua Carlos Gomes", num="800", bairro="Centro",
         logo="1534723452862-4c874018d66d", ofertas=[
             ("SacolaSurpresa", "Kit despensa", "Laticínios, frios e itens perto da validade, todos dentro do prazo.", 55, 21.90, 3, 2.5, "1534723452862-4c874018d66d")]),
    dict(email="emporiotoledo@xepa.test", nome="Empório Toledo", cat="Mercado", rua="Rua Tiradentes", num="600", bairro="Centro",
         logo="1606787366850-de6330128bfc", ofertas=[
             ("SacolaSurpresa", "Cesta do empório", "Queijos, embutidos e pães especiais da semana.", 80, 29.90, 2, 1.8, "1606787366850-de6330128bfc")]),
    dict(email="quitanda@xepa.test", nome="Quitanda da Boa Morte", cat="Feira", rua="Rua Boa Morte", num="900", bairro="Centro",
         logo="1610832958506-aa56368176cf", ofertas=[
             ("SacolaSurpresa", "Caixa de frutas", "Frutas maduras e boas para consumo hoje ou para doces e sucos.", 32, 9.90, 5, 3.5, "1610832958506-aa56368176cf"),
             ("SacolaSurpresa", "Kit legumes e verduras", "Legumes e folhas da xepa do dia.", 26, 8.90, 4, 3.0, "1540420773420-3366772f4999")]),
    dict(email="feiradapraca@xepa.test", nome="Barraca Feira da Praça", cat="Feira", rua="Rua Doutor Trajano de Barros Camargo", num="500", bairro="Centro",
         logo="1488459716781-31db52582fe9", ofertas=[
             ("SacolaSurpresa", "Xepa da feira", "Mix de frutas, verduras e legumes no fim da feira.", 30, 9.90, 6, 4.0, "1488459716781-31db52582fe9")]),
    dict(email="docesdacasa@xepa.test", nome="Doces da Casa", cat="Padaria", rua="Rua Alferes Franco", num="300", bairro="Centro",
         logo="1563805042-7684c019e1cb", ofertas=[
             ("SacolaSurpresa", "Sobremesas do dia", "Copos de sobremesa e mousses feitos hoje.", 40, 14.90, 3, 0.8, "1563805042-7684c019e1cb")]),
]

# Endereço de entrega do cliente demo em Limeira (fica como principal), a uns 3 km do centro: corridas realistas.
CLIENTE = dict(rua="Rua Pedro Zaccaria", num="300", bairro="Jardim São Paulo")


def sql(texto):
    return "N'" + str(texto).replace("'", "''") + "'"


def main():
    chave = chave_azure_maps()
    linhas = [
        "-- Gerado por infra/azure/gerar-dados-limeira.py. Lojas fictícias em endereços reais de Limeira-SP.",
        "-- Idempotente: cria o que falta e renova as ofertas para hoje (as antigas dessas lojas saem do ar).",
        "-- Todas as contas usam a senha dos dados de demonstração (Xepa@2026).",
        "SET NOCOUNT ON; SET XACT_ABORT ON;",
        "BEGIN TRAN;",
        "DECLARE @hash nvarchar(max) = (SELECT SenhaHash FROM Usuarios WHERE Email = 'cliente@xepa.test');",
        "IF @hash IS NULL THROW 50001, 'Rode antes as migrations com os dados de demonstração (cliente@xepa.test).', 1;",
        "DECLARE @agora datetimeoffset = SYSDATETIMEOFFSET();",
        "DECLARE @local datetimeoffset = @agora AT TIME ZONE 'E. South America Standard Time';",
        "-- Retirada de agora até 23h30 de hoje (ou de amanhã, se já passou das 22h).",
        "DECLARE @dia date = CASE WHEN DATEPART(hour, @local) >= 22 THEN DATEADD(day, 1, CAST(@local AS date)) ELSE CAST(@local AS date) END;",
        "DECLARE @inicio datetimeoffset = CASE WHEN @dia > CAST(@local AS date) THEN TODATETIMEOFFSET(DATEADD(hour, 11, CAST(@dia AS datetime2)), '-03:00') ELSE DATEADD(minute, -5, @agora) END;",
        "DECLARE @fim datetimeoffset = TODATETIMEOFFSET(DATEADD(minute, 1410, CAST(@dia AS datetime2)), '-03:00');",
        "DECLARE @u int, @e int;",
        "",
    ]

    for loja in LOJAS:
        endereco = f"{loja['rua']}, {loja['num']}, {loja['bairro']}, Limeira - SP"
        ponto = geocodificar(chave, endereco)
        if ponto is None:
            print(f"AVISO: não localizei {endereco}; loja {loja['nome']} ficou de fora.")
            continue
        lat, lon, cep = ponto
        print(f"{loja['nome']:28} {lat:.5f}, {lon:.5f}  {endereco}")
        linhas += [
            f"-- {loja['nome']}",
            f"IF NOT EXISTS (SELECT 1 FROM Usuarios WHERE Email = '{loja['email']}')",
            f"    INSERT INTO Usuarios (Nome, Email, SenhaHash, Tipo, Bloqueado, CriadoEm) VALUES ({sql(loja['nome'])}, '{loja['email']}', @hash, 'Estabelecimento', 0, @agora);",
            f"SET @u = (SELECT Id FROM Usuarios WHERE Email = '{loja['email']}');",
            "IF NOT EXISTS (SELECT 1 FROM Estabelecimentos WHERE UsuarioId = @u)",
            "    INSERT INTO Estabelecimentos (UsuarioId, Nome, Categoria, LogoUrl, Cep, Logradouro, Numero, Bairro, Cidade, Uf, Latitude, Longitude, StatusCadastro, Ativo, CriadoEm)",
            f"    VALUES (@u, {sql(loja['nome'])}, '{loja['cat']}', '{foto(loja['logo'], 160)}', '{cep or '13480000'}', {sql(loja['rua'])}, '{loja['num']}', {sql(loja['bairro'])}, N'Limeira', 'SP', {lat}, {lon}, 'Aprovado', 1, @agora);",
            "SET @e = (SELECT Id FROM Estabelecimentos WHERE UsuarioId = @u);",
            "UPDATE Ofertas SET Ativa = 0, AtualizadoEm = @agora WHERE EstabelecimentoId = @e AND Ativa = 1;",
        ]
        for tipo, titulo, desc, original, preco, qtd, kg, img in loja["ofertas"]:
            linhas.append(
                "INSERT INTO Ofertas (EstabelecimentoId, Tipo, Titulo, Descricao, FotoUrl, PrecoOriginal, Preco, QuantidadeDisponivel, PesoEstimadoKg, RetiradaInicio, RetiradaFim, Ativa, CriadoEm) "
                f"VALUES (@e, '{tipo}', {sql(titulo)}, {sql(desc)}, '{foto(img)}', {original:.2f}, {preco:.2f}, {qtd}, {kg}, @inicio, @fim, 1, @agora);")
        linhas.append("")

    cliente = f"{CLIENTE['rua']}, {CLIENTE['num']}, {CLIENTE['bairro']}, Limeira - SP"
    ponto = geocodificar(chave, cliente)
    if ponto:
        lat, lon, cep = ponto
        linhas += [
            "-- Endereço de entrega do cliente demo em Limeira (passa a ser o principal).",
            "SET @u = (SELECT Id FROM Usuarios WHERE Email = 'cliente@xepa.test');",
            "UPDATE Enderecos SET Principal = 0 WHERE UsuarioId = @u AND Cidade <> N'Limeira';",
            "IF EXISTS (SELECT 1 FROM Enderecos WHERE UsuarioId = @u AND Cidade = N'Limeira')",
            f"    UPDATE Enderecos SET Principal = 1, Cep = '{cep or '13480000'}', Logradouro = {sql(CLIENTE['rua'])}, Numero = '{CLIENTE['num']}', Bairro = {sql(CLIENTE['bairro'])},",
            f"        Latitude = {lat}, Longitude = {lon}, AtualizadoEm = @agora WHERE UsuarioId = @u AND Cidade = N'Limeira';",
            "ELSE",
            "    INSERT INTO Enderecos (UsuarioId, Apelido, Principal, Cep, Logradouro, Numero, Bairro, Cidade, Uf, Latitude, Longitude, CriadoEm)",
            f"    VALUES (@u, N'Casa em Limeira', 1, '{cep or '13480000'}', {sql(CLIENTE['rua'])}, '{CLIENTE['num']}', {sql(CLIENTE['bairro'])}, N'Limeira', 'SP', {lat}, {lon}, @agora);",
            "",
        ]
        print(f"{'Cliente demo (entrega)':28} {lat:.5f}, {lon:.5f}  {cliente}")

    linhas += [
        "COMMIT;",
        "SELECT e.Nome, e.Bairro, COUNT(o.Id) AS OfertasHoje FROM Estabelecimentos e LEFT JOIN Ofertas o ON o.EstabelecimentoId = e.Id AND o.Ativa = 1 AND o.RetiradaFim > @agora",
        "WHERE e.Cidade = N'Limeira' GROUP BY e.Nome, e.Bairro ORDER BY e.Nome;",
    ]
    SAIDA.write_text("\n".join(linhas) + "\n", encoding="utf-8")
    print(f"\nGerado: {SAIDA}")


if __name__ == "__main__":
    main()
