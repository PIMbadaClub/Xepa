-- Gerado por infra/azure/gerar-dados-limeira.py. Lojas fictícias em endereços reais de Limeira-SP.
-- Idempotente: cria o que falta e renova as ofertas para hoje (as antigas dessas lojas saem do ar).
-- Todas as contas usam a senha dos dados de demonstração (Xepa@2026).
SET NOCOUNT ON; SET XACT_ABORT ON;
BEGIN TRAN;
DECLARE @hash nvarchar(max) = (SELECT SenhaHash FROM Usuarios WHERE Email = 'cliente@xepa.test');
IF @hash IS NULL THROW 50001, 'Rode antes as migrations com os dados de demonstração (cliente@xepa.test).', 1;
DECLARE @agora datetimeoffset = SYSDATETIMEOFFSET();
DECLARE @local datetimeoffset = @agora AT TIME ZONE 'E. South America Standard Time';
-- Retirada de agora até 23h30 de hoje (ou de amanhã, se já passou das 22h).
DECLARE @dia date = CASE WHEN DATEPART(hour, @local) >= 22 THEN DATEADD(day, 1, CAST(@local AS date)) ELSE CAST(@local AS date) END;
DECLARE @inicio datetimeoffset = CASE WHEN @dia > CAST(@local AS date) THEN TODATETIMEOFFSET(DATEADD(hour, 11, CAST(@dia AS datetime2)), '-03:00') ELSE DATEADD(minute, -5, @agora) END;
DECLARE @fim datetimeoffset = TODATETIMEOFFSET(DATEADD(minute, 1410, CAST(@dia AS datetime2)), '-03:00');
DECLARE @u int, @e int;

-- Padaria Laranjal
IF NOT EXISTS (SELECT 1 FROM Usuarios WHERE Email = 'laranjal@xepa.test')
    INSERT INTO Usuarios (Nome, Email, SenhaHash, Tipo, Bloqueado, CriadoEm) VALUES (N'Padaria Laranjal', 'laranjal@xepa.test', @hash, 'Estabelecimento', 0, @agora);
SET @u = (SELECT Id FROM Usuarios WHERE Email = 'laranjal@xepa.test');
IF NOT EXISTS (SELECT 1 FROM Estabelecimentos WHERE UsuarioId = @u)
    INSERT INTO Estabelecimentos (UsuarioId, Nome, Categoria, LogoUrl, Cep, Logradouro, Numero, Bairro, Cidade, Uf, Latitude, Longitude, StatusCadastro, Ativo, CriadoEm)
    VALUES (@u, N'Padaria Laranjal', 'Padaria', 'https://images.unsplash.com/photo-1517433670267-08bbd4be890f?w=160&q=75&auto=format&fit=crop', '13480000', N'Rua Barão de Cascalho', '455', N'Centro', N'Limeira', 'SP', -22.5609394, -47.4015568, 'Aprovado', 1, @agora);
SET @e = (SELECT Id FROM Estabelecimentos WHERE UsuarioId = @u);
UPDATE Ofertas SET Ativa = 0, AtualizadoEm = @agora WHERE EstabelecimentoId = @e AND Ativa = 1;
INSERT INTO Ofertas (EstabelecimentoId, Tipo, Titulo, Descricao, FotoUrl, PrecoOriginal, Preco, QuantidadeDisponivel, PesoEstimadoKg, RetiradaInicio, RetiradaFim, Ativa, CriadoEm) VALUES (@e, 'SacolaSurpresa', N'Sacola surpresa de pães', N'Pães franceses, de forma e doces do dia.', 'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=800&q=75&auto=format&fit=crop', 30.00, 11.90, 4, 1.6, @inicio, @fim, 1, @agora);
INSERT INTO Ofertas (EstabelecimentoId, Tipo, Titulo, Descricao, FotoUrl, PrecoOriginal, Preco, QuantidadeDisponivel, PesoEstimadoKg, RetiradaInicio, RetiradaFim, Ativa, CriadoEm) VALUES (@e, 'SacolaSurpresa', N'Kit café da tarde', N'Croissants, bolo e salgados assados que sobraram da vitrine.', 'https://images.unsplash.com/photo-1555507036-ab1f4038808a?w=800&q=75&auto=format&fit=crop', 38.00, 14.90, 2, 1.2, @inicio, @fim, 1, @agora);

