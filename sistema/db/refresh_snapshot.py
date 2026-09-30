#!/usr/bin/env python3
"""Regrava a 'foto' torre_snapshot (Torre por praça) a partir de materiais/torre_controle.html.
Roda no GitHub Actions após cada atualização da Torre. Usa a service_role key (secret do repo),
que ignora RLS e pode escrever. NÃO expõe nada — roda no servidor do GitHub."""
import json, re, os, unicodedata, urllib.request, sys

SB = os.environ["SUPABASE_URL"].rstrip("/")
KEY = os.environ["SUPABASE_SERVICE_KEY"]
SRC = "materiais/torre_controle.html"

html = open(SRC, encoding="utf-8").read()
i = html.index("var D="); j = i + len("var D=")
assert html[j] == "{"
depth = 0; k = j; instr = False; esc = False
while k < len(html):
    c = html[k]
    if instr:
        if esc: esc = False
        elif c == "\\": esc = True
        elif c == '"': instr = False
    else:
        if c == '"': instr = True
        elif c == "{": depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0:
                k += 1; break
    k += 1
D = json.loads(html[j:k])

def slug(nm):
    s = unicodedata.normalize("NFKD", nm).encode("ascii", "ignore").decode()
    return re.sub(r"[^a-zA-Z0-9]+", "-", s).strip("-").lower()

INDK = [x["k"] for x in D["ind"]]
rows = []
for p in D["pracas"]:
    if p.get("src") != "live":
        continue
    m = p["m"]
    ref = p.get("ref", "")
    mes = ref.split("·")[0].strip() if "·" in ref else (ref or "")
    dados = {"nome": p["u"], "ref": ref, "mes": mes, "dia": D.get("dia"), "dias": D.get("dias"),
             "ind": {key: [m[key].get("meta"), m[key].get("real"), m[key].get("proj"),
                           m[key].get("pct"), m[key].get("farol", "na")] for key in INDK}}
    rows.append({"slug": slug(p["u"]), "nome": p["u"], "dados": dados})

if not rows:
    print("Nenhuma praça live encontrada — abortando sem escrever.", file=sys.stderr)
    sys.exit(1)

ktype = ("vazio" if not KEY else
         "sb_secret (correta)" if KEY.startswith("sb_secret_") else
         "sb_publishable (ERRADA - e a publica)" if KEY.startswith("sb_publishable_") else
         "jwt/legacy service_role" if KEY.startswith("eyJ") else
         "desconhecida")
print("Lidas %d praças de %s. SUPABASE_URL=%s. Chave: tipo=%s, tamanho=%d."
      % (len(rows), SRC, SB, ktype, len(KEY or "")))

body = json.dumps(rows).encode("utf-8")
req = urllib.request.Request(
    SB + "/rest/v1/torre_snapshot?on_conflict=slug",
    data=body, method="POST",
    headers={"apikey": KEY, "Authorization": "Bearer " + KEY,
             "Content-Type": "application/json",
             "Prefer": "resolution=merge-duplicates,return=minimal"})
try:
    with urllib.request.urlopen(req, timeout=60) as r:
        print("OK %d praças gravadas (HTTP %d)" % (len(rows), r.status))
except urllib.error.HTTPError as e:
    detail = e.read().decode("utf-8", "replace")
    print("FALHA HTTP %d ao gravar torre_snapshot:\n%s" % (e.code, detail), file=sys.stderr)
    sys.exit(1)
except Exception as e:
    print("FALHA: %r" % (e,), file=sys.stderr)
    sys.exit(1)

# 2) Torre COMPLETA (D inteiro) -> painel_blob id='torre' (a Torre logada lê daqui)
tbody = json.dumps([{"id": "torre", "data": {"D": D}}]).encode("utf-8")
treq = urllib.request.Request(
    SB + "/rest/v1/painel_blob?on_conflict=id",
    data=tbody, method="POST",
    headers={"apikey": KEY, "Authorization": "Bearer " + KEY,
             "Content-Type": "application/json",
             "Prefer": "resolution=merge-duplicates,return=minimal"})
