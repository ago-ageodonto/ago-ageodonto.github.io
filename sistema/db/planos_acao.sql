-- Plano de ação por indicador (por avaliador). Um plano "vivo" por (diretor, indicador),
-- editável no Painel do Avaliador. Fechado só pro time (equipe@).
create table if not exists planos_acao (
  id            uuid primary key default gen_random_uuid(),
  diretor_id    uuid not null references diretores(id)   on delete cascade,
  indicador_id  uuid not null references indicadores(id) on delete cascade,
  texto         text,
  atualizado_em timestamptz not null default now(),
  unique (diretor_id, indicador_id)
);
alter table planos_acao enable row level security;
revoke all on planos_acao from anon;
grant select, insert, update, delete on planos_acao to authenticated;
drop policy if exists p_team_all on planos_acao;
create policy p_team_all on planos_acao
  for all to authenticated
  using      (auth.jwt()->>'email' = 'equipe@ageodonto.com.br')
  with check (auth.jwt()->>'email' = 'equipe@ageodonto.com.br');
