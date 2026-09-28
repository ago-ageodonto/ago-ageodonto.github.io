-- ============================================================
-- SETUP COMPLETO — Plataforma de Gestão Comercial
-- Cole TUDO isto no SQL Editor do Supabase e clique em Run.
-- (junta schemas + indicadores + demandas + exemplo + policies)
-- ============================================================

-- ============================================================
-- Plataforma de Gestão Comercial para Diretores Clínicos
-- Schema Supabase (Postgres)  —  rodar 1º (antes dos seeds)
-- ============================================================
-- Ordem de execução: schemas.sql -> seed_indicadores.sql
--                    -> seed_demandas.sql -> seed_exemplo.sql

create extension if not exists "pgcrypto";  -- gen_random_uuid()

-- ---------- ENUMS ----------
do $$ begin
  create type status_checagem as enum ('feito','parcial','nao');
exception when duplicate_object then null; end $$;

do $$ begin
  create type status_reuniao as enum ('rascunho','concluida');
exception when duplicate_object then null; end $$;

-- ---------- CLÍNICAS ----------
create table if not exists clinicas (
  id          uuid primary key default gen_random_uuid(),
  nome        text not null,
  praca       text,
  uf          text,
  ativo       boolean not null default true,
  criado_em   timestamptz not null default now()
);

-- ---------- DIRETORES CLÍNICOS (sócios) ----------
create table if not exists diretores (
  id          uuid primary key default gen_random_uuid(),
  nome        text not null,
  clinica_id  uuid references clinicas(id) on delete set null,
  email       text,
  ativo       boolean not null default true,
  criado_em   timestamptz not null default now()
);

-- ---------- INDICADORES (os 8) ----------
create table if not exists indicadores (
  id          uuid primary key default gen_random_uuid(),
  chave       text not null unique,          -- faturamento, recompra, entrada, avaliacoes, conversao, ticket, resgate30, parcelamento
  nome        text not null,
  ordem       int  not null default 0,
  sentido     text not null default 'maior_melhor',  -- 'maior_melhor' (bate se >= meta) | 'teto' (bom se <= limite; ex.: parcelamento)
  descricao   text
);

-- ---------- DEMANDAS (~5 por indicador) ----------
create table if not exists demandas (
  id            uuid primary key default gen_random_uuid(),
  indicador_id  uuid not null references indicadores(id) on delete cascade,
  ordem         int  not null default 0,
  titulo        text not null,
  descricao     text,
  peso          numeric not null default 1,  -- para ponderar aderência
  ativo         boolean not null default true
);

-- ---------- REUNIÕES (pauta gravada por diretor) ----------
create table if not exists reunioes (
  id          uuid primary key default gen_random_uuid(),
  diretor_id  uuid not null references diretores(id) on delete cascade,
  data        date not null default current_date,
  video_url   text,
  status      status_reuniao not null default 'rascunho',
  resumo      text,
  criado_por  text,                          -- ex.: 'Gregori'
  criado_em   timestamptz not null default now()
);

-- ---------- CHECAGENS (reunião x demanda -> feito/parcial/nao) ----------
create table if not exists checagens (
  id          uuid primary key default gen_random_uuid(),
  reuniao_id  uuid not null references reunioes(id) on delete cascade,
  demanda_id  uuid not null references demandas(id) on delete cascade,
  status      status_checagem not null default 'nao',
  nota        text,
  unique (reuniao_id, demanda_id)
);

-- ---------- RESULTADOS (indicador x diretor x competência; fonte: Torre/Giga) ----------
create table if not exists resultados (
  id            uuid primary key default gen_random_uuid(),
  diretor_id    uuid not null references diretores(id) on delete cascade,
  indicador_id  uuid not null references indicadores(id) on delete cascade,
  competencia   text not null,               -- 'YYYY-MM'
  meta          numeric,        -- para 'teto' (parcelamento) = o LIMITE que não pode passar
  realizado     numeric,
  projecao      numeric,
  atualizado_em timestamptz not null default now(),
  unique (diretor_id, indicador_id, competencia)
);

-- ---------- ÍNDICES ----------
create index if not exists idx_demandas_indicador on demandas(indicador_id);
create index if not exists idx_checagens_reuniao  on checagens(reuniao_id);
create index if not exists idx_reunioes_diretor    on reunioes(diretor_id);
create index if not exists idx_resultados_diretor  on resultados(diretor_id, competencia);

-- ============================================================
-- VIEWS (dashboard e cruzamentos)
-- ============================================================

