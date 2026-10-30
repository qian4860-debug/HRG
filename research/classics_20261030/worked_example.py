"""Scalar, standard-library-only calculation trace for the book's full example.

Unlike verify_classics.py, this does not call the matrix/canonical helpers.
Each saved node records the arithmetic expression and already computed inputs.
"""
from pathlib import Path
import csv
import json
import math as m

HERE=Path(__file__).resolve().parent


def main():
    nodes=[];v={}
    def node(key,equation,expression,parents,fn,unit='normalized'):
        assert key not in v,'Trace node ids must be unique: '+key
        args={s:v[s] for s in parents};value=fn(*args.values());v[key]=value
        nodes.append(dict(step=len(nodes)+1,id=key,equation=equation,expression=expression,
                          operands=json.dumps(args,ensure_ascii=False),value=format(value,'.17g'),unit=unit))
        return value
    inputs=dict(a=2.,q=.2,theta=m.pi/6,delta=m.pi/12,w=1000.,decay=.01,damping=.004,split=.02,td=.1,tw=.2,k=.6,omega=.03,phidot=.001)
    for key,value in inputs.items():node(key,'input',str(value),[],lambda x=value:x)
    for key,value in dict(fxr=.1,fxi=-.2,fyr=.03,fyi=.04).items():node(key,'input',str(value),[],lambda x=value:x)
    for key,parent,fn in [('ct','theta',m.cos),('st','theta',m.sin),('cd','delta',m.cos),('sd','delta',m.sin)]:
        node(key,'29',fn.__name__+'('+parent+')',[parent],fn)
    for key,p,q in [('ac','a','ct'),('as','a','st'),('qc','q','ct'),('qs','q','st')]:node(key,'29',p+'*'+q,[p,q],lambda x,y:x*y)
    for key,x,y in [('cx1','ac','cd'),('cx2','qs','sd'),('sx1','ac','sd'),('sx2','qs','cd'),
                    ('cy1','as','cd'),('cy2','qc','sd'),('sy1','as','sd'),('sy2','qc','cd')]:node(key,'29',x+'*'+y,[x,y],lambda x,y:x*y)
    for key,p1,p2,sign in [('cx','cx1','cx2',1),('sx','sx1','sx2',-1),('cy','cy1','cy2',-1),('sy','sy1','sy2',1)]:
        node(key,'29',p1+('+' if sign==1 else '-')+p2,[p1,p2],lambda x,y,s=sign:x+s*y)
    for key in ['cx','sx','cy','sy']:node(key+'_sq','31',key+'**2',[key],lambda x:x*x)
    node('E','31','cx_sq+sx_sq+cy_sq+sy_sq',['cx_sq','sx_sq','cy_sq','sy_sq'],lambda *args:sum(args))
    node('Qp1','31','cx*sy',['cx','sy'],lambda x,y:x*y);node('Qp2','31','cy*sx',['cy','sx'],lambda x,y:x*y)
    node('Q','31','2*(Qp1-Qp2)',['Qp1','Qp2'],lambda x,y:2*(x-y))
    node('R','31','cx_sq+sx_sq-cy_sq-sy_sq',['cx_sq','sx_sq','cy_sq','sy_sq'],lambda a,b,c,d:a+b-c-d)
    node('S','31','2*(cx*cy+sx*sy)',['cx','cy','sx','sy'],lambda a,b,c,d:2*(a*b+c*d))
    node('L_real','31','cx_sq-sx_sq+cy_sq-sy_sq',['cx_sq','sx_sq','cy_sq','sy_sq'],lambda a,b,c,d:a-b+c-d)
    node('L_imag','31','2*(cx*sx+cy*sy)',['cx','sx','cy','sy'],lambda a,b,c,d:2*(a*b+c*d))
    node('E2','39','E**2',['E'],lambda x:x*x);node('Q2','39','Q**2',['Q'],lambda x:x*x)
    node('D2','39','E2-Q2',['E2','Q2'],lambda x,y:x-y);node('D','39','sqrt(D2)',['D2'],m.sqrt)
    node('theta_recovered','31','atan2(S,R)/2',['S','R'],lambda x,y:m.atan2(x,y)/2,'rad')
    node('delta_recovered','31','atan2(L_imag,L_real)/2',['L_imag','L_real'],lambda x,y:m.atan2(x,y)/2,'rad')
    node('fa_r','36','fxr*ct+fyr*st',['fxr','ct','fyr','st'],lambda a,b,c,d:a*b+c*d)
    node('fa_i','36','fxi*ct+fyi*st',['fxi','ct','fyi','st'],lambda a,b,c,d:a*b+c*d)
    node('fq_r','36','-fxr*st+fyr*ct',['fxr','st','fyr','ct'],lambda a,b,c,d:-a*b+c*d)
    node('fq_i','36','-fxi*st+fyi*ct',['fxi','st','fyi','ct'],lambda a,b,c,d:-a*b+c*d)
    for key,x,y,is_im in [('ua','fa_r','fa_i',False),('va','fa_r','fa_i',True),('uq','fq_r','fq_i',False),('vq','fq_r','fq_i',True)]:
        node(key,'35',('imag' if is_im else 'real')+'(('+x+'+1j*'+y+')*exp(-1j*delta))',[x,y,'cd','sd'],
             (lambda a,b,c,d:b*c-a*d) if is_im else (lambda a,b,c,d:a*c+b*d))
    node('u','35','2*(theta-td)',['theta','td'],lambda x,y:2*(x-y),'rad')
    node('v','35','2*(theta-tw)',['theta','tw'],lambda x,y:2*(x-y),'rad')
    for key,p,fn in [('su','u',m.sin),('cu','u',m.cos),('sv','v',m.sin),('cv','v',m.cos)]:node(key,'35',fn.__name__+'('+p+')',[p],fn)
    node('E1','38','-2*decay*E',['decay','E'],lambda x,y:-2*x*y)
    node('E2term','38','-damping*cu*D',['damping','cu','D'],lambda x,y,z:-x*y*z)
    node('E3','38','(-a*va+q*uq)/w',['a','va','q','uq','w'],lambda a,b,c,d,w:(-a*b+c*d)/w)
    node('E_dot','38','E1+E2term+E3',['E1','E2term','E3'],lambda *x:sum(x))
    node('Q1','38','-2*decay*Q',['decay','Q'],lambda x,y:-2*x*y)
    node('Q2term','38','-split*sv*D',['split','sv','D'],lambda x,y,z:-x*y*z)
    node('Q3','38','(a*uq-q*va)/w',['a','uq','q','va','w'],lambda a,b,c,d,w:(a*b-c*d)/w)
    node('Q_dot','38','Q1+Q2term+Q3',['Q1','Q2term','Q3'],lambda *x:sum(x))
    node('T1','38','-k*omega',['k','omega'],lambda x,y:-x*y)
    node('T2','38','damping/2*su*E/D',['damping','su','E','D'],lambda a,b,c,d:a*b*c/(2*d))
    node('T3','38','split/2*cv*Q/D',['split','cv','Q','D'],lambda a,b,c,d:a*b*c/(2*d))
    node('T4','38','(-a*vq+q*ua)/(2*w*D)',['a','vq','q','ua','w','D'],lambda a,b,c,d,w,D:(-a*b+c*d)/(2*w*D))
    node('theta_dot','38','T1+T2+T3+T4',['T1','T2','T3','T4'],lambda *x:sum(x),'rad/s')
    node('D1','38','phidot',['phidot'],lambda x:x)
    node('D2term','38','damping/2*su*Q/D',['damping','su','Q','D'],lambda a,b,c,d:a*b*c/(2*d))
    node('D3','38','split/2*cv*E/D',['split','cv','E','D'],lambda a,b,c,d:a*b*c/(2*d))
    node('D4','38','(a*ua-q*vq)/(2*w*D)',['a','ua','q','vq','w','D'],lambda a,b,c,d,w,D:(a*b-c*d)/(2*w*D))
    node('delta_dot','38','D1+D2term+D3+D4',['D1','D2term','D3','D4'],lambda *x:sum(x),'rad/s')
    node('phi_prime_dot','38','phidot-delta_dot',['phidot','delta_dot'],lambda x,y:x-y,'rad/s')
    node('a_dot','35','-(decay+damping/2*cu)*a+split/2*sv*q-va/(2*w)',
         ['decay','damping','cu','a','split','sv','q','va','w'],lambda ga,d,cu,a,h,sv,q,va,w:-(ga+d/2*cu)*a+h/2*sv*q-va/(2*w))
    node('q_dot','35','-(decay-damping/2*cu)*q-split/2*sv*a+uq/(2*w)',
         ['decay','damping','cu','q','split','sv','a','uq','w'],lambda ga,d,cu,q,h,sv,a,uq,w:-(ga-d/2*cu)*q-h/2*sv*a+uq/(2*w))
    node('E_dot_chain','38','2*a*a_dot+2*q*q_dot',['a','a_dot','q','q_dot'],lambda a,b,c,d:2*a*b+2*c*d)
    node('Q_dot_chain','38','2*q*a_dot+2*a*q_dot',['q','a_dot','a','q_dot'],lambda a,b,c,d:2*a*b+2*c*d)
    for key,der in [('E','E_dot'),('Q','Q_dot'),('theta','theta_dot'),('delta','delta_dot')]:node(key+'_next','Euler',key+'+0.001*'+der,[key,der],lambda x,y:x+.001*y)
    d=dict(inputs=inputs,fixed_force_real=[v['fxr'],v['fyr']],fixed_force_imag=[v['fxi'],v['fyi']],
           cos_theta=v['ct'],sin_theta=v['st'],cos_delta=v['cd'],sin_delta=v['sd'],C_real=[v['cx'],v['cy']],C_imag=[v['sx'],v['sy']],
           force_rotated_real=[v['fa_r'],v['fq_r']],force_rotated_imag=[v['fa_i'],v['fq_i']],force_vibration_real=[v['ua'],v['uq']],force_vibration_imag=[v['va'],v['vq']],
           terms=dict(sin_u=v['su'],cos_u=v['cu'],sin_v=v['sv'],cos_v=v['cv'],E_terms=[v['E1'],v['E2term'],v['E3']],Q_terms=[v['Q1'],v['Q2term'],v['Q3']],theta_terms=[v[k] for k in ['T1','T2','T3','T4']],delta_terms=[v[k] for k in ['D1','D2term','D3','D4']]),trace_nodes=len(nodes))
    for key in ['E','Q','R','S','L_real','L_imag','D','u','v','a_dot','q_dot','theta_dot','delta_dot','phi_prime_dot','E_dot','Q_dot']:d[key]=v[key]
    assert abs(v['E_dot']-v['E_dot_chain'])<1e-12 and abs(v['Q_dot']-v['Q_dot_chain'])<1e-12
    (HERE/'worked_example.json').write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
    with (HERE/'worked_trace.csv').open('w',encoding='utf-8-sig',newline='') as f:
        writer=csv.DictWriter(f,fieldnames=list(nodes[0]),lineterminator='\n');writer.writeheader();writer.writerows(nodes)
    print('PASS: scalar worked example,',len(nodes),'recorded calculation nodes, two independent chain-rule cross-checks')


if __name__=='__main__':main()
