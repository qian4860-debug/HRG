"""Match cited titles to explicitly linked PDFs on author laboratory pages."""
import json
from pathlib import Path
import urllib.parse

from lxml import html

import acquire_wa_citations as a


def main():
    net=a.Network('http://127.0.0.1:7897')
    rows=json.loads((a.REPORT/'references.json').read_text(encoding='utf-8'))
    target=a.REPORT/'manual_download_links.json'
    links=json.loads(target.read_text(encoding='utf-8'))
    seen={(x.get('doi'),x['url']) for x in links};evidence=[]
    for url in ['https://mems.eng.uci.edu/publications/','https://memslab.ucdavis.edu/publications/']:
        try:
            data,final,ctype=net.get(url,8_000_000,25)
            doc=html.fromstring(data);count=0
            for anchor in doc.xpath('//a[@href]'):
                href=urllib.parse.urljoin(final,anchor.attrib['href'])
                if '.pdf' not in href.lower():continue
                containers=list(anchor.iterancestors())
                context=next((' '.join(x.itertext()) for x in containers if x.tag in ['tr','li','p']),'')
                context=' '.join(context.split())
                if not context or len(context)>2500:continue
                for row in rows:
                    resolved=row.get('resolved',{});title=resolved.get('title')
                    if not title or len(a.norm(title))<22:continue
                    if a.title_score(title,context)<.96:continue
                    variants=[href]
                    if href.startswith('https://bpb-us-e2.wpmucdn.com/'):
                        variants.append(href.replace('https://bpb-us-e2.wpmucdn.com/','https://cpb-us-e2.wpmucdn.com/',1))
                    for variant in variants:
                        key=(row.get('doi'),variant)
                        if key in seen:continue
                        links.append(dict(doi=row.get('doi'),id=row['id'],url=variant,
                            expected_title=title,source=url,
                            note='PDF href explicitly linked with matching title; cpb CDN alias is recorded separately when derived from the validated bpb/cpb author-host pair',
                            title_context=context[:600]))
                        seen.add(key);count+=1
            evidence.append(dict(url=url,final_url=final,sha256=a.digest(data),matched_links=count,status='author_page_matched'))
            print(url,'MATCHED PDF LINKS',count,flush=True)
        except Exception as e:
            evidence.append(dict(url=url,status='unavailable',error=str(e)))
            print(url,str(e),flush=True)
    a.save(target,links);a.save(a.REPORT/'author_page_discovery.json',evidence)


if __name__=='__main__':main()
