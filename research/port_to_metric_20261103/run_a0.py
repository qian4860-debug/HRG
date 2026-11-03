"""重建A0当前归档实验；不改变旧版本，不重新选择门槛。"""
from pathlib import Path
import subprocess
import sys

HERE=Path(__file__).resolve().parent


if __name__=='__main__':
    for script,args in [('generate_records.py',[]),('fit_records.py',['--observations',str(HERE/'data/observations'),'--output',str(HERE/'evidence')]),('score_records.py',[])]:
        subprocess.run([sys.executable,'-X','utf8',str(HERE/script),*args],cwd=HERE,check=True)
    print('A0 data/estimation/scoring rebuilt. Run a0_matlab_check in MATLAB, make_report.py, then check_a0.py.')
