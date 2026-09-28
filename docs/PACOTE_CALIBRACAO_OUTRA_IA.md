# Sistema de Gestão Comercial — Pacote de Calibração

> **Como usar este documento:** cole tudo isto na outra IA como contexto inicial. Ele é auto-contido: explica a visão, os 8 indicadores, o modelo de notas por função (a lógica que dá a nota do avaliador), traz o **código real** (JavaScript das funções→nota + SQL do banco) e no fim diz exatamente o que você quer que ela faça. Não precisa recalibrar nada do zero — está tudo aqui.

---

## 1. O que é o sistema

Plataforma de **Gestão Comercial para Diretores Clínicos** de uma rede de ~40 clínicas odontológicas (Ageodonto / Oral Unic). O objetivo é dar ao diretor comercial (Gregori) um **motor de acompanhamento por indicador**: a cada reunião com o avaliador/diretor de cada praça, ele registra o que foi feito, o sistema calcula uma **nota por indicador** e cruza essa nota com o **resultado real** do mês (puxado do Giga/Torre de Controle). A leitura-chave é *"não fez × não bateu"* vs *"fez × bateu"*.

**Stack:** front-end estático (HTML/JS puro, sem framework) + Supabase (Postgres/PostgREST) + host Netlify. Páginas: `index` (menu), `console` (lançamento de notas por função), `geral`/`avaliador`/`rede` (leitura), `dashboard` (cruzamento aderência × resultado).

**Princípio de leitura:** aderência (o que foi feito nas funções) de um lado, resultado do indicador (bateu meta?) do outro. Onde o avaliador **não fez e não bateu**, a cobrança é clara. Onde **fez e bateu**, reforço. O resto é ruído.

---

## 2. Os 8 indicadores

Alinhados 1:1 com a Torre de Controle. Todos "maior = melhor", **exceto Parcelamento**, que é **teto** (limite que não se pode estourar; quanto menor, melhor).

| # | chave | Nome | Sentido | O que mede |
|---|-------|------|---------|------------|
| 1 | `faturamento` | Faturamento | maior_melhor | Faturamento bruto da unidade no mês. *Consequência* — não tem funções próprias de nota. |
| 2 | `recompra` | Recompra | maior_melhor | Faturamento vindo da base (reaval/retorno/acréscimo/resgate). |
| 3 | `entrada` | Entrada | maior_melhor | Entrada de caixa das vendas (negociação/fechamento). |
| 4 | `avaliacoes` | Avaliações | maior_melhor | Quantidade de avaliações realizadas no mês. |
| 5 | `conversao` | Conversão | maior_melhor | Dos que compareceram, quantos fecharam. |
| 6 | `ticket` | Ticket médio | maior_melhor | Valor médio por avaliação fechada. |
| 7 | `resgate30` | Resgate 30+ | maior_melhor | Vendas resgatadas de pacientes com 30+ dias parados (Vlr 30+). |
| 8 | `parcelamento` | Parcelamento médio | **teto** | Parcelamento médio ponderado. É um **limite**: abaixo do número = OK. |

**Faturamento** é resultado/consequência dos outros — no modelo de notas ele não tem funções (não se dá nota de "esforço" a ele; ele aparece só como resultado a bater).

---

## 3. Modelo de notas por função (a lógica central)

Cada indicador se decompõe em **funções** — os comportamentos concretos que o avaliador tem que executar para o indicador andar. A cada reunião, o diretor lança os números de cada função e o sistema calcula:

- **Nota de cada função:** 0 a 100, por uma fórmula própria (ver seção 4).
- **Nota do indicador:** média das funções **com peso**.

### Regra-mãe (não violar ao calibrar)

1. **Peso IGUAL entre as funções** de um indicador. A nuance/gravidade mora *dentro* da fórmula de cada função, não em pesos diferentes entre funções.
2. **Funções `neutro:true` não entram na média** — são "de referência" (o diretor marca Bom/Regular/Ruim para acompanhar, mas não pesa na nota). Viram "com peso" quando a ferramenta que as sustenta (ex.: Ovix Pro) estiver instalada.
3. **`nota` retorna `null`** quando não há dado lançado → a função é ignorada na média (não conta como zero).
4. Todas as notas são **clampadas em [0, 100]** e arredondadas.

### Como a média sai (pseudocódigo)

