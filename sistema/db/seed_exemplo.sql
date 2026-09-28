-- ============================================================
-- Seed de EXEMPLO (1 clínica + 1 diretor + 1 reunião + resultados)
-- Rodar após seed_demandas.sql. Dados de teste (Dourados/ago-2026).
-- ============================================================
do $$
declare
  v_cli uuid; v_dir uuid; v_reu uuid;
begin
  insert into clinicas (nome, praca, uf) values ('Dourados','Dourados','MS') returning id into v_cli;
  insert into diretores (nome, clinica_id, email) values ('Dr. Emerson', v_cli, 'diretor.dourados@ageodonto.com') returning id into v_dir;

  -- Resultados de ago/2026 (fonte: Torre de Controle)
  insert into resultados (diretor_id, indicador_id, competencia, meta, realizado, projecao)
  select v_dir, i.id, '2026-08', r.meta, r.real, r.proj
  from (values
    ('faturamento', 856500, 968377, 968377),
    ('recompra',    105000, 146864, 146864),
    ('ticket',       10500,  10442,  10442),
    ('conversao',       53,     54,     54),
    ('avaliacoes',     140,    141,    141),
    ('parcelamento',    18,     11,     11),
    ('resgate30',   90000, 106610, 106610),
    ('entrada',    149887, 209269, 209269)
  ) as r(chave, meta, real, proj)
  join indicadores i on i.chave = r.chave;

  -- Uma reunião concluída com checagens de exemplo (mistura feito/parcial/não)
  insert into reunioes (diretor_id, data, status, criado_por, resumo, video_url)
  values (v_dir, current_date, 'concluida', 'Gregori',
          'Primeira pauta: base boa em faturamento/recompra; parcelamento e conversão a trabalhar.',
          'https://exemplo.com/video-reuniao-1')
  returning id into v_reu;

  -- Marca todas as demandas como "nao" e depois ajusta algumas para feito/parcial
  insert into checagens (reuniao_id, demanda_id, status)
  select v_reu, d.id, 'nao' from demandas d;

  update checagens c set status='feito'
   from demandas d join indicadores i on i.id=d.indicador_id
   where c.demanda_id=d.id and c.reuniao_id=v_reu
     and i.chave in ('faturamento','recompra','resgate30') and d.ordem <= 3;

  update checagens c set status='parcial'
   from demandas d join indicadores i on i.id=d.indicador_id
   where c.demanda_id=d.id and c.reuniao_id=v_reu
     and i.chave in ('conversao','ticket') and d.ordem <= 2;
end $$;

-- Conferência rápida:
-- select * from v_dashboard_diretor order by diretor, indicador_ordem;
