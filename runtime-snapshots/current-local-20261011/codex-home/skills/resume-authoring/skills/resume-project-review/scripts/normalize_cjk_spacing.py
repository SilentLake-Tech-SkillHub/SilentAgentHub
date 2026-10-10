#!/usr/bin/env python3
"""Create a DOCX copy without CJK/Latin boundary spaces or automatic CJK spacing."""
import argparse,json,re,zipfile
from pathlib import Path
from lxml import etree as E
W='{http://schemas.openxmlformats.org/wordprocessingml/2006/main}'
GAPS=re.compile(r'(?<=[\u3400-\u9fff，。；：！？、（）《》「」])[ \u00a0]+(?=[A-Za-z0-9])|(?<=[A-Za-z0-9%])[ \u00a0]+(?=[\u3400-\u9fff，。；：！？、（）《》「」])')
FOLLOWERS=['bidi','adjustRightInd','snapToGrid','spacing','ind','contextualSpacing','mirrorIndents','suppressOverlap','jc','textDirection','textAlignment','textboxTightWrap','outlineLvl','divId','cnfStyle','rPr','sectPr','pPrChange']
def disable(pp):
 for name in ['autoSpaceDE','autoSpaceDN']:
  item=pp.find(W+name)
  if item is None:
   item=E.Element(W+name)
   successors=[W+x for x in (['autoSpaceDN'] if name=='autoSpaceDE' else [])+FOLLOWERS]
   pos=next((i for i,x in enumerate(pp) if x.tag in successors),len(pp));pp.insert(pos,item)
  item.set(W+'val','0')
def normalize(source,output):
 source=Path(source);output=Path(output)
 if source.resolve()==output.resolve() or output.exists():raise ValueError('Use a new output path; source and existing files are preserved.')
 count=0;changed=0;parts=0
 with zipfile.ZipFile(source) as zin,zipfile.ZipFile(output,'w') as zout:
  for info in zin.infolist():
   data=zin.read(info.filename)
   if re.fullmatch(r'word/(document|styles|header\d+|footer\d+|footnotes|endnotes)\.xml',info.filename):
    node=E.fromstring(data);parts+=1
    for para in node.iter(W+'p'):
     texts=list(para.iter(W+'t'));old=''.join(t.text or '' for t in texts)
     indices={i for m in GAPS.finditer(old) for i in range(m.start(),m.end())}
     offset=0
     for t in texts:
      s=t.text or '';t.text=''.join(ch for i,ch in enumerate(s,offset) if i not in indices);offset+=len(s)
     new=''.join(t.text or '' for t in texts)
     assert re.sub(r'\s+','',old)==re.sub(r'\s+','',new)
     assert not GAPS.search(new)
     count+=len(indices);changed+=bool(indices)
     pp=para.find(W+'pPr')
     if pp is None:pp=E.Element(W+'pPr');para.insert(0,pp)
     disable(pp)
    if info.filename=='word/styles.xml':
     default=node.find(W+'docDefaults')
     if default is None:default=E.Element(W+'docDefaults');node.insert(0,default)
     pd=default.find(W+'pPrDefault')
     if pd is None:pd=E.SubElement(default,W+'pPrDefault')
     pp=pd.find(W+'pPr')
     if pp is None:pp=E.SubElement(pd,W+'pPr')
     for pp in list(node.iter(W+'pPr')):disable(pp)
    data=E.tostring(node,encoding='UTF-8',xml_declaration=True,standalone=True)
   zout.writestr(info,data)
 return {'removed_spaces':count,'changed_paragraphs':changed,'processed_parts':parts,'automatic_spacing_disabled':True}
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--input',required=True,type=Path);p.add_argument('--output',required=True,type=Path);a=p.parse_args();print(json.dumps(normalize(a.input,a.output),ensure_ascii=False))
if __name__=='__main__':main()