```
notas = []
para cada função f do indicador:
  if f.neutro: continue          // referência, não pesa
  n = f.nota(valores_lançados)
  if n === null: continue        // sem dado, ignora
  notas.push(n)
nota_do_indicador = média(notas)  // peso igual
```

---

## 4. As funções de cada indicador + fórmulas

Legenda: **meta** = alvo; **Nota** = fórmula (sempre clampada 0–100). `neutro` = não pesa hoje.

### 7 — Resgate 30+
- **Contatos do relacionamento** (meta ≥10/dia, registrados): `Nota = (média_dia / 10) × 100`. Se **não registrado no sistema → 0** (cobrança conjunta avaliador + relacionamento).
- **Vídeos do doutor p/ resgate** (meta ≥5): `Nota = (vídeos_feitos / 5) × 100`.
- **Entusiasmo / abordagem:** Bom=100, Regular=50, Ruim=0.

### 8 — Parcelamento médio (teto)
- **Conformidade de parcelamento:** de N contratos analisados, A ficaram acima do teto da praça e B desses sem justificativa (prazo de recebimento incompatível com a entrega). `Nota = 100 − 5×(A−B) − 10×B`. Ou seja: cada contrato acima tira 5; se sem justificativa, tira 10 (o dobro).

### 6 — Ticket médio
- **Uso da ferramenta de IA** (meta ≥80% das avaliações): `Nota = (uso% / 80) × 100`.
- **Cobertura da oferta** (ofertou tudo?): `Nota = (completas + 0,5×parciais) / avaliações_analisadas × 100`.
- **Foto + IA antes-e-depois (casos estéticos):** `Nota = casos_com_AD / casos_estéticos × 100`.

### 5 — Conversão
- **Envio de gravações de avaliações** (meta ≥10): `Nota = (enviadas / 10) × 100`. **Única função com peso hoje.**
- **Storytelling / Negociação / Abordagem do dentista / Análise de score:** todas `neutro` (Bom/Regular/Ruim de referência) — dependem do **Ovix Pro** (em instalação) para virar peso.

### 3 — Entrada
- **Envio de gravações de avaliações** (meta ≥10): `Nota = (enviadas / 10) × 100`. **Única com peso hoje** (mesma base da conversão, via Ovix Pro).
- **Storytelling / Negociação / Abordagem / Score:** `neutro` (idem Conversão).

### 4 — Avaliações
- **Entrega de vídeos** (mkt + captação): `Nota = enviados / solicitados × 100`.
- **Presença ativa** (reuniões mkt + rádio): `Nota = cumpridos / previstos × 100`.
- **Bloqueios indevidos na agenda (penalidade):** `Nota = 100 − %_carga_horária_perdida`.
- **Avaliações trazidas pela equipe** (meta 4/sem ≈16/mês): `Nota = (n / 16) × 100`.
- **Comentários nas redes respondidos:** `Nota = respondidos / comentários × 100`.
- **Avaliações de interação nas redes** (meta 1/sem ≈4/mês): `Nota = (n / 4) × 100`.

### 2 — Recompra
- **Altas realizadas** (meta ≥30/mês): `Nota = (altas / 30) × 100`.
- **Venda nas altas + reavaliações** (meta ≥70%): `Nota = (%venda / 70) × 100`, onde `%venda = vendas/base`.
- **Disparos de recompra** — avaliador + relacionamento (meta ≥30/mês): `Nota = (disparos / 30) × 100`.
- **Ação/bonificação da equipe de protesistas:** `neutro` (Sim=100 / Não=0, de referência).

### 1 — Faturamento
- Sem funções de nota. É consequência dos demais; entra só como **resultado a bater** (realizado × meta na Torre).

---

## 5. Código real — funções → nota (JavaScript)

Este é o objeto `FUNCS` que roda no `console.html`. Cada função tem: `key`, `label`, `inputs` (campos que o diretor preenche), `nota(v)` (fórmula → 0–100 ou null) e `detail(v)` (texto de resumo). `neutro:true` = não pesa.