-- Panificadora Morro Azul
IF NOT EXISTS (SELECT 1 FROM Usuarios WHERE Email = 'morroazul@xepa.test')
    INSERT INTO Usuarios (Nome, Email, SenhaHash, Tipo, Bloqueado, CriadoEm) VALUES (N'Panificadora Morro Azul', 'morroazul@xepa.test', @hash, 'Estabelecimento', 0, @agora);
SET @u = (SELECT Id FROM Usuarios WHERE Email = 'morroazul@xepa.test');
IF NOT EXISTS (SELECT 1 FROM Estabelecimentos WHERE UsuarioId = @u)
    INSERT INTO Estabelecimentos (UsuarioId, Nome, Categoria, LogoUrl, Cep, Logradouro, Numero, Bairro, Cidade, Uf, Latitude, Longitude, StatusCadastro, Ativo, CriadoEm)
    VALUES (@u, N'Panificadora Morro Azul', 'Padaria', 'https://images.unsplash.com/photo-1586444248902-2f64eddc13df?w=160&q=75&auto=format&fit=crop', '13480000', N'Rua Senador Vergueiro', '1200', N'Centro', N'Limeira', 'SP', -22.5678579, -47.4068539, 'Aprovado', 1, @agora);
SET @e = (SELECT Id FROM Estabelecimentos WHERE UsuarioId = @u);
UPDATE Ofertas SET Ativa = 0, AtualizadoEm = @agora WHERE EstabelecimentoId = @e AND Ativa = 1;
INSERT INTO Ofertas (EstabelecimentoId, Tipo, Titulo, Descricao, FotoUrl, PrecoOriginal, Preco, QuantidadeDisponivel, PesoEstimadoKg, RetiradaInicio, RetiradaFim, Ativa, CriadoEm) VALUES (@e, 'SacolaSurpresa', N'Sacola surpresa', N'Pães artesanais e de fermentação natural do dia.', 'https://images.unsplash.com/photo-1586444248902-2f64eddc13df?w=800&q=75&auto=format&fit=crop', 34.00, 12.90, 3, 1.5, @inicio, @fim, 1, @agora);

-- Doceria Vila Claudia
IF NOT EXISTS (SELECT 1 FROM Usuarios WHERE Email = 'vilaclaudia@xepa.test')
    INSERT INTO Usuarios (Nome, Email, SenhaHash, Tipo, Bloqueado, CriadoEm) VALUES (N'Doceria Vila Claudia', 'vilaclaudia@xepa.test', @hash, 'Estabelecimento', 0, @agora);
SET @u = (SELECT Id FROM Usuarios WHERE Email = 'vilaclaudia@xepa.test');
IF NOT EXISTS (SELECT 1 FROM Estabelecimentos WHERE UsuarioId = @u)
    INSERT INTO Estabelecimentos (UsuarioId, Nome, Categoria, LogoUrl, Cep, Logradouro, Numero, Bairro, Cidade, Uf, Latitude, Longitude, StatusCadastro, Ativo, CriadoEm)
    VALUES (@u, N'Doceria Vila Claudia', 'Padaria', 'https://images.unsplash.com/photo-1550617931-e17a7b70dce2?w=160&q=75&auto=format&fit=crop', '13480000', N'Avenida Campinas', '900', N'Vila Claudia', N'Limeira', 'SP', -22.5755219, -47.3932229, 'Aprovado', 1, @agora);
