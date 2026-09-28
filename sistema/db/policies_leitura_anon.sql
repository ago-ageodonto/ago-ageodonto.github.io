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
