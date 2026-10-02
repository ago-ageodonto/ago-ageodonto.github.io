-- ================================================================
-- BUNDLE (rodar UMA vez no Supabase → SQL Editor)
-- 1) View do histórico mês a mês (seletor de mês na Visão Geral)
-- 2) Tabela de Reuniões com Fornecedores (nova aba)
-- Tudo idempotente e fechado só pro time (equipe@ageodonto.com.br).
-- Obs.: a mudança de "nota por função por data" NÃO precisa de SQL
--       (apuracoes.competencia é texto livre) — já está nas páginas.
-- ================================================================

-- 1) ------------------------------------------------------------------
-- View irmã da v_dashboard_diretor, SEM o "último mês" (lateral limit 1):
-- devolve TODAS as competências, filtrável por ?competencia=eq.AAAA-MM.
create or replace view v_dashboard_diretor_mes
with (security_invoker = on) as
select
  di.id    as diretor_id,
  di.nome  as diretor,
  cl.nome  as clinica,
  ind.chave as indicador_chave,
  ind.nome  as indicador,
  ind.ordem as indicador_ordem,
  ind.sentido,
  r.competencia,
  r.meta,
  r.realizado,
  r.projecao
from diretores di
join clinicas   cl  on cl.id = di.clinica_id
cross join indicadores ind
join resultados r
     on r.diretor_id = di.id and r.indicador_id = ind.id
order by r.competencia desc, di.nome, ind.ordem;

revoke all on v_dashboard_diretor_mes from anon;
grant select on v_dashboard_diretor_mes to authenticated;

-- 2) ------------------------------------------------------------------
-- Reuniões com Fornecedores (histórico de transcrições, filtrável por praça).
create table if not exists reunioes_fornecedor (
  id          uuid primary key default gen_random_uuid(),
  fornecedor  text not null,
  data        date,
  assunto     text,
  transcricao text,
  pracas      text[] not null default '{}',
  criado_por  text,
  criado_em   timestamptz not null default now()
);
create index if not exists idx_reunioes_fornecedor_data on reunioes_fornecedor(data desc);

alter table reunioes_fornecedor enable row level security;
revoke all on reunioes_fornecedor from anon;
grant select, insert, update, delete on reunioes_fornecedor to authenticated;
drop policy if exists p_team_all on reunioes_fornecedor;
create policy p_team_all on reunioes_fornecedor
  for all to authenticated
  using      (auth.jwt()->>'email' = 'equipe@ageodonto.com.br')
  with check (auth.jwt()->>'email' = 'equipe@ageodonto.com.br');