```javascript
var FUNCS={
 parcelamento:{label:"Parcelamento médio",funcs:[
   {key:"conf",label:"Conformidade de parcelamento",inputs:[
     {k:"analisados",label:"Contratos analisados"},{k:"acima",label:"Acima do teto"},{k:"injust",label:"Desses, sem justificativa"}],
    nota:v=>{if(!(v.analisados||v.acima||v.injust))return null;var A=v.acima||0,B=Math.min(v.injust||0,A);return Math.max(0,Math.round(100-5*(A-B)-10*B));},
    detail:v=>{var N=v.analisados||0,A=v.acima||0,B=Math.min(v.injust||0,A);return N?(A+" acima do teto de "+N+(B?(" · "+B+" sem justificativa"):"")):"";}}
 ]},
 resgate30:{label:"Resgate 30+",funcs:[
   {key:"contatos",label:"Contatos do relacionamento (≥10/dia)",inputs:[
     {k:"media",label:"Contatos/dia (média)"},{k:"reg",label:"Registrado no sistema?",sel:[["sim","Sim"],["nao","Não"]]}],
    nota:v=>{if(v.reg==="nao")return 0;if(v.media===""||v.media==null)return null;return Math.min(100,Math.round((+v.media)/10*100));},
    detail:v=>{if(v.media===""||v.media==null)return (v.reg==="nao"?"NÃO registrado (0)":"");return v.media+"/dia"+(v.reg==="nao"?" · NÃO registrado (0)":"");}},
   {key:"videos",label:"Vídeos do doutor p/ resgate (≥5)",inputs:[{k:"feitos",label:"Vídeos feitos"}],
    nota:v=>{if(v.feitos===""||v.feitos==null)return null;return Math.min(100,Math.round((+v.feitos)/5*100));},
    detail:v=>{if(v.feitos===""||v.feitos==null)return "";return v.feitos+" vídeos (meta 5)";}},
   {key:"entusiasmo",label:"Entusiasmo / abordagem",inputs:[{k:"grau",label:"Avaliação",sel:[["bom","Bom"],["regular","Regular"],["ruim","Ruim"]]}],
    nota:v=>v.grau==="bom"?100:v.grau==="regular"?50:v.grau==="ruim"?0:null,
    detail:v=>({bom:"Bom",regular:"Regular",ruim:"Ruim"})[v.grau]||""}
 ]},
 ticket:{label:"Ticket médio",funcs:[
   {key:"ia",label:"Uso da ferramenta de IA (meta ≥80%)",inputs:[{k:"uso",label:"% das avaliações que usaram"}],
    nota:v=>{if(v.uso===""||v.uso==null)return null;return Math.min(100,Math.round((+v.uso)/80*100));},
    detail:v=>{if(v.uso===""||v.uso==null)return "";return v.uso+"% usaram a ferramenta";}},
   {key:"oferta",label:"Cobertura da oferta (ofertou tudo?)",inputs:[
     {k:"analisadas",label:"Avaliações analisadas"},{k:"completa",label:"Oferta completa"},{k:"parcial",label:"Oferta parcial"}],
    nota:v=>{var N=v.analisadas||0;if(!N)return null;return Math.round(((v.completa||0)+0.5*(v.parcial||0))/N*100);},
    detail:v=>{var N=v.analisadas||0;return N?((v.completa||0)+" completa / "+(v.parcial||0)+" parcial de "+N):"";}},
   {key:"esteticos",label:"Foto + IA antes-e-depois (casos estéticos)",inputs:[
     {k:"esteticos",label:"Casos estéticos"},{k:"comAD",label:"Com antes-e-depois"}],
    nota:v=>{var E=v.esteticos||0;if(!E)return null;return Math.round((v.comAD||0)/E*100);},
    detail:v=>{var E=v.esteticos||0;return E?((v.comAD||0)+" de "+E+" estéticos com antes-e-depois"):"";}}
 ]},
 conversao:{label:"Conversão",funcs:[
   {key:"gravacoes",label:"Envio de gravações de avaliações (≥10)",inputs:[{k:"enviadas",label:"Gravações enviadas"}],
    nota:v=>{if(v.enviadas===""||v.enviadas==null)return null;return Math.min(100,Math.round((+v.enviadas)/10*100));},
    detail:v=>{if(v.enviadas===""||v.enviadas==null)return "";return v.enviadas+" gravações enviadas (meta 10)";}},
   {key:"storytelling",label:"Storytelling da venda",neutro:true,inputs:[{k:"grau",label:"Avaliação (referência)",sel:[["bom","Bom"],["regular","Regular"],["ruim","Ruim"]]}],
    nota:v=>v.grau==="bom"?100:v.grau==="regular"?50:v.grau==="ruim"?0:null,detail:v=>({bom:"Bom",regular:"Regular",ruim:"Ruim"})[v.grau]||""},
   {key:"negociacao",label:"Negociação no orçamento",neutro:true,inputs:[{k:"grau",label:"Avaliação (referência)",sel:[["bom","Bom"],["regular","Regular"],["ruim","Ruim"]]}],
    nota:v=>v.grau==="bom"?100:v.grau==="regular"?50:v.grau==="ruim"?0:null,detail:v=>({bom:"Bom",regular:"Regular",ruim:"Ruim"})[v.grau]||""},
   {key:"abordagem",label:"Abordagem do dentista",neutro:true,inputs:[{k:"grau",label:"Avaliação (referência)",sel:[["bom","Bom"],["regular","Regular"],["ruim","Ruim"]]}],
    nota:v=>v.grau==="bom"?100:v.grau==="regular"?50:v.grau==="ruim"?0:null,detail:v=>({bom:"Bom",regular:"Regular",ruim:"Ruim"})[v.grau]||""},
   {key:"score",label:"Análise de score do paciente",neutro:true,inputs:[{k:"grau",label:"Avaliação (referência)",sel:[["bom","Bom"],["regular","Regular"],["ruim","Ruim"]]}],
    nota:v=>v.grau==="bom"?100:v.grau==="regular"?50:v.grau==="ruim"?0:null,detail:v=>({bom:"Bom",regular:"Regular",ruim:"Ruim"})[v.grau]||""}
 ]},
 entrada:{label:"Entrada",funcs:[
   {key:"gravacoes",label:"Envio de gravações de avaliações (≥10)",inputs:[{k:"enviadas",label:"Gravações enviadas"}],
    nota:v=>{if(v.enviadas===""||v.enviadas==null)return null;return Math.min(100,Math.round((+v.enviadas)/10*100));},
    detail:v=>{if(v.enviadas===""||v.enviadas==null)return "";return v.enviadas+" gravações enviadas (meta 10)";}},
   {key:"storytelling",label:"Storytelling da venda",neutro:true,inputs:[{k:"grau",label:"Avaliação (referência)",sel:[["bom","Bom"],["regular","Regular"],["ruim","Ruim"]]}],
    nota:v=>v.grau==="bom"?100:v.grau==="regular"?50:v.grau==="ruim"?0:null,detail:v=>({bom:"Bom",regular:"Regular",ruim:"Ruim"})[v.grau]||""},
   {key:"negociacao",label:"Negociação no orçamento",neutro:true,inputs:[{k:"grau",label:"Avaliação (referência)",sel:[["bom","Bom"],["regular","Regular"],["ruim","Ruim"]]}],
    nota:v=>v.grau==="bom"?100:v.grau==="regular"?50:v.grau==="ruim"?0:null,detail:v=>({bom:"Bom",regular:"Regular",ruim:"Ruim"})[v.grau]||""},
   {key:"abordagem",label:"Abordagem do dentista",neutro:true,inputs:[{k:"grau",label:"Avaliação (referência)",sel:[["bom","Bom"],["regular","Regular"],["ruim","Ruim"]]}],
    nota:v=>v.grau==="bom"?100:v.grau==="regular"?50:v.grau==="ruim"?0:null,detail:v=>({bom:"Bom",regular:"Regular",ruim:"Ruim"})[v.grau]||""},
   {key:"score",label:"Análise de score do paciente",neutro:true,inputs:[{k:"grau",label:"Avaliação (referência)",sel:[["bom","Bom"],["regular","Regular"],["ruim","Ruim"]]}],
    nota:v=>v.grau==="bom"?100:v.grau==="regular"?50:v.grau==="ruim"?0:null,detail:v=>({bom:"Bom",regular:"Regular",ruim:"Ruim"})[v.grau]||""}
 ]},
 avaliacoes:{label:"Avaliações",funcs:[
   {key:"videos",label:"Entrega de vídeos (mkt + captação)",inputs:[{k:"solicitados",label:"Vídeos solicitados"},{k:"enviados",label:"Vídeos enviados"}],
    nota:v=>{var S=v.solicitados||0;if(!S)return null;return Math.min(100,Math.round((v.enviados||0)/S*100));},
    detail:v=>{var S=v.solicitados||0;return S?((v.enviados||0)+" de "+S+" vídeos enviados"):"";}},
   {key:"presenca",label:"Presença ativa (reuniões mkt + rádio)",inputs:[{k:"previstos",label:"Compromissos previstos"},{k:"cumpridos",label:"Cumpridos"}],
    nota:v=>{var P=v.previstos||0;if(!P)return null;return Math.min(100,Math.round((v.cumpridos||0)/P*100));},
    detail:v=>{var P=v.previstos||0;return P?((v.cumpridos||0)+" de "+P+" compromissos"):"";}},
   {key:"bloqueios",label:"Bloqueios indevidos na agenda (penalidade)",inputs:[{k:"pct",label:"% de carga horária perdida"}],
    nota:v=>{if(v.pct===""||v.pct==null)return null;return Math.max(0,Math.round(100-(+v.pct)));},
    detail:v=>{if(v.pct===""||v.pct==null)return "";return v.pct+"% da carga horária perdida com bloqueios";}},
   {key:"equipe",label:"Avaliações trazidas pela equipe (meta 4/sem)",inputs:[{k:"n",label:"Avaliações da equipe no mês"}],
    nota:v=>{if(v.n===""||v.n==null)return null;return Math.min(100,Math.round((+v.n)/16*100));},
    detail:v=>{if(v.n===""||v.n==null)return "";return v.n+" avaliações pela equipe (meta ≈16/mês)";}},
   {key:"comentarios",label:"Comentários nas redes respondidos",inputs:[{k:"total",label:"Comentários"},{k:"resp",label:"Respondidos"}],
    nota:v=>{var T=v.total||0;if(!T)return null;return Math.min(100,Math.round((v.resp||0)/T*100));},
    detail:v=>{var T=v.total||0;return T?((v.resp||0)+" de "+T+" comentários respondidos"):"";}},
   {key:"interacao",label:"Avaliações de interação nas redes (meta 1/sem)",inputs:[{k:"n",label:"Avaliações via interação no mês"}],
    nota:v=>{if(v.n===""||v.n==null)return null;return Math.min(100,Math.round((+v.n)/4*100));},
    detail:v=>{if(v.n===""||v.n==null)return "";return v.n+" avaliações via interação (meta ≈4/mês)";}}
 ]},
 recompra:{label:"Recompra",funcs:[
   {key:"altas",label:"Altas realizadas (meta ≥30/mês)",inputs:[{k:"n",label:"Altas no mês"}],
    nota:v=>{if(v.n===""||v.n==null)return null;return Math.min(100,Math.round((+v.n)/30*100));},
    detail:v=>{if(v.n===""||v.n==null)return "";return v.n+" altas (meta 30/mês)";}},
   {key:"venda",label:"Venda nas altas + reavaliações (meta ≥70%)",inputs:[{k:"base",label:"Altas + reavaliações"},{k:"vendas",label:"Geraram venda nova"}],
    nota:v=>{var B=v.base||0;if(!B)return null;return Math.min(100,Math.round(((v.vendas||0)/B*100)/70*100));},
    detail:v=>{var B=v.base||0;if(!B)return "";var pct=Math.round((v.vendas||0)/B*100);return (v.vendas||0)+" de "+B+" com venda ("+pct+"%, meta 70%)";}},
   {key:"disparos",label:"Disparos de recompra — avaliador+relacionamento (meta ≥30/mês)",inputs:[{k:"n",label:"Disparos de recompra no mês"}],
    nota:v=>{if(v.n===""||v.n==null)return null;return Math.min(100,Math.round((+v.n)/30*100));},
    detail:v=>{if(v.n===""||v.n==null)return "";return v.n+" disparos de recompra (meta 30/mês)";}},
   {key:"protesista",label:"Ação/bonificação da equipe de protesistas",neutro:true,inputs:[{k:"ativo",label:"Há ação/bonificação ativa?",sel:[["sim","Sim"],["nao","Não"]]}],
    nota:v=>v.ativo==="sim"?100:v.ativo==="nao"?0:null,
    detail:v=>v.ativo==="sim"?"Ativa":v.ativo==="nao"?"Sem ação":""}
 ]}
};
```

