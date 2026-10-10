#!/usr/bin/env python3
"""Check DOCX encoding/markup and optional approved/rendered text without modifying files."""
import argparse,json,re,sys,zipfile
from pathlib import Path
from collections import Counter
from xml.etree import ElementTree as ET

W='{http://schemas.openxmlformats.org/wordprocessingml/2006/main}'
R='{http://schemas.openxmlformats.org/package/2006/relationships}'
def norm(text):
    return re.sub(r'\s+','',text).replace('\u00ad','')
CJK_LATIN_SPACES=re.compile(r'(?<=[\u3400-\u9fff，。；：！？、（）《》「」])[ \u00a0]+(?=[A-Za-z0-9])|(?<=[A-Za-z0-9%])[ \u00a0]+(?=[\u3400-\u9fff，。；：！？、（）《》「」])')

def check(docx,approved=None,rendered=None,no_cjk_latin_spaces=False):
    errors=[];warnings=[];fonts=Counter()
    with zipfile.ZipFile(docx) as z:
        bad=z.testzip()
        if bad:errors.append({'kind':'zip_integrity','member':bad})
        xml=z.read('word/document.xml').decode('utf-8',errors='strict')
        doc=ET.fromstring(xml)
        paragraphs=[''.join(n.text or '' for n in p.iter(W+'t')) for p in doc.iter(W+'p')]
        for name in ['word/document.xml','word/styles.xml']:
            node=ET.fromstring(z.read(name).decode('utf-8',errors='strict'))
            for f in node.iter(W+'rFonts'):
                if f.get(W+'eastAsia'):fonts[f.get(W+'eastAsia')]+=1
        targets=[]
        if 'word/_rels/document.xml.rels' in z.namelist():
            rel=ET.fromstring(z.read('word/_rels/document.xml.rels').decode('utf-8',errors='strict'))
            targets=[x.get('Target') for x in rel if x.get('Type','').endswith('/hyperlink')]
    for i,text in enumerate(paragraphs):
        if no_cjk_latin_spaces:
            if CJK_LATIN_SPACES.search(text):errors.append({'kind':'cjk_latin_boundary_space','paragraph':i})
            if re.search(r'[\u3400-\u9fff]',text):
                props=list(doc.iter(W+'p'))[i].find(W+'pPr')
                for setting in ['autoSpaceDE','autoSpaceDN']:
                    item=props.find(W+setting) if props is not None else None
                    if item is None or item.get(W+'val') not in ['0','false','off']:
                        errors.append({'kind':'automatic_cjk_spacing_not_disabled','paragraph':i,'setting':setting})
        if '\ufffd' in text or re.search(r'[\x00-\x08\x0b\x0c\x0e-\x1f\x7f-\x9f]',text):
            errors.append({'kind':'damaged_character','paragraph':i})
        if '**' in text or re.search(r'\[[^\]]+\]\(https?://',text):
            errors.append({'kind':'literal_markdown','paragraph':i})
        if re.search(r'[\ue000-\uf8ff]',text):warnings.append({'kind':'private_use_glyph_inspect_font','paragraph':i})
    all_text=norm('\n'.join(paragraphs))
    if approved is not None:
        for i,line in enumerate(Path(approved).read_text(encoding='utf-8',errors='strict').splitlines()):
            if line.strip() and norm(line) not in all_text:errors.append({'kind':'approved_text_missing','line':i+1})
    if rendered is not None:
        rtext=norm(Path(rendered).read_text(encoding='utf-8',errors='strict'))
        for i,text in enumerate(paragraphs):
            if text.strip() and norm(text) not in rtext:errors.append({'kind':'rendered_text_missing','paragraph':i})
    if any(re.search(r'[\u3400-\u9fff]',x) for x in paragraphs) and not fonts:
        warnings.append({'kind':'chinese_font_not_explicit','action':'inspect style/theme and actual renderer font coverage'})
    return {'passed':not errors,'paragraphs':len(paragraphs),'errors':errors,'warnings':warnings,'east_asia_fonts':dict(fonts),'hyperlink_targets':targets,'visual_review_required':True}

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--docx',required=True,type=Path);p.add_argument('--approved-text',type=Path);p.add_argument('--rendered-text',type=Path);p.add_argument('--output',type=Path);p.add_argument('--no-cjk-latin-spaces',action='store_true');a=p.parse_args()
    try:result=check(a.docx,a.approved_text,a.rendered_text,a.no_cjk_latin_spaces)
    except (OSError,UnicodeError,zipfile.BadZipFile,ET.ParseError,KeyError) as e:
        result={'passed':False,'errors':[{'kind':'unreadable_document','detail':str(e)}]}
    data=json.dumps(result,ensure_ascii=False,indent=2)
    if a.output:a.output.write_text(data+'\n',encoding='utf-8')
    print(data);return 0 if result['passed'] else 1
if __name__=='__main__':sys.exit(main())
