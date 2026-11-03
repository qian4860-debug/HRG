"""原始记录产生后重算三方法及评分；原记录需先在MATLAB运行a1_generate。"""
import subprocess
import sys
from a1_fit import HERE

if __name__=='__main__':
    for mode in ['joint_loading','no_loading','raw_second_order']:
        subprocess.run([sys.executable,'-X','utf8',str(HERE/'a1_fit.py'),'--observations',str(HERE/'data/observations'),
            '--output',str(HERE/'evidence'/mode),'--mode',mode],check=True)
    subprocess.run([sys.executable,'-X','utf8',str(HERE/'a1_score.py')],check=True)
    print('Next: MATLAB a1_simulink_check; a1_report; then Python a1_check.py --isolation and a1_report.py.')
