-- Checklist de Campo do Anderson (consultor comercial) dentro do sistema.
-- 3 tabelas: lançamentos por frente/dia, respostas de NPS e anotações internas.
-- Fechado ao time (equipe@ageodonto.com.br), como as demais tabelas da plataforma.

-- 1) Lançamentos do checklist: um por (data, frente). respostas/obs em jsonb (chaves = nº do item, ex. "1.1").
create table if not exists anderson_entries (
  data         date not null,
  frente       text not null,
  frente_nome  text,
  respostas    jsonb not null default '{}'::jsonb,
  obs          jsonb not null default '{}'::jsonb,
  salvo_em     timestamptz not null default now(),
  primary key (data, frente)
);

-- 2) Pesquisa de atendimento (NPS): uma linha por paciente.
create table if not exists anderson_nps (
  id        uuid primary key default gen_random_uuid(),
  data      date,
  dados     jsonb not null default '{}'::jsonb,
  salvo_em  timestamptz not null default now()
);

-- 3) Anotações de desenvolvimento (internas, aba Acompanhamento).
create table if not exists anderson_notas (
  id        uuid primary key default gen_random_uuid(),
  texto     text not null,
  salvo_em  timestamptz not null default now()
);

alter table anderson_entries enable row level security;
alter table anderson_nps     enable row level security;
alter table anderson_notas   enable row level security;

revoke all on anderson_entries from anon;
revoke all on anderson_nps     from anon;
revoke all on anderson_notas   from anon;
grant select, insert, update, delete on anderson_entries to authenticated;
grant select, insert, update, delete on anderson_nps     to authenticated;
grant select, insert, update, delete on anderson_notas   to authenticated;

drop policy if exists p_team_all on anderson_entries;
create policy p_team_all on anderson_entries for all to authenticated
  using (auth.jwt()->>'email' = 'equipe@ageodonto.com.br')
  with check (auth.jwt()->>'email' = 'equipe@ageodonto.com.br');

drop policy if exists p_team_all on anderson_nps;
create policy p_team_all on anderson_nps for all to authenticated
  using (auth.jwt()->>'email' = 'equipe@ageodonto.com.br')
  with check (auth.jwt()->>'email' = 'equipe@ageodonto.com.br');

drop policy if exists p_team_all on anderson_notas;
create policy p_team_all on anderson_notas for all to authenticated
  using (auth.jwt()->>'email' = 'equipe@ageodonto.com.br')
  with check (auth.jwt()->>'email' = 'equipe@ageodonto.com.br');
