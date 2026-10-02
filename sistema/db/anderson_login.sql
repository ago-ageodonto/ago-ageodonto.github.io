-- Login próprio do Anderson no Checklist de Campo.
-- Libera o usuário anderson@ageodonto.com.br a LER/GRAVAR os lançamentos e o NPS,
-- junto com o time (equipe@). As anotações internas (anderson_notas) continuam
-- SÓ do time — o Anderson não vê o Acompanhamento.
--
-- PASSO MANUAL (você faz no Supabase, pois envolve criar senha):
--   Authentication > Users > Add user
--     email: anderson@ageodonto.com.br
--     password: <a senha que você definir para ele>
--     Auto Confirm User: SIM
--   Depois rode este SQL.

-- entries: time + anderson
drop policy if exists p_team_all on anderson_entries;
drop policy if exists p_rw on anderson_entries;
create policy p_rw on anderson_entries for all to authenticated
  using      (auth.jwt()->>'email' in ('equipe@ageodonto.com.br','anderson@ageodonto.com.br'))
  with check (auth.jwt()->>'email' in ('equipe@ageodonto.com.br','anderson@ageodonto.com.br'));

-- nps: time + anderson
drop policy if exists p_team_all on anderson_nps;
drop policy if exists p_rw on anderson_nps;
create policy p_rw on anderson_nps for all to authenticated
  using      (auth.jwt()->>'email' in ('equipe@ageodonto.com.br','anderson@ageodonto.com.br'))
  with check (auth.jwt()->>'email' in ('equipe@ageodonto.com.br','anderson@ageodonto.com.br'));

-- notas internas: continua SÓ do time (não mexe; Anderson não acessa)
-- (policy p_team_all em anderson_notas permanece como está)
