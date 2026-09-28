-- Seed dos 8 indicadores (alinhados à Torre de Controle) — rodar após schemas.sql
insert into indicadores (chave, nome, ordem, sentido, descricao) values
 ('faturamento',  'Faturamento',       1, 'maior_melhor','Faturamento bruto da unidade no mês.'),
 ('recompra',     'Recompra',          2, 'maior_melhor','Faturamento vindo de pacientes da base (reaval/retorno/acréscimo/resgate).'),
 ('entrada',      'Entrada',           3, 'maior_melhor','Entrada de caixa das vendas (negociação/fechamento; entrada como pré-requisito).'),
 ('avaliacoes',   'Avaliações',        4, 'maior_melhor','Quantidade de avaliações realizadas no mês.'),
 ('conversao',    'Conversão',         5, 'maior_melhor','Dos que compareceram, quantos fecharam.'),
 ('ticket',       'Ticket médio',      6, 'maior_melhor','Valor médio por avaliação fechada.'),
 ('resgate30',    'Resgate 30+',       7, 'maior_melhor','Vendas resgatadas de pacientes com 30+ dias (Vlr 30+).'),
 ('parcelamento', 'Parcelamento médio',8, 'teto',        'Parcelamento médio ponderado. É um LIMITE (teto): quanto menor, melhor; abaixo do número = dentro/OK — não é meta a bater.')
on conflict (chave) do update set nome=excluded.nome, ordem=excluded.ordem, sentido=excluded.sentido, descricao=excluded.descricao;

-- Remove o indicador antigo 'vendas' (fundido em Entrada/Conversão), se existir
delete from indicadores where chave='vendas';