-- Aderência por indicador na ÚLTIMA reunião concluída de cada diretor
create or replace view v_aderencia_indicador as
with ult as (
  select distinct on (diretor_id) id as reuniao_id, diretor_id, data
  from reunioes where status = 'concluida'
  order by diretor_id, data desc
)
select
  u.diretor_id,
  u.reuniao_id,
  u.data as data_reuniao,
  d.indicador_id,
  count(*)                                              as total_demandas,
  count(*) filter (where c.status = 'feito')            as feitas,
  count(*) filter (where c.status = 'parcial')          as parciais,
  count(*) filter (where c.status = 'nao')              as nao_feitas,
  round( sum(case c.status when 'feito' then d.peso when 'parcial' then d.peso*0.5 else 0 end)
         / nullif(sum(d.peso),0) * 100, 0)              as aderencia_pct
from ult u
join checagens c on c.reuniao_id = u.reuniao_id
join demandas  d on d.id = c.demanda_id
group by u.diretor_id, u.reuniao_id, u.data, d.indicador_id;

-- Dashboard do diretor: aderência x resultado do indicador (cruzamento "não fez x não bateu")
create or replace view v_dashboard_diretor as
select
  di.id                as diretor_id,
  di.nome              as diretor,
  cl.nome              as clinica,
  ind.chave            as indicador_chave,
  ind.nome             as indicador,
  ind.ordem            as indicador_ordem,
  a.aderencia_pct,
  a.total_demandas,
  a.feitas,
  a.nao_feitas,
  ind.sentido,
  r.competencia,
  r.meta,
  r.realizado,
  r.projecao,
  (case when r.meta is null or r.realizado is null then null
        when ind.sentido = 'teto' then r.realizado <= r.meta
        else r.realizado >= r.meta end)                as atingiu,
  case
    when (case when ind.sentido='teto' then r.realizado <= r.meta else r.realizado >= r.meta end) is false
         and coalesce(a.aderencia_pct,0) < 60 then 'nao_fez_nao_bateu'
    when (case when ind.sentido='teto' then r.realizado <= r.meta else r.realizado >= r.meta end) is true
         and coalesce(a.aderencia_pct,0) >= 60 then 'fez_bateu'
    else 'ok'
  end                  as leitura
from diretores di
join clinicas   cl  on cl.id = di.clinica_id
cross join indicadores ind
left join v_aderencia_indicador a
       on a.diretor_id = di.id and a.indicador_id = ind.id
left join lateral (
  select * from resultados r2
  where r2.diretor_id = di.id and r2.indicador_id = ind.id
  order by r2.competencia desc limit 1
) r on true
order by di.nome, ind.ordem;

-- ============================================================
-- RLS (Row Level Security) — habilitar; políticas conforme auth do Supabase
-- ============================================================
alter table clinicas    enable row level security;
alter table diretores   enable row level security;
alter table indicadores enable row level security;
alter table demandas    enable row level security;
alter table reunioes    enable row level security;
alter table checagens   enable row level security;
alter table resultados  enable row level security;

-- Política mínima (ajustar quando definir papéis/auth):
-- Leitura liberada para usuários autenticados; escrita idem (refinar por papel depois).
do $$
declare t text;
begin
  foreach t in array array['clinicas','diretores','indicadores','demandas','reunioes','checagens','resultados']
  loop
    execute format('drop policy if exists p_auth_all on %I', t);
    execute format('create policy p_auth_all on %I for all to authenticated using (true) with check (true)', t);
  end loop;
end $$;

-- ===== SEED INDICADORES =====
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

-- ===== SEED DEMANDAS =====
-- ============================================================
-- Seed das DEMANDAS por indicador (CONSOLIDADO/AGRUPADO)
-- Rodar após seed_indicadores.sql. 🔒 na descrição = requer CRM/ferramenta.
-- ============================================================
truncate table checagens;
delete from demandas;

