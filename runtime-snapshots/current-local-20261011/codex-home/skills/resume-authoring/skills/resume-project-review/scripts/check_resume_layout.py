#!/usr/bin/env python3
"""Read-only DOCX layout preflight. JSON output contains positions, not private text."""
import argparse,json,re,zipfile
from pathlib import Path
from xml.etree import ElementTree as E
W="{http://schemas.openxmlformats.org/wordprocessingml/2006/main}"
def audit(path):
    with zipfile.ZipFile(path) as z:
        doc=E.fromstring(z.read("word/document.xml"));styles=E.fromstring(z.read("word/styles.xml"))
    catalog={s.get(W+"styleId"):s for s in styles.findall(W+"style")}
    default=next((s.get(W+"styleId") for s in styles.findall(W+"style") if s.get(W+"type")=="paragraph" and s.get(W+"default")=="1"),None)
    defaults=styles.find(W+"docDefaults")
    def chain(style_id):
        result=[];seen=set()
        while style_id and style_id not in seen:
            seen.add(style_id);s=catalog.get(style_id)
            if s is None:break
            result.append(s);base=s.find(W+"basedOn");style_id=base.get(W+"val") if base is not None else None
        return result
    def prop(groups,name,attr):
        for g in groups:
            n=g.find(W+name) if g is not None else None
            if n is not None and n.get(W+attr) is not None:return n.get(W+attr)
        return None
    body=doc.find(W+"body");pars=body.findall(W+"p");last=body.find(W+"sectPr")
    sections=[(i,p.find(W+"pPr/"+W+"sectPr")) for i,p in enumerate(pars) if p.find(W+"pPr/"+W+"sectPr") is not None]
    errors=[];dates=[];checked=0
    for i,p in enumerate(pars):
        pp=p.find(W+"pPr");ps=pp.find(W+"pStyle") if pp is not None else None
        sid=ps.get(W+"val") if ps is not None else default;cs=chain(sid)
        pgroups=[pp]+[s.find(W+"pPr") for s in cs]+[defaults.find(W+"pPrDefault/"+W+"pPr") if defaults is not None else None]
        line=prop(pgroups,"spacing","line");rule=prop(pgroups,"spacing","lineRule")
        max_size=0
        for run in p.findall(".//"+W+"r"):
            if not run.findall(".//"+W+"t"):continue
            rp=run.find(W+"rPr");rs=rp.find(W+"rStyle") if rp is not None else None
            rcs=chain(rs.get(W+"val")) if rs is not None else []
            groups=[rp]+[s.find(W+"rPr") for s in rcs+cs]+[defaults.find(W+"rPrDefault/"+W+"rPr") if defaults is not None else None]
            size=prop(groups,"sz","val");max_size=max(max_size,float(size or 22)/2)
        if rule=="exact" and line and max_size>int(line)/20:
            errors.append({"kind":"fixed_line_height_below_run_size","paragraph":i,"line_pt":int(line)/20,"max_run_pt":max_size})
        checked+=1;text="".join(t.text or "" for t in p.iter(W+"t"))
        if not p.findall(".//"+W+"tab") or not re.search(r"\b(?:19|20)\d{2}\.\d{2}",text):continue
        sect=next((s for end,s in sections if i<=end),last)
        if sect is None:errors.append({"kind":"missing_section_geometry","paragraph":i});continue
        sz=sect.find(W+"pgSz");mar=sect.find(W+"pgMar")
        width=int(sz.get(W+"w"))-sum(int(mar.get(W+k,"0")) for k in ["left","right","gutter"])
        expected=width-int(prop(pgroups,"ind","right") or 0)
        tabs=next((g.find(W+"tabs") for g in pgroups if g is not None and g.find(W+"tabs") is not None),None)
        positions=[int(t.get(W+"pos")) for t in list(tabs or []) if t.get(W+"val")=="right"]
        dates.append({"paragraph":i,"expected_twips":expected,"right_tabs":positions})
        if expected not in positions:errors.append({"kind":"date_right_tab_mismatch","paragraph":i,"expected_twips":expected,"actual":positions})
        if text.endswith(" "):errors.append({"kind":"date_trailing_alignment_space","paragraph":i})
    return {"passed":not errors,"checked_paragraphs":checked,"dates":dates,"errors":errors,"visual_review_required":True}
def main():
    parser=argparse.ArgumentParser();parser.add_argument("--docx",required=True);parser.add_argument("--output");args=parser.parse_args()
    result=audit(args.docx);data=json.dumps(result,ensure_ascii=False,indent=2)
    if args.output:Path(args.output).write_text(data+"\n",encoding="utf-8")
    print(data);raise SystemExit(0 if result["passed"] else 1)
if __name__=="__main__":main()
