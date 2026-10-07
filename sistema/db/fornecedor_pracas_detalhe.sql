-- ============================================================
-- Fornecedores: detalhe POR PRAÇA dentro de cada reunião
-- Rodar 1x no SQL Editor do Supabase. Não-destrutivo.
-- Mantém a coluna pracas (text[]) existente p/ filtro/compat;
-- adiciona pracas_detalhe (jsonb) com [{praca,farol,comentario,acao,prazo}].
-- ============================================================
alter table reunioes_fornecedor
  add column if not exists pracas_detalhe jsonb not null default '[]'::jsonb;

-- (RLS, grants e policy p_team_all já existem para reunioes_fornecedor —
--  a nova coluna é coberta automaticamente.)
