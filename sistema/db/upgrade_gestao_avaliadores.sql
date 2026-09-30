-- Gestão dos Avaliadores — atualização aditiva e segura
-- Pode ser executada mais de uma vez.

alter table public.diretores add column if not exists telefone text;
alter table public.diretores add column if not exists foto_url text;
alter table public.diretores add column if not exists funcao text default 'Avaliador';

alter table public.reunioes add column if not exists transcricao text;
alter table public.reunioes add column if not exists observacoes text;

create table if not exists public.compromissos (
  id uuid primary key default gen_random_uuid(),
  reuniao_id uuid not null references public.reunioes(id) on delete cascade,
  diretor_id uuid not null references public.diretores(id) on delete cascade,
  indicador_id uuid references public.indicadores(id) on delete set null,
  descricao text not null,
  prazo date,
  status text not null default 'pendente' check (status in ('pendente','concluido')),
  concluido_na_reuniao_id uuid references public.reunioes(id) on delete set null,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);

grant select, insert, update, delete on public.compromissos to authenticated;
grant all on public.compromissos to service_role;
-- Compatibilidade temporária com a política atual do sistema antigo.
grant select, insert, update, delete on public.compromissos to anon;

alter table public.compromissos enable row level security;
drop policy if exists p_auth_all on public.compromissos;
create policy p_auth_all on public.compromissos for all to authenticated using (true) with check (true);
drop policy if exists p_anon_all on public.compromissos;
create policy p_anon_all on public.compromissos for all to anon using (true) with check (true);

create index if not exists idx_compromissos_diretor_status on public.compromissos(diretor_id,status);
create index if not exists idx_compromissos_reuniao on public.compromissos(reuniao_id);
create index if not exists idx_compromissos_prazo on public.compromissos(prazo);
