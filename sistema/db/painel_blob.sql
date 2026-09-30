-- Painel de Resultados — armazém dos dados (só sócios). Rodar uma vez.
create table if not exists public.painel_blob(
  id text primary key,
  data jsonb not null,
  atualizado_em timestamptz not null default now()
);
grant select, insert, update on public.painel_blob to authenticated;
grant all on public.painel_blob to service_role;
alter table public.painel_blob enable row level security;
drop policy if exists p_pb_team on public.painel_blob;
create policy p_pb_team on public.painel_blob for all to authenticated
  using (auth.jwt()->>'email' = 'equipe@ageodonto.com.br')
  with check (auth.jwt()->>'email' = 'equipe@ageodonto.com.br');
