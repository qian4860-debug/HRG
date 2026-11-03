"""重放封存数据与两种窗口，不改变冻结规则或随机种子。"""
import subprocess
import sys
from a3_common import HERE

if __name__=='__main__':
    for window in [40,240]:
        subprocess.run([sys.executable,'-X','utf8',str(HERE/'a3_process.py'),'--observations',str(HERE/'data/observations'),
            '--output',str(HERE/'evidence'/('window_'+str(window))),'--window',str(window)],check=True)
    subprocess.run([sys.executable,'-X','utf8',str(HERE/'a3_score.py')],check=True)
    subprocess.run([sys.executable,'-X','utf8',str(HERE/'a3_math_checks.py')],check=True)
    print('Next MATLAB a3_matlab_check; a3_report; then a3_check.py --isolation and a3_report.py.')