### Descrições (o `CRIT` — critério de cada função, texto que aparece na tela)

```javascript
var CRIT={
 "parcelamento.conf":"Meta = manter cada contrato dentro do teto da praça. Cada contrato acima do teto tira 5; se o planejamento não justificar (prazo de recebimento incompatível com a entrega), tira 10 (o dobro).",
 "resgate30.contatos":"O relacionamento deve fazer ≥10 contatos/dia, registrados no sistema. Nota = (média/dia ÷ 10). Se não estiver registrado, a nota é 0 — a cobrança é conjunta (avaliador + relacionamento).",
 "resgate30.videos":"O doutor deve gravar ≥5 vídeos para pacientes de resgate no período. Nota = (vídeos feitos ÷ 5).",
 "resgate30.entusiasmo":"Qualidade da abordagem do relacionamento (tom/entusiasmo), monitorada via consultores/Marilda até ter CRM. Bom=100, Regular=50, Ruim=0.",
 "ticket.ia":"Uso da ferramenta de IA nas avaliações. Meta ≥80% das avaliações. Nota = (uso% ÷ 80%).",
 "ticket.oferta":"Ofereceu ao paciente tudo que ele poderia comprar? Nota = (ofertas completas + metade das parciais) ÷ avaliações analisadas.",
 "ticket.esteticos":"Nos casos estéticos, usou foto + IA de antes-e-depois? Nota = (casos com antes-e-depois ÷ casos estéticos).",
 "conversao.gravacoes":"O avaliador deve te enviar ≥10 gravações de avaliações no período, para embasar a análise da venda. Nota = (gravações enviadas ÷ 10). É a única função com peso hoje.",
 "conversao.storytelling":"Como o avaliador conduz o storytelling da venda. Só fica assertivo com o Ovix Pro (em instalação). NEUTRO por enquanto — sem peso; marque de referência.",
 "conversao.negociacao":"Como é feita a negociação na hora do orçamento. Via Ovix Pro. NEUTRO por enquanto — sem peso.",
 "conversao.abordagem":"Abordagem/condução do dentista na avaliação. Via Ovix Pro. NEUTRO por enquanto — sem peso.",
 "conversao.score":"Uso da análise de score do paciente para apoiar a conversão. NEUTRO por enquanto — sem peso.",
 "entrada.gravacoes":"O avaliador deve te enviar ≥10 gravações de avaliações no período (o Ovix Pro traz a mesma base da conversão). Nota = (gravações enviadas ÷ 10). Única função com peso hoje.",
 "entrada.storytelling":"Storytelling na venda/entrada. Via Ovix Pro. NEUTRO por enquanto — sem peso.",
 "entrada.negociacao":"Negociação no orçamento/entrada. Via Ovix Pro. NEUTRO por enquanto — sem peso.",
 "entrada.abordagem":"Abordagem do dentista na entrada. Via Ovix Pro. NEUTRO por enquanto — sem peso.",
 "entrada.score":"Análise de score do paciente para apoiar a entrada. NEUTRO por enquanto — sem peso.",
 "avaliacoes.videos":"Entregou os vídeos solicitados (marketing + captação/cadência)? Nota = (enviados ÷ solicitados).",
 "avaliacoes.presenca":"Participou dos compromissos de presença ativa (reuniões de marketing, rádio da semana)? Nota = (cumpridos ÷ previstos).",
 "avaliacoes.bloqueios":"Bloqueios na agenda de avaliação fora do combinado prejudicam o resultado. Penalidade: Nota = 100 − % da carga horária perdida.",
 "avaliacoes.equipe":"Avaliações trazidas por indicação da equipe (na cadeira). Meta 4/semana (≈16/mês). Nota = (nº ÷ 16).",
 "avaliacoes.comentarios":"Os comentários nas redes estão sendo respondidos no período? Nota = (respondidos ÷ comentários).",
 "avaliacoes.interacao":"Avaliações que vieram de interação da equipe com quem curtiu/seguiu (Insta/Face). Meta 1/semana (≈4/mês). Nota = (nº ÷ 4).",
 "recompra.altas":"Quantidade de altas realizadas. Meta ≥30/mês (10 por reunião). Nota = (altas ÷ 30).",
 "recompra.venda":"Das altas + reavaliações, quantas geraram venda nova. Mínimo aceitável 70%. Nota = (%venda ÷ 70%).",
 "recompra.disparos":"Disparos (vídeos/áudios) do avaliador + relacionamento para clientes, para RECOMPRA (não resgate). Meta ≥30/mês (10 por reunião). Nota = (disparos ÷ 30).",
 "recompra.protesista":"Existe ação/bonificação interna da equipe de protesistas para sustentar as altas? NEUTRO por enquanto — sem peso; marque de referência."
};
```

