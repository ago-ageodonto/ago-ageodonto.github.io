-- Fecha a plataforma interna: só a conta do TIME (equipe@ageodonto.com.br) acessa.
-- Remove o acesso anônimo (anon) das tabelas da plataforma.
-- Idempotente e seguro: só mexe nas tabelas que existirem.
-- RODAR SÓ DEPOIS de confirmar que o login do time (senha A) abre a plataforma.

do $$
declare r record;
begin
  for r in select policyname, tablename from pg_policies
    where schemaname='public'
      and tablename in ('clinicas','diretores','indicadores','demandas','reunioes','checagens','compromissos','apuracoes','resultados')
  loop
    execute format('drop policy if exists %I on public.%I', r.policyname, r.tablename);
  end loop;
end $$;

do $$
declare t text;
begin
  foreach t in array array['clinicas','diretores','indicadores','demandas','reunioes','checagens','compromissos','apuracoes','resultados']
  loop
    if to_regclass('public.'||t) is not null then
      execute format('alter table public.%I enable row level security', t);
      execute format('revoke all on public.%I from anon', t);
      execute format('grant select, insert, update, delete on public.%I to authenticated', t);
      execute format('create policy p_team_all on public.%I for all to authenticated using (auth.jwt()->>''email'' = ''equipe@ageodonto.com.br'') with check (auth.jwt()->>''email'' = ''equipe@ageodonto.com.br'')', t);
    end if;
  end loop;
end $$;
