-- View "motivacional" para o ticker da Torre da Praça:
-- expõe SÓ o percentual dos indicadores POSITIVOS (farol verde) de cada praça,
-- SEM valores (faturamento etc.). Alimenta o ticker "ao vivo" que os sócios veem.
-- Exclui 'parc' (parcelamento é teto — o % confunde num ticker de motivação).
-- security_invoker=on -> respeita a RLS do torre_snapshot (leitura liberada p/ logados).

create or replace view v_praca_motivacional
with (security_invoker = on) as
select
  s.nome,
  e.key                                           as ind,
  round((e.value->>3)::numeric * 100)::int        as pct
from torre_snapshot s,
     lateral jsonb_each(s.dados->'ind') e
where e.value->>4 = 'g'          -- só farol verde (positivo)
  and e.key <> 'parc'            -- tira parcelamento (teto)
  and (e.value->>3) is not null;

revoke all on v_praca_motivacional from anon;
grant select on v_praca_motivacional to authenticated;