---

## 6. Banco de dados (Supabase / Postgres)

Modelo de dados. `resultados` guarda o realizado × meta por indicador/diretor/mês (fonte Torre/Giga); `reunioes` + `checagens` guardam a pauta gravada e o que foi feito por demanda; as *views* fazem o cruzamento aderência × resultado ("não fez × não bateu").

Observações importantes de calibração:
- `indicadores.sentido` = `'maior_melhor'` (bate se realizado ≥ meta) ou `'teto'` (bom se realizado ≤ meta; só o `parcelamento`).
- Em `resultados`, para o indicador `teto`, `meta` é o **limite** que não pode ser ultrapassado.
- `demandas` são os itens da pauta (5–7 por indicador); `checagens` marca cada uma como `feito` / `parcial` / `nao`. Aderência = `(feito×peso + parcial×peso×0,5) / Σpeso`. **Peso igual** (todos = 1).

```sql
-- ENUMS
create type status_checagem as enum ('feito','parcial','nao');
create type status_reuniao  as enum ('rascunho','concluida');

-- Clínicas e diretores (sócios)
create table clinicas (
  id uuid primary key default gen_random_uuid(),
  nome text not null, praca text, uf text,
  ativo boolean not null default true, criado_em timestamptz not null default now());

create table diretores (
  id uuid primary key default gen_random_uuid(),
  nome text not null, clinica_id uuid references clinicas(id) on delete set null,
  email text, ativo boolean not null default true, criado_em timestamptz not null default now());

-- Os 8 indicadores
create table indicadores (
  id uuid primary key default gen_random_uuid(),
  chave text not null unique,               -- faturamento, recompra, entrada, avaliacoes, conversao, ticket, resgate30, parcelamento
  nome text not null, ordem int not null default 0,
  sentido text not null default 'maior_melhor',  -- 'maior_melhor' | 'teto'
  descricao text);

-- Demandas (pauta) — 5 a 7 por indicador
create table demandas (
  id uuid primary key default gen_random_uuid(),
  indicador_id uuid not null references indicadores(id) on delete cascade,
  ordem int not null default 0, titulo text not null, descricao text,
  peso numeric not null default 1, ativo boolean not null default true);

-- Reuniões (pauta gravada por diretor)
create table reunioes (
  id uuid primary key default gen_random_uuid(),
  diretor_id uuid not null references diretores(id) on delete cascade,
  data date not null default current_date, video_url text,
  status status_reuniao not null default 'rascunho', resumo text,
  criado_por text, criado_em timestamptz not null default now());

-- Checagens (reunião × demanda → feito/parcial/nao)
create table checagens (
  id uuid primary key default gen_random_uuid(),
  reuniao_id uuid not null references reunioes(id) on delete cascade,
  demanda_id uuid not null references demandas(id) on delete cascade,
  status status_checagem not null default 'nao', nota text,
  unique (reuniao_id, demanda_id));

-- Resultados (indicador × diretor × competência; fonte: Torre/Giga)
create table resultados (
  id uuid primary key default gen_random_uuid(),
  diretor_id uuid not null references diretores(id) on delete cascade,
  indicador_id uuid not null references indicadores(id) on delete cascade,
  competencia text not null,                -- 'YYYY-MM'
  meta numeric,      -- para 'teto' (parcelamento) = o LIMITE que não pode passar
  realizado numeric, projecao numeric,
  atualizado_em timestamptz not null default now(),
  unique (diretor_id, indicador_id, competencia));
```

