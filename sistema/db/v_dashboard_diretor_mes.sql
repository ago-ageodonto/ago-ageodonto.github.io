-- View irmã da v_dashboard_diretor, SEM o "último mês" (lateral limit 1):
-- devolve TODAS as competências, filtrável por ?competencia=eq.AAAA-MM.
-- Alimenta o seletor de mês da Visão Geral (geral.html).
-- security_invoker=on -> respeita a RLS das tabelas (acesso só do time, equipe@ageodonto.com.br).
-- Idempotente: pode rodar quantas vezes quiser.

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