SET @e = (SELECT Id FROM Estabelecimentos WHERE UsuarioId = @u);
UPDATE Ofertas SET Ativa = 0, AtualizadoEm = @agora WHERE EstabelecimentoId = @e AND Ativa = 1;
INSERT INTO Ofertas (EstabelecimentoId, Tipo, Titulo, Descricao, FotoUrl, PrecoOriginal, Preco, QuantidadeDisponivel, PesoEstimadoKg, RetiradaInicio, RetiradaFim, Ativa, CriadoEm) VALUES (@e, 'SacolaSurpresa', N'Caixa de doces', N'Cupcakes, fatias de bolo e doces finos que não saíram hoje.', 'https://images.unsplash.com/photo-1565958011703-44f9829ba187?w=800&q=75&auto=format&fit=crop', 45.00, 16.90, 3, 0.8, @inicio, @fim, 1, @agora);
INSERT INTO Ofertas (EstabelecimentoId, Tipo, Titulo, Descricao, FotoUrl, PrecoOriginal, Preco, QuantidadeDisponivel, PesoEstimadoKg, RetiradaInicio, RetiradaFim, Ativa, CriadoEm) VALUES (@e, 'Prato', N'Bolo inteiro do dia', N'Bolo de festa de 1 kg feito hoje (sabor varia).', 'https://images.unsplash.com/photo-1550617931-e17a7b70dce2?w=800&q=75&auto=format&fit=crop', 70.00, 24.90, 1, 1.0, @inicio, @fim, 1, @agora);

-- Cantina Bella Limeira
IF NOT EXISTS (SELECT 1 FROM Usuarios WHERE Email = 'bellalimeira@xepa.test')
    INSERT INTO Usuarios (Nome, Email, SenhaHash, Tipo, Bloqueado, CriadoEm) VALUES (N'Cantina Bella Limeira', 'bellalimeira@xepa.test', @hash, 'Estabelecimento', 0, @agora);
SET @u = (SELECT Id FROM Usuarios WHERE Email = 'bellalimeira@xepa.test');
IF NOT EXISTS (SELECT 1 FROM Estabelecimentos WHERE UsuarioId = @u)
    INSERT INTO Estabelecimentos (UsuarioId, Nome, Categoria, LogoUrl, Cep, Logradouro, Numero, Bairro, Cidade, Uf, Latitude, Longitude, StatusCadastro, Ativo, CriadoEm)
    VALUES (@u, N'Cantina Bella Limeira', 'Restaurante', 'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=160&q=75&auto=format&fit=crop', '13480000', N'Rua Santa Cruz', '700', N'Centro', N'Limeira', 'SP', -22.5634859, -47.4035536, 'Aprovado', 1, @agora);
SET @e = (SELECT Id FROM Estabelecimentos WHERE UsuarioId = @u);
UPDATE Ofertas SET Ativa = 0, AtualizadoEm = @agora WHERE EstabelecimentoId = @e AND Ativa = 1;
INSERT INTO Ofertas (EstabelecimentoId, Tipo, Titulo, Descricao, FotoUrl, PrecoOriginal, Preco, QuantidadeDisponivel, PesoEstimadoKg, RetiradaInicio, RetiradaFim, Ativa, CriadoEm) VALUES (@e, 'Prato', N'Massa do almoço', N'Porção de massa com molho do dia, embalada para viagem.', 'https://images.unsplash.com/photo-1621996346565-e3dbc646d9a9?w=800&q=75&auto=format&fit=crop', 42.00, 15.90, 5, 0.6, @inicio, @fim, 1, @agora);
INSERT INTO Ofertas (EstabelecimentoId, Tipo, Titulo, Descricao, FotoUrl, PrecoOriginal, Preco, QuantidadeDisponivel, PesoEstimadoKg, RetiradaInicio, RetiradaFim, Ativa, CriadoEm) VALUES (@e, 'SacolaSurpresa', N'Pizza de fim de noite', N'Pizzas inteiras ou meias que sobraram do rodízio.', 'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=800&q=75&auto=format&fit=crop', 60.00, 19.90, 2, 1.0, @inicio, @fim, 1, @agora);

