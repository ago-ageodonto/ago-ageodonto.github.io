#!/usr/bin/env python3
import json, os, sys, urllib.request, urllib.error
SB=os.environ["SUPABASE_URL"].rstrip("/"); KEY=os.environ["SUPABASE_SERVICE_KEY"]
data=json.load(open("materiais/painel_data.json",encoding="utf-8"))
print("painel_data.json: %d chaves"%len(data))
body=json.dumps([{"id":"main","data":data}]).encode("utf-8")
req=urllib.request.Request(SB+"/rest/v1/painel_blob?on_conflict=id",data=body,method="POST",
  headers={"apikey":KEY,"Authorization":"Bearer "+KEY,"Content-Type":"application/json",
           "Prefer":"resolution=merge-duplicates,return=minimal"})
try:
    with urllib.request.urlopen(req,timeout=120) as r: print("OK painel_blob gravado (HTTP %d)"%r.status)
except urllib.error.HTTPError as e:
    print("FALHA HTTP %d: %s"%(e.code,e.read().decode("utf-8","replace")),file=sys.stderr); sys.exit(1)
