-- ============================================================
-- Seed das DEMANDAS por indicador (CONSOLIDADO/AGRUPADO)
-- Rodar após seed_indicadores.sql. 🔒 na descrição = requer CRM/ferramenta.
-- ============================================================
truncate table checagens;
delete from demandas;

with ins(chave, ordem, titulo, descricao, peso) as (values
 -- FATURAMENTO (5)
 ('faturamento',1,'Agenda cheia dos avaliadores','Não deixar cadeira ociosa; bloqueios e horários preenchidos.',1),
 ('faturamento',2,'Leitura diária do realizado × projeção','Acompanhar no Giga e reagir quando furar a meta.',1),
 ('faturamento',3,'Recuperar orçamentos de alto ticket não fechados','Follow-up semanal dos grandes orçamentos abertos.',1),
 ('faturamento',4,'Mix de tratamentos (além do implante)','Prótese, orto, faceta, clínico geral.',1),
 ('faturamento',5,'Plano de recuperação quando furar a meta','Campanha/mutirão/resgate quando a projeção cair.',1),
 -- RECOMPRA (6)
 ('recompra',1,'Rotina de resgate da base','Trabalhar diariamente a lista de resgate.',1),
 ('recompra',2,'Reavaliação e retorno agendados','Tratamentos em andamento voltam para nova venda.',1),
 ('recompra',3,'Trabalhar as altas → indicações','Todo paciente de alta vira porta de indicação.',1),
 ('recompra',4,'Campanha e disparos para a base ativa','Reativação + disparos (ex.: higienização de protocolo). 🔒 (requer CRM)',1),
 ('recompra',5,'Alinhamento com os dentistas p/ essas vendas','Dentistas engajados para realizar as vendas da base.',1),
 ('recompra',6,'Monitorar % de recompra × meta','Acompanhar o indicador e corrigir rota.',1),
 -- ENTRADA (6)
 ('entrada',1,'Entrada como pré-requisito da venda','A entrada é condição pra fechar — padronizado.',1),
 ('entrada',2,'Qualidade da negociação e credibilidade','Como está a negociação e a credibilidade que o dentista passa.',1),
 ('entrada',3,'Usar a Ovix Pro (gravação)','Gravar a venda pra avaliar a abordagem. (ferramenta Ovix Pro)',1),
 ('entrada',4,'Confirmação ativa (áudio/vídeo) dos fechados','Reduzir arrependimento/cancelamento com confirmação individual.',1),
 ('entrada',5,'Garantir a entrada efetivada','Acompanhar a efetivação da entrada da venda.',1),
 ('entrada',6,'Monitorar entrada × meta','Acompanhar o indicador de entrada.',1),
 -- AVALIAÇÕES (6 — agrupado)
 ('avaliacoes',1,'Funil e agenda de avaliação','Volume de leads + capacidade + reduzir no-show + agenda dedicada (não usar p/ atendimento).',1),
 ('avaliacoes',2,'Engajamento nas redes (Insta/Face)','Responder comentários e interagir com quem curtiu as publicações. 🔒 (requer CRM/social)',1),
 ('avaliacoes',3,'Entregar os vídeos solicitados','Vídeos de marketing e de captação pedidos.',1),
 ('avaliacoes',4,'Presença ativa','Presença na clínica, rádio no horário, reuniões de marketing/SDR e eventos de comunidade.',1),
 ('avaliacoes',5,'Indicações dos funcionários','Avaliações trazidas por indicação dos funcionários (há bonificação).',1),
 ('avaliacoes',6,'Monitorar nº de avaliações × meta','Acompanhar o indicador diariamente.',1),
 -- CONVERSÃO (7 — agrupado)
 ('conversao',1,'Confirmação ativa das avaliações','Reduzir no-show garantindo comparecimento.',1),
 ('conversao',2,'Padrão de atendimento e tour na recepção','Experiência consistente antes da avaliação.',1),
 ('conversao',3,'Follow-up dos não-fechados','Trabalhar quem avaliou e não fechou.',1),
 ('conversao',4,'Fechamento (treino + no ato)','Treinar fechamento e estimular a decisão na hora, com a proposta pronta.',1),
 ('conversao',5,'Storytelling na venda','Usar storytelling na apresentação da venda.',1),
 ('conversao',6,'Passagem para o relacionamento','Paciente vai direto à sala do relacionamento e o contexto da venda é alinhado antes de chamá-lo.',1),
 ('conversao',7,'Monitorar conversão por avaliador × meta','Acompanhar e corrigir por pessoa.',1),
 -- TICKET MÉDIO (6 — agrupado)
 ('ticket',1,'Venda consultiva (plano completo)','Apresentar o plano inteiro, não fatiado.',1),
 ('ticket',2,'Upsell nos fechamentos parciais','Reabrir os que fecharam só parte do plano.',1),
 ('ticket',3,'Diagnóstico 360 (além do implante)','Despertar o olhar diagnóstico do clínico.',1),
 ('ticket',4,'Ferramentas de diagnóstico/imagem na avaliação','Tomodoc ou DIL, Aitero (scanner), raio-x cadastrado no sistema e fotografia apresentada no tour.',1),
 ('ticket',5,'Revisar precificação/tabela','Garantir que a tabela sustenta o ticket-alvo.',1),
 ('ticket',6,'Acompanhar ticket por avaliador','Ver quem puxa o ticket para cima/baixo.',1),
 -- RESGATE 30+ (7 — agrupado)
 ('resgate30',1,'Rotina diária de resgate','Trabalhar a planilha de resgate todo dia.',1),
 ('resgate30',2,'Priorizar pacientes com 30+ dias','Focar quem está há mais tempo parado.',1),
 ('resgate30',3,'Registrar o resgate no sistema','Lançar corretamente (relacionamento/SDR).',1),
 ('resgate30',4,'Cadência de contato e vídeos personalizados','Contatos diários + vídeos doutor/relacionamento + vídeo com raio-x/tomografia pro paciente. 🔒 (requer CRM)',1),
 ('resgate30',5,'Entusiasmo / tom de voz / abordagem','Qualidade da mensagem de resgate.',1),
 ('resgate30',6,'Doutor apoia e municia o resgate','O dentista sustenta a funcionária e leva pacientes ao avaliador p/ os vídeos.',1),
 ('resgate30',7,'Bater a meta mínima / Vlr 30+ × meta','Acompanhar o Vlr 30+ do mês vs meta mínima.',1),
 -- PARCELAMENTO MÉDIO (5)
 ('parcelamento',1,'Entrada e prazo dentro da política','Negociação para o parcelamento-alvo (teto).',1),
 ('parcelamento',2,'Usar o cartão para o perfil de risco','Score baixo → cartão (reduz inadimplência).',1),
 ('parcelamento',3,'Acompanhar inadimplência de boleto','Monitorar quem para de pagar e agir cedo.',1),
 ('parcelamento',4,'Revisar renegociações','Controle das renegociações de parcelamento.',1),
 ('parcelamento',5,'Monitorar parcelamento médio (teto) × meta','Não estourar o teto de parcelamento.',1)
)
insert into demandas (indicador_id, ordem, titulo, descricao, peso)
select i.id, ins.ordem, ins.titulo, ins.descricao, ins.peso
from ins join indicadores i on i.chave = ins.chave;