### View de cruzamento (aderência × resultado)

```sql
-- Aderência por indicador na última reunião concluída de cada diretor
create or replace view v_aderencia_indicador as
with ult as (
  select distinct on (diretor_id) id as reuniao_id, diretor_id, data
  from reunioes where status = 'concluida'
  order by diretor_id, data desc)
select u.diretor_id, u.reuniao_id, u.data as data_reuniao, d.indicador_id,
  count(*) as total_demandas,
  count(*) filter (where c.status='feito')   as feitas,
  count(*) filter (where c.status='parcial') as parciais,
  count(*) filter (where c.status='nao')     as nao_feitas,
  round(sum(case c.status when 'feito' then d.peso when 'parcial' then d.peso*0.5 else 0 end)
        / nullif(sum(d.peso),0) * 100, 0)    as aderencia_pct
from ult u
join checagens c on c.reuniao_id = u.reuniao_id
join demandas  d on d.id = c.demanda_id
group by u.diretor_id, u.reuniao_id, u.data, d.indicador_id;

-- Dashboard: cruza aderência × resultado → leitura 'nao_fez_nao_bateu' / 'fez_bateu' / 'ok'
create or replace view v_dashboard_diretor as
select di.id as diretor_id, di.nome as diretor, cl.nome as clinica,
  ind.chave as indicador_chave, ind.nome as indicador, ind.ordem as indicador_ordem,
  a.aderencia_pct, a.total_demandas, a.feitas, a.nao_feitas, ind.sentido,
  r.competencia, r.meta, r.realizado, r.projecao,
  (case when r.meta is null or r.realizado is null then null
        when ind.sentido='teto' then r.realizado <= r.meta
        else r.realizado >= r.meta end) as atingiu,
  case
    when (case when ind.sentido='teto' then r.realizado<=r.meta else r.realizado>=r.meta end) is false
         and coalesce(a.aderencia_pct,0) < 60 then 'nao_fez_nao_bateu'
    when (case when ind.sentido='teto' then r.realizado<=r.meta else r.realizado>=r.meta end) is true
         and coalesce(a.aderencia_pct,0) >= 60 then 'fez_bateu'
    else 'ok' end as leitura
from diretores di
join clinicas cl on cl.id = di.clinica_id
cross join indicadores ind
left join v_aderencia_indicador a on a.diretor_id=di.id and a.indicador_id=ind.id
left join lateral (select * from resultados r2
  where r2.diretor_id=di.id and r2.indicador_id=ind.id
  order by r2.competencia desc limit 1) r on true
order by di.nome, ind.ordem;
```