-- Sabor Caipira
IF NOT EXISTS (SELECT 1 FROM Usuarios WHERE Email = 'saborcaipira@xepa.test')
    INSERT INTO Usuarios (Nome, Email, SenhaHash, Tipo, Bloqueado, CriadoEm) VALUES (N'Sabor Caipira', 'saborcaipira@xepa.test', @hash, 'Estabelecimento', 0, @agora);
SET @u = (SELECT Id FROM Usuarios WHERE Email = 'saborcaipira@xepa.test');
IF NOT EXISTS (SELECT 1 FROM Estabelecimentos WHERE UsuarioId = @u)
    INSERT INTO Estabelecimentos (UsuarioId, Nome, Categoria, LogoUrl, Cep, Logradouro, Numero, Bairro, Cidade, Uf, Latitude, Longitude, StatusCadastro, Ativo, CriadoEm)
    VALUES (@u, N'Sabor Caipira', 'Restaurante', 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=160&q=75&auto=format&fit=crop', '13486', N'Avenida Major José Levy Sobrinho', '1500', N'Vila Cidade Jardim', N'Limeira', 'SP', -22.5576837, -47.3853978, 'Aprovado', 1, @agora);
SET @e = (SELECT Id FROM Estabelecimentos WHERE UsuarioId = @u);
UPDATE Ofertas SET Ativa = 0, AtualizadoEm = @agora WHERE EstabelecimentoId = @e AND Ativa = 1;
INSERT INTO Ofertas (EstabelecimentoId, Tipo, Titulo, Descricao, FotoUrl, PrecoOriginal, Preco, QuantidadeDisponivel, PesoEstimadoKg, RetiradaInicio, RetiradaFim, Ativa, CriadoEm) VALUES (@e, 'Prato', N'Marmita caseira', N'Arroz, feijão, mistura e salada do almoço.', 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=800&q=75&auto=format&fit=crop', 28.00, 11.90, 6, 0.7, @inicio, @fim, 1, @agora);

-- Sushi do Cascalho
IF NOT EXISTS (SELECT 1 FROM Usuarios WHERE Email = 'sushicascalho@xepa.test')
    INSERT INTO Usuarios (Nome, Email, SenhaHash, Tipo, Bloqueado, CriadoEm) VALUES (N'Sushi do Cascalho', 'sushicascalho@xepa.test', @hash, 'Estabelecimento', 0, @agora);
SET @u = (SELECT Id FROM Usuarios WHERE Email = 'sushicascalho@xepa.test');
IF NOT EXISTS (SELECT 1 FROM Estabelecimentos WHERE UsuarioId = @u)
    INSERT INTO Estabelecimentos (UsuarioId, Nome, Categoria, LogoUrl, Cep, Logradouro, Numero, Bairro, Cidade, Uf, Latitude, Longitude, StatusCadastro, Ativo, CriadoEm)
    VALUES (@u, N'Sushi do Cascalho', 'Restaurante', 'https://images.unsplash.com/photo-1579584425555-c3ce17fd4351?w=160&q=75&auto=format&fit=crop', '13480000', N'Rua Barão de Cascalho', '1100', N'Centro', N'Limeira', 'SP', -22.5626569, -47.3996758, 'Aprovado', 1, @agora);
SET @e = (SELECT Id FROM Estabelecimentos WHERE UsuarioId = @u);
UPDATE Ofertas SET Ativa = 0, AtualizadoEm = @agora WHERE EstabelecimentoId = @e AND Ativa = 1;
INSERT INTO Ofertas (EstabelecimentoId, Tipo, Titulo, Descricao, FotoUrl, PrecoOriginal, Preco, QuantidadeDisponivel, PesoEstimadoKg, RetiradaInicio, RetiradaFim, Ativa, CriadoEm) VALUES (@e, 'SacolaSurpresa', N'Combinado surpresa', N'20 peças de sushi e hot roll do dia.', 'https://images.unsplash.com/photo-1579584425555-c3ce17fd4351?w=800&q=75&auto=format&fit=crop', 75.00, 29.90, 2, 0.6, @inicio, @fim, 1, @agora);

-- Verde Leve Saladas
IF NOT EXISTS (SELECT 1 FROM Usuarios WHERE Email = 'verdeleve@xepa.test')
    INSERT INTO Usuarios (Nome, Email, SenhaHash, Tipo, Bloqueado, CriadoEm) VALUES (N'Verde Leve Saladas', 'verdeleve@xepa.test', @hash, 'Estabelecimento', 0, @agora);
SET @u = (SELECT Id FROM Usuarios WHERE Email = 'verdeleve@xepa.test');
IF NOT EXISTS (SELECT 1 FROM Estabelecimentos WHERE UsuarioId = @u)
    INSERT INTO Estabelecimentos (UsuarioId, Nome, Categoria, LogoUrl, Cep, Logradouro, Numero, Bairro, Cidade, Uf, Latitude, Longitude, StatusCadastro, Ativo, CriadoEm)
    VALUES (@u, N'Verde Leve Saladas', 'Restaurante', 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=160&q=75&auto=format&fit=crop', '13482', N'Avenida Comendador Agostinho Prada', '2000', N'Jardim Nossa Senhora de Fátima', N'Limeira', 'SP', -22.5731409, -47.4127469, 'Aprovado', 1, @agora);
SET @e = (SELECT Id FROM Estabelecimentos WHERE UsuarioId = @u);
UPDATE Ofertas SET Ativa = 0, AtualizadoEm = @agora WHERE EstabelecimentoId = @e AND Ativa = 1;
INSERT INTO Ofertas (EstabelecimentoId, Tipo, Titulo, Descricao, FotoUrl, PrecoOriginal, Preco, QuantidadeDisponivel, PesoEstimadoKg, RetiradaInicio, RetiradaFim, Ativa, CriadoEm) VALUES (@e, 'Prato', N'Bowl do dia', N'Bowl com grãos, legumes e proteína, montado hoje.', 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=800&q=75&auto=format&fit=crop', 36.00, 13.90, 4, 0.5, @inicio, @fim, 1, @agora);
INSERT INTO Ofertas (EstabelecimentoId, Tipo, Titulo, Descricao, FotoUrl, PrecoOriginal, Preco, QuantidadeDisponivel, PesoEstimadoKg, RetiradaInicio, RetiradaFim, Ativa, CriadoEm) VALUES (@e, 'Prato', N'Salada completa', N'Salada grande com molho à parte.', 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=800&q=75&auto=format&fit=crop', 30.00, 10.90, 3, 0.4, @inicio, @fim, 1, @agora);

-- Mercado Bom Jardim
IF NOT EXISTS (SELECT 1 FROM Usuarios WHERE Email = 'bomjardim@xepa.test')
    INSERT INTO Usuarios (Nome, Email, SenhaHash, Tipo, Bloqueado, CriadoEm) VALUES (N'Mercado Bom Jardim', 'bomjardim@xepa.test', @hash, 'Estabelecimento', 0, @agora);
SET @u = (SELECT Id FROM Usuarios WHERE Email = 'bomjardim@xepa.test');
IF NOT EXISTS (SELECT 1 FROM Estabelecimentos WHERE UsuarioId = @u)
    INSERT INTO Estabelecimentos (UsuarioId, Nome, Categoria, LogoUrl, Cep, Logradouro, Numero, Bairro, Cidade, Uf, Latitude, Longitude, StatusCadastro, Ativo, CriadoEm)
    VALUES (@u, N'Mercado Bom Jardim', 'Mercado', 'https://images.unsplash.com/photo-1534723452862-4c874018d66d?w=160&q=75&auto=format&fit=crop', '13480000', N'Rua Carlos Gomes', '800', N'Centro', N'Limeira', 'SP', -22.5671255, -47.4046319, 'Aprovado', 1, @agora);
SET @e = (SELECT Id FROM Estabelecimentos WHERE UsuarioId = @u);
UPDATE Ofertas SET Ativa = 0, AtualizadoEm = @agora WHERE EstabelecimentoId = @e AND Ativa = 1;
INSERT INTO Ofertas (EstabelecimentoId, Tipo, Titulo, Descricao, FotoUrl, PrecoOriginal, Preco, QuantidadeDisponivel, PesoEstimadoKg, RetiradaInicio, RetiradaFim, Ativa, CriadoEm) VALUES (@e, 'SacolaSurpresa', N'Kit despensa', N'Laticínios, frios e itens perto da validade, todos dentro do prazo.', 'https://images.unsplash.com/photo-1534723452862-4c874018d66d?w=800&q=75&auto=format&fit=crop', 55.00, 21.90, 3, 2.5, @inicio, @fim, 1, @agora);

-- Empório Toledo
IF NOT EXISTS (SELECT 1 FROM Usuarios WHERE Email = 'emporiotoledo@xepa.test')
    INSERT INTO Usuarios (Nome, Email, SenhaHash, Tipo, Bloqueado, CriadoEm) VALUES (N'Empório Toledo', 'emporiotoledo@xepa.test', @hash, 'Estabelecimento', 0, @agora);
SET @u = (SELECT Id FROM Usuarios WHERE Email = 'emporiotoledo@xepa.test');
IF NOT EXISTS (SELECT 1 FROM Estabelecimentos WHERE UsuarioId = @u)
    INSERT INTO Estabelecimentos (UsuarioId, Nome, Categoria, LogoUrl, Cep, Logradouro, Numero, Bairro, Cidade, Uf, Latitude, Longitude, StatusCadastro, Ativo, CriadoEm)
    VALUES (@u, N'Empório Toledo', 'Mercado', 'https://images.unsplash.com/photo-1606787366850-de6330128bfc?w=160&q=75&auto=format&fit=crop', '13480000', N'Rua Tiradentes', '600', N'Centro', N'Limeira', 'SP', -22.5665979, -47.4027219, 'Aprovado', 1, @agora);
SET @e = (SELECT Id FROM Estabelecimentos WHERE UsuarioId = @u);
UPDATE Ofertas SET Ativa = 0, AtualizadoEm = @agora WHERE EstabelecimentoId = @e AND Ativa = 1;
INSERT INTO Ofertas (EstabelecimentoId, Tipo, Titulo, Descricao, FotoUrl, PrecoOriginal, Preco, QuantidadeDisponivel, PesoEstimadoKg, RetiradaInicio, RetiradaFim, Ativa, CriadoEm) VALUES (@e, 'SacolaSurpresa', N'Cesta do empório', N'Queijos, embutidos e pães especiais da semana.', 'https://images.unsplash.com/photo-1606787366850-de6330128bfc?w=800&q=75&auto=format&fit=crop', 80.00, 29.90, 2, 1.8, @inicio, @fim, 1, @agora);

-- Quitanda da Boa Morte
IF NOT EXISTS (SELECT 1 FROM Usuarios WHERE Email = 'quitanda@xepa.test')
    INSERT INTO Usuarios (Nome, Email, SenhaHash, Tipo, Bloqueado, CriadoEm) VALUES (N'Quitanda da Boa Morte', 'quitanda@xepa.test', @hash, 'Estabelecimento', 0, @agora);
SET @u = (SELECT Id FROM Usuarios WHERE Email = 'quitanda@xepa.test');
IF NOT EXISTS (SELECT 1 FROM Estabelecimentos WHERE UsuarioId = @u)
    INSERT INTO Estabelecimentos (UsuarioId, Nome, Categoria, LogoUrl, Cep, Logradouro, Numero, Bairro, Cidade, Uf, Latitude, Longitude, StatusCadastro, Ativo, CriadoEm)
    VALUES (@u, N'Quitanda da Boa Morte', 'Feira', 'https://images.unsplash.com/photo-1610832958506-aa56368176cf?w=160&q=75&auto=format&fit=crop', '13480000', N'Rua Boa Morte', '900', N'Centro', N'Limeira', 'SP', -22.5624129, -47.405227, 'Aprovado', 1, @agora);
SET @e = (SELECT Id FROM Estabelecimentos WHERE UsuarioId = @u);
UPDATE Ofertas SET Ativa = 0, AtualizadoEm = @agora WHERE EstabelecimentoId = @e AND Ativa = 1;
INSERT INTO Ofertas (EstabelecimentoId, Tipo, Titulo, Descricao, FotoUrl, PrecoOriginal, Preco, QuantidadeDisponivel, PesoEstimadoKg, RetiradaInicio, RetiradaFim, Ativa, CriadoEm) VALUES (@e, 'SacolaSurpresa', N'Caixa de frutas', N'Frutas maduras e boas para consumo hoje ou para doces e sucos.', 'https://images.unsplash.com/photo-1610832958506-aa56368176cf?w=800&q=75&auto=format&fit=crop', 32.00, 9.90, 5, 3.5, @inicio, @fim, 1, @agora);
INSERT INTO Ofertas (EstabelecimentoId, Tipo, Titulo, Descricao, FotoUrl, PrecoOriginal, Preco, QuantidadeDisponivel, PesoEstimadoKg, RetiradaInicio, RetiradaFim, Ativa, CriadoEm) VALUES (@e, 'SacolaSurpresa', N'Kit legumes e verduras', N'Legumes e folhas da xepa do dia.', 'https://images.unsplash.com/photo-1540420773420-3366772f4999?w=800&q=75&auto=format&fit=crop', 26.00, 8.90, 4, 3.0, @inicio, @fim, 1, @agora);

-- Barraca Feira da Praça
IF NOT EXISTS (SELECT 1 FROM Usuarios WHERE Email = 'feiradapraca@xepa.test')
    INSERT INTO Usuarios (Nome, Email, SenhaHash, Tipo, Bloqueado, CriadoEm) VALUES (N'Barraca Feira da Praça', 'feiradapraca@xepa.test', @hash, 'Estabelecimento', 0, @agora);
SET @u = (SELECT Id FROM Usuarios WHERE Email = 'feiradapraca@xepa.test');
IF NOT EXISTS (SELECT 1 FROM Estabelecimentos WHERE UsuarioId = @u)
    INSERT INTO Estabelecimentos (UsuarioId, Nome, Categoria, LogoUrl, Cep, Logradouro, Numero, Bairro, Cidade, Uf, Latitude, Longitude, StatusCadastro, Ativo, CriadoEm)
    VALUES (@u, N'Barraca Feira da Praça', 'Feira', 'https://images.unsplash.com/photo-1488459716781-31db52582fe9?w=160&q=75&auto=format&fit=crop', '13480000', N'Rua Doutor Trajano de Barros Camargo', '500', N'Centro', N'Limeira', 'SP', -22.5647028, -47.4001857, 'Aprovado', 1, @agora);
SET @e = (SELECT Id FROM Estabelecimentos WHERE UsuarioId = @u);
UPDATE Ofertas SET Ativa = 0, AtualizadoEm = @agora WHERE EstabelecimentoId = @e AND Ativa = 1;
INSERT INTO Ofertas (EstabelecimentoId, Tipo, Titulo, Descricao, FotoUrl, PrecoOriginal, Preco, QuantidadeDisponivel, PesoEstimadoKg, RetiradaInicio, RetiradaFim, Ativa, CriadoEm) VALUES (@e, 'SacolaSurpresa', N'Xepa da feira', N'Mix de frutas, verduras e legumes no fim da feira.', 'https://images.unsplash.com/photo-1488459716781-31db52582fe9?w=800&q=75&auto=format&fit=crop', 30.00, 9.90, 6, 4.0, @inicio, @fim, 1, @agora);

-- Doces da Casa
IF NOT EXISTS (SELECT 1 FROM Usuarios WHERE Email = 'docesdacasa@xepa.test')
    INSERT INTO Usuarios (Nome, Email, SenhaHash, Tipo, Bloqueado, CriadoEm) VALUES (N'Doces da Casa', 'docesdacasa@xepa.test', @hash, 'Estabelecimento', 0, @agora);
SET @u = (SELECT Id FROM Usuarios WHERE Email = 'docesdacasa@xepa.test');
IF NOT EXISTS (SELECT 1 FROM Estabelecimentos WHERE UsuarioId = @u)
    INSERT INTO Estabelecimentos (UsuarioId, Nome, Categoria, LogoUrl, Cep, Logradouro, Numero, Bairro, Cidade, Uf, Latitude, Longitude, StatusCadastro, Ativo, CriadoEm)
    VALUES (@u, N'Doces da Casa', 'Padaria', 'https://images.unsplash.com/photo-1563805042-7684c019e1cb?w=160&q=75&auto=format&fit=crop', '13480000', N'Rua Alferes Franco', '300', N'Centro', N'Limeira', 'SP', -22.5608334, -47.4015994, 'Aprovado', 1, @agora);
SET @e = (SELECT Id FROM Estabelecimentos WHERE UsuarioId = @u);
UPDATE Ofertas SET Ativa = 0, AtualizadoEm = @agora WHERE EstabelecimentoId = @e AND Ativa = 1;
INSERT INTO Ofertas (EstabelecimentoId, Tipo, Titulo, Descricao, FotoUrl, PrecoOriginal, Preco, QuantidadeDisponivel, PesoEstimadoKg, RetiradaInicio, RetiradaFim, Ativa, CriadoEm) VALUES (@e, 'SacolaSurpresa', N'Sobremesas do dia', N'Copos de sobremesa e mousses feitos hoje.', 'https://images.unsplash.com/photo-1563805042-7684c019e1cb?w=800&q=75&auto=format&fit=crop', 40.00, 14.90, 3, 0.8, @inicio, @fim, 1, @agora);

-- Endereço de entrega do cliente demo em Limeira (passa a ser o principal).
SET @u = (SELECT Id FROM Usuarios WHERE Email = 'cliente@xepa.test');
UPDATE Enderecos SET Principal = 0 WHERE UsuarioId = @u AND Cidade <> N'Limeira';
IF EXISTS (SELECT 1 FROM Enderecos WHERE UsuarioId = @u AND Cidade = N'Limeira')
    UPDATE Enderecos SET Principal = 1, Cep = '13484', Logradouro = N'Rua Pedro Zaccaria', Numero = '300', Bairro = N'Jardim São Paulo',
        Latitude = -22.557638, Longitude = -47.427199, AtualizadoEm = @agora WHERE UsuarioId = @u AND Cidade = N'Limeira';
ELSE
    INSERT INTO Enderecos (UsuarioId, Apelido, Principal, Cep, Logradouro, Numero, Bairro, Cidade, Uf, Latitude, Longitude, CriadoEm)
    VALUES (@u, N'Casa em Limeira', 1, '13484', N'Rua Pedro Zaccaria', '300', N'Jardim São Paulo', N'Limeira', 'SP', -22.557638, -47.427199, @agora);

COMMIT;
SELECT e.Nome, e.Bairro, COUNT(o.Id) AS OfertasHoje FROM Estabelecimentos e LEFT JOIN Ofertas o ON o.EstabelecimentoId = e.Id AND o.Ativa = 1 AND o.RetiradaFim > @agora
WHERE e.Cidade = N'Limeira' GROUP BY e.Nome, e.Bairro ORDER BY e.Nome;
