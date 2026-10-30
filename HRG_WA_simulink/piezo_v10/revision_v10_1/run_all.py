"""Rebuild synthetic fixtures, MATLAB models and independent scoreboards.

No automatic sealing or Git operations: inspect regenerated evidence first.
"""
from pathlib import Path
import argparse, subprocess, sys

HERE=Path(__file__).resolve().parent

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--matlab',default='D:/matlab/bin/matlab.exe')
    args=parser.parse_args()
    for name in ['fit_calibration.py','identify_multiload.py','fit_temperature.py','budget.py']:
        subprocess.run([sys.executable,'-X','utf8',str(HERE/name)],check=True,cwd=HERE)
    matlab_path=str(HERE).replace('\\','/').replace("'","''")
    subprocess.run([args.matlab,'-batch',f"addpath('{matlab_path}');p101_run_all;p101_plot_results"],check=True,cwd=HERE)
    for name in ['verify_measurement.py','verify_envelope.py']:
        subprocess.run([sys.executable,'-X','utf8',str(HERE/name)],check=True,cwd=HERE)
    for path in HERE.rglob('*'):
        if path.is_file() and path.suffix in {'.json','.csv','.m','.py','.md'}:
            raw=path.read_bytes(); normalized=raw.replace(b'\r\n',b'\n')
            if raw!=normalized:path.write_bytes(normalized)
    print('PASS: rebuilt evidence. SLX bytes may change on rebuild; accepted delivery hashes require an explicit new review.')

if __name__=='__main__':main()