### Seed dos 8 indicadores

```sql
insert into indicadores (chave, nome, ordem, sentido, descricao) values
 ('faturamento',  'Faturamento',       1, 'maior_melhor','Faturamento bruto da unidade no mês.'),
 ('recompra',     'Recompra',          2, 'maior_melhor','Faturamento vindo de pacientes da base (reaval/retorno/acréscimo/resgate).'),
 ('entrada',      'Entrada',           3, 'maior_melhor','Entrada de caixa das vendas.'),
 ('avaliacoes',   'Avaliações',        4, 'maior_melhor','Quantidade de avaliações realizadas no mês.'),
 ('conversao',    'Conversão',         5, 'maior_melhor','Dos que compareceram, quantos fecharam.'),
 ('ticket',       'Ticket médio',      6, 'maior_melhor','Valor médio por avaliação fechada.'),
 ('resgate30',    'Resgate 30+',       7, 'maior_melhor','Vendas resgatadas de pacientes com 30+ dias (Vlr 30+).'),
 ('parcelamento', 'Parcelamento médio',8, 'teto',        'Parcelamento médio ponderado. É um LIMITE (teto): quanto menor, melhor.')
on conflict (chave) do update set nome=excluded.nome, ordem=excluded.ordem, sentido=excluded.sentido, descricao=excluded.descricao;
```

