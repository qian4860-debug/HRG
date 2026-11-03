"""MATLAB生成原始记录后重算两种窗口和评分，不重选预算。"""
import subprocess
import sys
from a2_dsp import HERE,read_json

if __name__=='__main__':
    cfg=read_json(HERE/'config.json')
    for window in [cfg['demod_window_samples'],cfg['comparison_demod_window_samples']]:
        subprocess.run([sys.executable,'-X','utf8',str(HERE/'a2_process.py'),'--observations',str(HERE/'data/observations'),
            '--output',str(HERE/'evidence'/('window_'+str(window))),'--window',str(window)],check=True)
    subprocess.run([sys.executable,'-X','utf8',str(HERE/'a2_score.py')],check=True)
    print('Next MATLAB a2_simulink_check; a2_report; then a2_check.py --isolation and a2_report.py.')
