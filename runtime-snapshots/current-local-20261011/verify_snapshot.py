from pathlib import Path
import hashlib,json,sys
root=Path(__file__).resolve().parent
expected=json.loads((root/'SHA256SUMS.json').read_text())
errors=[]
for rel,digest in expected.items():
 p=root/rel
 if not p.is_file() or hashlib.sha256(p.read_bytes()).hexdigest()!=digest:errors.append(rel)
actual={p.relative_to(root).as_posix() for p in root.rglob('*') if p.is_file() and p.name!='SHA256SUMS.json' and '__pycache__' not in p.parts}
extras=sorted(actual-set(expected))
print(json.dumps({'passed':not errors and not extras,'files_checked':len(expected),'missing_or_changed':errors,'unexpected_files':extras},ensure_ascii=False))
sys.exit(bool(errors or extras))
