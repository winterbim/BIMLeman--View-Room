#!/usr/bin/env python3
"""Prepare a native Veyon Master rebrand. Fail closed on unrecognized source trees."""
from pathlib import Path
import argparse, re, shutil, sys, json
p=argparse.ArgumentParser()
p.add_argument("--source",required=True)
p.add_argument("--logo",required=True)
p.add_argument("--report",required=True)
a=p.parse_args()
root=Path(a.source).resolve()
logo=Path(a.logo).resolve()
assert root.is_dir() and logo.is_file()
master=root/"master"
if not master.is_dir():
    raise SystemExit("STOP: Veyon source tree has no master/ directory")
# Only native UI text; leave protocol, settings, service, translation keys, and licensing untouched.
changes=[]
for file in master.rglob("*"):
    if not file.is_file() or file.suffix.lower() not in {".cpp",".h",".ui",".rc",".qrc"}:continue
    raw=file.read_bytes()
    if b"\x00" in raw:continue
    try: src=raw.decode("utf-8")
    except UnicodeDecodeError:continue
    out=src
    for old,new in [("Veyon Master","BIMLéman View Room"),("Veyon master","BIMLéman View Room")]:
        out=out.replace(old,new)
    if out!=src:
        file.write_text(out,encoding="utf-8")
        changes.append({"path":str(file.relative_to(root)),"count":sum(src.count(x) for x in ["Veyon Master","Veyon master"])})
# Do not replace icons by filename guessing: inspect upstream resource references first.
images=[]
for file in master.rglob("*"):
    if file.is_file() and file.suffix.lower() in {".png",".svg",".ico",".qrc"}:
        images.append(str(file.relative_to(root)))
report={"status":"REVIEW_REQUIRED","title_changes":changes,"master_resources":images,"logo":logo.name,
"remaining_work":"Identify native Master icon and splash references; replace exact resources and validate Qt build before installer release."}
Path(a.report).write_text(json.dumps(report,indent=2,ensure_ascii=False),encoding="utf-8")
print(json.dumps(report,indent=2,ensure_ascii=False))
if not changes:
    raise SystemExit("STOP: no verified Master title strings found; upstream source needs review")
