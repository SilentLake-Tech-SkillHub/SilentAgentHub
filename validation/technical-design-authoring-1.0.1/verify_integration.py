#!/usr/bin/env python3
"""Verify the technical-design integration's affected files; no network or mutation."""
from pathlib import Path
import argparse, json, hashlib, re

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()

def main():
    a=argparse.ArgumentParser()
    a.add_argument("--source",type=Path,required=True)
    a.add_argument("--codex-home",type=Path,required=True)
    a.add_argument("--output",type=Path)
    args=a.parse_args(); source=args.source; local=args.codex_home
    package=source/"harness/V5.2.5"
    pointer=json.loads((local/"harness/current.json").read_text())
    installed=Path(pointer["packageRoot"])
    result={"scope":"five affected Skills, root rules and affected manifest entries", "skill_files":[],"references":[],"root_copies":5}
    root=source/"core/AGENTS.md"
    for p in [source/"core/CLAUDE.md",package/"AGENTS.md",local/"AGENTS.md",installed/"AGENTS.md"]:
        assert p.read_bytes()==root.read_bytes(), f"root divergence: {p}"
    assert pointer["agentsSha256"]==digest(root)
    manifest_paths=["AGENTS.md"]
    names=["technical-design-authoring","workflow-orchestrator","skill-library-router","harness-router","plan-orchestrator"]
    for name in names:
        folder=next((source/"skills").glob("*】"+name))
        for p in sorted(folder.rglob("*")):
            if not p.is_file(): continue
            rel=p.relative_to(folder); h=digest(p)
            for other in [package/"skills-source"/name/rel,local/"skills"/name/rel,installed/"skills-source"/name/rel]:
                assert digest(other)==h, f"copy mismatch: {name}/{rel}"
            manifest_paths.append("skills-source/"+name+"/"+str(rel))
            result["skill_files"].append({"skill":name,"file":str(rel),"sha256":h,"copies":4})
            if p.suffix==".md":
                for link in re.findall(r"\]\(([^)]+)\)",p.read_text()):
                    if "://" in link or link.startswith("#"): continue
                    target=p.parent/link.split("#")[0]
                    assert target.exists(), f"missing reference: {name}/{rel} -> {link}"
                    result["references"].append({"from":name+"/"+str(rel),"to":link})
    for base in [package,installed]:
        m=json.loads((base/"manifest.json").read_text()); entries={x["path"]:x for x in m["files"]}
        for p in manifest_paths:
            entry=entries[p]; path=base/p
            assert entry["sha256"].upper()==digest(path), f"manifest mismatch: {p}"
            assert entry["bytes"]==path.stat().st_size
        assert m["agentsSha256"]==digest(root)
    result["affected_manifest_entries"]=len(manifest_paths)
    result["paid_calls"]=0
    result["passed"]=True
    if args.output: args.output.write_text(json.dumps(result,ensure_ascii=False,indent=2)+"\n")
    print(json.dumps({"passed":True,"skill_files":len(result["skill_files"]),"four_copy_comparisons":len(result["skill_files"])*4,"roots":5,"manifest_entries_per_package":len(manifest_paths)},ensure_ascii=False))

if __name__=="__main__":main()
