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