try:
    with urllib.request.urlopen(treq, timeout=60) as r:
        print("OK Torre completa gravada em painel_blob:torre (HTTP %d)" % r.status)
except urllib.error.HTTPError as e:
    print("FALHA HTTP %d ao gravar painel_blob:torre:\n%s" % (e.code, e.read().decode("utf-8","replace")), file=sys.stderr)
    sys.exit(1)

# 3) Alimentar resultados (Rede / Visão Geral) das clínicas cadastradas na plataforma
def _norm(s):
    s = unicodedata.normalize("NFKD", s or "").encode("ascii", "ignore").decode().lower()
    s = s.replace("oral unic", "").strip()
    s = re.sub(r"\s+", " ", s)
    s = s.replace("campo grande 2", "campo grande ii").replace("campo grande 02", "campo grande ii")
    return s
def _gget(path):
    rq = urllib.request.Request(SB + "/rest/v1/" + path,
        headers={"apikey": KEY, "Authorization": "Bearer " + KEY})
    with urllib.request.urlopen(rq, timeout=60) as r:
        return json.loads(r.read().decode("utf-8"))
try:
    indmap = {i["chave"]: i["id"] for i in _gget("indicadores?select=id,chave")}
    cli_by_id = {c["id"]: c["nome"] for c in _gget("clinicas?select=id,nome")}
    dir_by_norm = {}
    for d in _gget("diretores?select=id,clinica_id"):
        nm = cli_by_id.get(d["clinica_id"])
        if nm:
            dir_by_norm.setdefault(_norm(nm), d["id"])
    MES = {"jan":"01","fev":"02","mar":"03","abr":"04","mai":"05","jun":"06","jul":"07","ago":"08","set":"09","out":"10","nov":"11","dez":"12"}
    comp = None
    for p in D["pracas"]:
        m = re.match(r"\s*([A-Za-zç]{3})/(\d{2})", p.get("ref",""))
        if m:
            comp = "20" + m.group(2) + "-" + MES.get(m.group(1).lower()[:3], "01"); break
    IMAP = {"fat":"faturamento","recompra":"recompra","entrada":"entrada","aval":"avaliacoes","conv":"conversao","tk":"ticket","d30":"resgate30","parc":"parcelamento"}
    res = []
    for p in D["pracas"]:
        if p.get("src") != "live": continue
        did = dir_by_norm.get(_norm(p["u"]))
        if not did: continue
        mm = p["m"]
        for tk, chave in IMAP.items():
            iid = indmap.get(chave)
            if not iid: continue
            node = mm.get(tk, {})
            meta = node.get("meta"); real = node.get("real")
            proj = node.get("proj")
            if proj is None: proj = real
            if chave == "conversao":
                meta = meta*100 if meta is not None else None
                real = real*100 if real is not None else None
                proj = proj*100 if proj is not None else None
            res.append({"diretor_id":did,"indicador_id":iid,"competencia":comp,"meta":meta,"realizado":real,"projecao":proj})
    if res and comp:
        rb = json.dumps(res).encode("utf-8")
        rq = urllib.request.Request(SB + "/rest/v1/resultados?on_conflict=diretor_id,indicador_id,competencia",
            data=rb, method="POST",
            headers={"apikey": KEY, "Authorization": "Bearer " + KEY, "Content-Type": "application/json",
                     "Prefer": "resolution=merge-duplicates,return=minimal"})
        with urllib.request.urlopen(rq, timeout=60) as r:
            n_cli = len(set(x["diretor_id"] for x in res))
            print("OK resultados (Rede/Visão Geral): %d linhas, %d clínicas, competência %s" % (len(res), n_cli, comp))
    else:
        print("resultados: nada a gravar (comp=%s, casaram=%d)" % (comp, len(res)))
except Exception as e:
    print("AVISO: falhou ao alimentar resultados (Torre não é afetada): %r" % (e,), file=sys.stderr)
