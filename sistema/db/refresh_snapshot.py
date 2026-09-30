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

body = json.dumps(rows).encode("utf-8")
req = urllib.request.Request(
    SB + "/rest/v1/torre_snapshot?on_conflict=slug",
    data=body, method="POST",
    headers={"apikey": KEY, "Authorization": "Bearer " + KEY,
             "Content-Type": "application/json",
             "Prefer": "resolution=merge-duplicates,return=minimal"})
with urllib.request.urlopen(req, timeout=60) as r:
    print("OK %d praças gravadas (HTTP %d)" % (len(rows), r.status))