with ins(chave, ordem, titulo, descricao, peso) as (values
 -- FATURAMENTO (5)
 ('faturamento',1,'Agenda cheia dos avaliadores','Não deixar cadeira ociosa; bloqueios e horários preenchidos.',1),
 ('faturamento',2,'Leitura diária do realizado × projeção','Acompanhar no Giga e reagir quando furar a meta.',1),
 ('faturamento',3,'Recuperar orçamentos de alto ticket não fechados','Follow-up semanal dos grandes orçamentos abertos.',1),
 ('faturamento',4,'Mix de tratamentos (além do implante)','Prótese, orto, faceta, clínico geral.',1),
 ('faturamento',5,'Plano de recuperação quando furar a meta','Campanha/mutirão/resgate quando a projeção cair.',1),
 -- RECOMPRA (6)
 ('recompra',1,'Rotina de resgate da base','Trabalhar diariamente a lista de resgate.',1),
 ('recompra',2,'Reavaliação e retorno agendados','Tratamentos em andamento voltam para nova venda.',1),
 ('recompra',3,'Trabalhar as altas → indicações','Todo paciente de alta vira porta de indicação.',1),
 ('recompra',4,'Campanha e disparos para a base ativa','Reativação + disparos (ex.: higienização de protocolo). 🔒 (requer CRM)',1),
 ('recompra',5,'Alinhamento com os dentistas p/ essas vendas','Dentistas engajados para realizar as vendas da base.',1),
 ('recompra',6,'Monitorar % de recompra × meta','Acompanhar o indicador e corrigir rota.',1),
 -- ENTRADA (6)
 ('entrada',1,'Entrada como pré-requisito da venda','A entrada é condição pra fechar — padronizado.',1),
 ('entrada',2,'Qualidade da negociação e credibilidade','Como está a negociação e a credibilidade que o dentista passa.',1),
 ('entrada',3,'Usar a Ovix Pro (gravação)','Gravar a venda pra avaliar a abordagem. (ferramenta Ovix Pro)',1),
 ('entrada',4,'Confirmação ativa (áudio/vídeo) dos fechados','Reduzir arrependimento/cancelamento com confirmação individual.',1),
 ('entrada',5,'Garantir a entrada efetivada','Acompanhar a efetivação da entrada da venda.',1),
 ('entrada',6,'Monitorar entrada × meta','Acompanhar o indicador de entrada.',1),
 -- AVALIAÇÕES (6 — agrupado)
 ('avaliacoes',1,'Funil e agenda de avaliação','Volume de leads + capacidade + reduzir no-show + agenda dedicada (não usar p/ atendimento).',1),
 ('avaliacoes',2,'Engajamento nas redes (Insta/Face)','Responder comentários e interagir com quem curtiu as publicações. 🔒 (requer CRM/social)',1),
 ('avaliacoes',3,'Entregar os vídeos solicitados','Vídeos de marketing e de captação pedidos.',1),
 ('avaliacoes',4,'Presença ativa','Presença na clínica, rádio no horário, reuniões de marketing/SDR e eventos de comunidade.',1),
 ('avaliacoes',5,'Indicações dos funcionários','Avaliações trazidas por indicação dos funcionários (há bonificação).',1),
 ('avaliacoes',6,'Monitorar nº de avaliações × meta','Acompanhar o indicador diariamente.',1),
 -- CONVERSÃO (7 — agrupado)
 ('conversao',1,'Confirmação ativa das avaliações','Reduzir no-show garantindo comparecimento.',1),
 ('conversao',2,'Padrão de atendimento e tour na recepção','Experiência consistente antes da avaliação.',1),
 ('conversao',3,'Follow-up dos não-fechados','Trabalhar quem avaliou e não fechou.',1),
 ('conversao',4,'Fechamento (treino + no ato)','Treinar fechamento e estimular a decisão na hora, com a proposta pronta.',1),
 ('conversao',5,'Storytelling na venda','Usar storytelling na apresentação da venda.',1),
 ('conversao',6,'Passagem para o relacionamento','Paciente vai direto à sala do relacionamento e o contexto da venda é alinhado antes de chamá-lo.',1),
 ('conversao',7,'Monitorar conversão por avaliador × meta','Acompanhar e corrigir por pessoa.',1),
 -- TICKET MÉDIO (6 — agrupado)
 ('ticket',1,'Venda consultiva (plano completo)','Apresentar o plano inteiro, não fatiado.',1),
 ('ticket',2,'Upsell nos fechamentos parciais','Reabrir os que fecharam só parte do plano.',1),
 ('ticket',3,'Diagnóstico 360 (além do implante)','Despertar o olhar diagnóstico do clínico.',1),
 ('ticket',4,'Ferramentas de diagnóstico/imagem na avaliação','Tomodoc ou DIL, Aitero (scanner), raio-x cadastrado no sistema e fotografia apresentada no tour.',1),
 ('ticket',5,'Revisar precificação/tabela','Garantir que a tabela sustenta o ticket-alvo.',1),
 ('ticket',6,'Acompanhar ticket por avaliador','Ver quem puxa o ticket para cima/baixo.',1),
 -- RESGATE 30+ (7 — agrupado)
 ('resgate30',1,'Rotina diária de resgate','Trabalhar a planilha de resgate todo dia.',1),
 ('resgate30',2,'Priorizar pacientes com 30+ dias','Focar quem está há mais tempo parado.',1),
 ('resgate30',3,'Registrar o resgate no sistema','Lançar corretamente (relacionamento/SDR).',1),
 ('resgate30',4,'Cadência de contato e vídeos personalizados','Contatos diários + vídeos doutor/relacionamento + vídeo com raio-x/tomografia pro paciente. 🔒 (requer CRM)',1),
 ('resgate30',5,'Entusiasmo / tom de voz / abordagem','Qualidade da mensagem de resgate.',1),
 ('resgate30',6,'Doutor apoia e municia o resgate','O dentista sustenta a funcionária e leva pacientes ao avaliador p/ os vídeos.',1),
 ('resgate30',7,'Bater a meta mínima / Vlr 30+ × meta','Acompanhar o Vlr 30+ do mês vs meta mínima.',1),
 -- PARCELAMENTO MÉDIO (5)
 ('parcelamento',1,'Entrada e prazo dentro da política','Negociação para o parcelamento-alvo (teto).',1),
 ('parcelamento',2,'Usar o cartão para o perfil de risco','Score baixo → cartão (reduz inadimplência).',1),
 ('parcelamento',3,'Acompanhar inadimplência de boleto','Monitorar quem para de pagar e agir cedo.',1),
 ('parcelamento',4,'Revisar renegociações','Controle das renegociações de parcelamento.',1),
 ('parcelamento',5,'Monitorar parcelamento médio (teto) × meta','Não estourar o teto de parcelamento.',1)
)
insert into demandas (indicador_id, ordem, titulo, descricao, peso)
select i.id, ins.ordem, ins.titulo, ins.descricao, ins.peso
from ins join indicadores i on i.chave = ins.chave;