As **demandas** (pauta) de cada indicador e o seed de exemplo estão no arquivo `db/setup_completo.sql` do projeto — se a outra IA precisar da pauta completa, cole aquele arquivo também. O essencial para a lógica de notas é o que está acima.

---

## 7. O que eu quero que você (outra IA) faça

Já está tudo calibrado acima — **não recomece do zero.** Trabalhe assim:

1. **Assuma este modelo como base.** Os 8 indicadores, a regra-mãe (peso igual entre funções, nuance dentro da fórmula), as funções e fórmulas da seção 4/5, e o banco da seção 6 são o estado atual e correto.
2. Quando eu pedir para **ajustar/criar uma função nova**, mantenha o mesmo padrão do objeto `FUNCS`: `key`, `label`, `inputs` (com `sel` quando for escolha), `nota(v)` retornando **0–100 ou null**, `detail(v)`, e `neutro:true` quando a função ainda não deve pesar. Fórmula sempre clampada e arredondada.
3. **Não invente pesos diferentes** entre funções de um mesmo indicador. A gravidade mora na fórmula.
4. Quando envolver **resultado** (bateu meta?), respeite o `sentido`: `parcelamento` é **teto** (bom quando realizado ≤ meta); os demais batem quando realizado ≥ meta.
5. Toda regra nova deve refletir **operação real de clínica odontológica** (avaliador, relacionamento/SDR, dentista, recepção) — nada genérico.

Fim do pacote.
