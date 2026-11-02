"""Static inspection only. Never loads source SLX or executes startup/callbacks."""
from pathlib import Path
import collections,hashlib,json,zipfile,xml.etree.ElementTree as ET
HERE=Path(__file__).resolve().parent
ARCHIVE=Path('C:/Users/11725/xwechat_files/wxid_qvgyt57csh8y22_a935/temp/RWTemp/2026-11/cb4ddb28667600e67f7999fb47a06b60/Gyro.rar')
SOURCE=HERE.parents[1]/'_work/gyro_reference/Gyro'
def main():
    result={'archive':str(ARCHIVE),'sha256':hashlib.sha256(ARCHIVE.read_bytes()).hexdigest(),
            'method':'RAR selected source extraction; static ZIP/XML only; no reference code executed', 'models':[]}
    for path in sorted(SOURCE.rglob('*.slx')):
        with zipfile.ZipFile(path) as z:
            blocks=[];root=[];callbacks=[]
            for name in z.namelist():
                if name.endswith('.xml') and (name.startswith('simulink/systems/') or name=='simulink/blockdiagram.xml'):
                    tree=ET.fromstring(z.read(name))
                    for p in tree.iter('P'):
                        if p.get('Name','').endswith('Fcn') and p.text:callbacks.append({'name':p.get('Name'),'text':p.text})
                    bs=[{'name':b.get('Name'),'type':b.get('BlockType'),'parameters':{p.get('Name'):p.text for p in b.findall('P') if p.get('Name') in ['SourceBlock','ModelName','FunctionName','Numerator','Denominator','GotoTag','SampleTime']}} for b in tree.iter('Block')]
                    blocks.extend(bs)
                    if name.endswith('system_root.xml'):root=bs
            result['models'].append({'path':path.relative_to(SOURCE).as_posix(),'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),
                'block_counts':dict(collections.Counter(b['type'] for b in blocks)), 'root':root,
                'library_references':sorted(set(b['parameters']['SourceBlock'] for b in blocks if b['parameters'].get('SourceBlock'))),
                'callbacks_not_executed':callbacks})
    out=HERE/'evidence/reference_audit.json';out.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
    print('Statically inspected',len(result['models']),'SLX models')
    for m in result['models']:
        if m['path'].startswith(('final/','Heading/','SDM/')):
            print(m['path'],[(b['name'],b['type']) for b in m['root']],m['library_references'])
if __name__=='__main__':main()