-- ===== SEED EXEMPLO =====
-- ============================================================
-- Seed de EXEMPLO (1 clínica + 1 diretor + 1 reunião + resultados)
-- Rodar após seed_demandas.sql. Dados de teste (Dourados/ago-2026).
-- ============================================================
do $$
declare
  v_cli uuid; v_dir uuid; v_reu uuid;
begin
  insert into clinicas (nome, praca, uf) values ('Dourados','Dourados','MS') returning id into v_cli;
  insert into diretores (nome, clinica_id, email) values ('Dr. Emerson', v_cli, 'diretor.dourados@ageodonto.com') returning id into v_dir;

  -- Resultados de ago/2026 (fonte: Torre de Controle)
  insert into resultados (diretor_id, indicador_id, competencia, meta, realizado, projecao)
  select v_dir, i.id, '2026-08', r.meta, r.real, r.proj
  from (values
    ('faturamento', 856500, 968377, 968377),
    ('recompra',    105000, 146864, 146864),
    ('ticket',       10500,  10442,  10442),
    ('conversao',       53,     54,     54),
    ('avaliacoes',     140,    141,    141),
    ('parcelamento',    18,     11,     11),
    ('resgate30',   90000, 106610, 106610),
    ('entrada',    149887, 209269, 209269)
  ) as r(chave, meta, real, proj)
  join indicadores i on i.chave = r.chave;

  -- Uma reunião concluída com checagens de exemplo (mistura feito/parcial/não)
  insert into reunioes (diretor_id, data, status, criado_por, resumo, video_url)
  values (v_dir, current_date, 'concluida', 'Gregori',
          'Primeira pauta: base boa em faturamento/recompra; parcelamento e conversão a trabalhar.',
          'https://exemplo.com/video-reuniao-1')
  returning id into v_reu;

  -- Marca todas as demandas como "nao" e depois ajusta algumas para feito/parcial
  insert into checagens (reuniao_id, demanda_id, status)
  select v_reu, d.id, 'nao' from demandas d;

  update checagens c set status='feito'
   from demandas d join indicadores i on i.id=d.indicador_id
   where c.demanda_id=d.id and c.reuniao_id=v_reu
     and i.chave in ('faturamento','recompra','resgate30') and d.ordem <= 3;

  update checagens c set status='parcial'
   from demandas d join indicadores i on i.id=d.indicador_id
   where c.demanda_id=d.id and c.reuniao_id=v_reu
     and i.chave in ('conversao','ticket') and d.ordem <= 2;
end $$;

-- Conferência rápida:
-- select * from v_dashboard_diretor order by diretor, indicador_ordem;

-- ===== POLICIES LEITURA (anon) =====
-- ============================================================
-- Leitura para o dashboard (Fase 2) — rodar DEPOIS dos seeds.
-- Libera SELECT para 'anon' (a anon/public key) — ferramenta interna, sem login.
-- ⚠️ Depois, com auth, restringimos por diretor/papel.
-- ============================================================
grant usage on schema public to anon, authenticated;
grant select on all tables in schema public to anon, authenticated;

do $$
declare t text;
begin
  foreach t in array array['clinicas','diretores','indicadores','demandas','reunioes','checagens','resultados']
  loop
    execute format('drop policy if exists p_anon_read on %I', t);
    execute format('create policy p_anon_read on %I for select to anon using (true)', t);
  end loop;
end $$;
