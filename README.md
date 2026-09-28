# Ageodonto — Hub Comercial

Tudo que construímos, reunido pra você hospedar na **sua** conta: os materiais (dashboards) e o **Sistema de Gestão Comercial** (que usa o Supabase como banco).

- **`index.html`** — portal que abre tudo (a home do site).
- **`materiais/`** — dashboards prontos (páginas independentes, cada uma abre sozinha).
- **`sistema/`** — o Sistema de Gestão Comercial (páginas + banco Supabase em `sistema/db/`).
- **`docs/`** — documentação (inclui o pacote de calibração da IA).

Arranjo: **GitHub** (guarda o código) → **GitHub Pages** (publica o site, grátis) → **Supabase** (guarda os dados do sistema).

---

## Parte 0 — Os 3 cadastros (uma vez só)

1. **GitHub** — conta em https://github.com (é onde os arquivos ficam).
2. **Git no seu Mac** — abra o app **Terminal** e digite `git --version`. Se pedir pra instalar, aceite. (Alternativa sem terminal: **GitHub Desktop**, https://desktop.github.com — mais visual.)
3. **Supabase** — você já tem (projeto `pwbcehrfhspgipjhaedc`). Só precisamos rodar o banco uma vez (Parte 3).

---

## Parte 1 — Criar o repositório e subir os arquivos

### Caminho A — GitHub Desktop (mais fácil, recomendado pra você)

1. Abra o **GitHub Desktop** e faça login.
2. Menu **File → Add Local Repository** → aponte para esta pasta (`Ageodonto_GitHub`).
3. Ele vai avisar que "não é um repositório ainda" → clique em **create a repository** → **Create Repository**.
4. No topo, clique **Publish repository**. **Desmarque "Keep this code private" só se você quiser o site público** (veja a Parte 4 sobre o que é sensível). Recomendo deixar **privado** por enquanto.
5. Pronto — o código está no seu GitHub.

Sempre que mudar algo: abre o GitHub Desktop, escreve um resumo embaixo (ex.: "atualizei a torre"), clica **Commit to main** e depois **Push origin**.

### Caminho B — Terminal (se preferir a linha de comando)

```bash
cd "/Users/gregoriespoladorscarpeta/Library/Mobile Documents/com~apple~CloudDocs/Ageodonto_GitHub"
git init
git add .
git commit -m "Primeira versão: sistema + materiais"
```

Depois crie um repositório vazio em https://github.com/new (nome ex.: `ageodonto-hub`, sem README), e rode o que o GitHub mostrar na tela — algo como:

```bash
git remote add origin https://github.com/SEU_USUARIO/ageodonto-hub.git
git branch -M main
git push -u origin main
```

---

## Parte 2 — Publicar o site (GitHub Pages, grátis)

1. No GitHub, abra o repositório → **Settings** (aba de cima) → **Pages** (menu da esquerda).
2. Em **Source**, escolha **Deploy from a branch**; **Branch = main**, pasta **/(root)** → **Save**.
3. Espere ~1 minuto. O endereço aparece no topo: `https://SEU_USUARIO.github.io/ageodonto-hub/`.
4. Esse link abre o **`index.html`** (o portal). Cada material tem seu próprio endereço, ex.: `.../ageodonto-hub/materiais/torre_controle.html`.

> **Repositório privado + GitHub Pages:** no plano grátis, Pages de repositório **privado** fica com endereço público mesmo assim (quem tiver o link abre). Se precisar de site realmente fechado, use **Netlify** (Parte 5) com proteção por senha, ou mantenha os materiais sensíveis fora do repositório.

---

## Parte 3 — Ligar o Sistema de Gestão Comercial ao Supabase

O sistema (pasta `sistema/`) precisa do banco criado uma vez.

1. Entre no Supabase → seu projeto → **SQL Editor** → **New query**.
2. Abra o arquivo **`sistema/db/setup_completo.sql`**, copie **tudo**, cole no editor e clique **Run**. Isso cria as tabelas, os 8 indicadores, as demandas e um exemplo.
3. As páginas do sistema já vêm com a **URL do projeto** e a **chave publishable** (`sb_publishable_...`) — essa chave pode ficar no código do navegador, é segura. **Nunca** coloque no repositório a chave *secreta* (service_role): essa é só de servidor.
4. Abra `sistema/app/index.html` pelo site publicado e teste. Se aparecer os dados do exemplo (Dourados), está conectado.

> Se algum dia trocar de projeto Supabase, é só atualizar a URL e a chave publishable no topo dos arquivos `sistema/app/*.html`.

---

## Parte 4 — O que é público e o que é sensível (importante)

Este repositório foi montado **sem** dados pessoais/financeiros. Antes de deixar algo público, lembre:

- **Pode ser público:** dashboards agregados, o sistema (com a chave *publishable*).
- **Mantenha privado / fora do repo:** CFO pessoal, qualquer planilha com **CPF/nome de paciente**, contratos, valores individuais, e **qualquer chave secreta**.
- Regra prática: se você não colaria aquilo num grupo de WhatsApp aberto, não deixe num site público. Na dúvida, **repositório privado** já resolve 95% dos casos.

---

## Parte 5 — Alternativa: Netlify (opcional)

Se quiser publicação automática + senha no site:

1. Conta em https://netlify.com → **Add new site → Import from Git → GitHub** → escolha o repositório.
2. Build: deixe vazio (é site estático). **Publish directory = /** (raiz). **Deploy**.
3. Cada `push` no GitHub publica sozinho. Em **Site settings → Access control** dá pra pôr **senha**.
4. Você já usa Netlify no sistema hoje (`splendorous-bonbon-2cbf73`) — pode apontar esse mesmo site pro repositório.

---

## Como me pedir pra atualizar

Quando quiser um material novo ou uma correção, é só falar. Eu gero/atualizo o arquivo aqui na pasta; você dá **Commit + Push** (GitHub Desktop) e o site atualiza sozinho.

## O que ainda falta trazer pra cá

Alguns materiais antigos existem só publicados (no Claude) e não como arquivo. Quando quiser, eu baixo e adiciono na pasta `materiais/` (Cartão de Crédito, Painel de Resultados, Mapa de Calor, Faturamento por Bloco, campanhas por praça, etc.).
