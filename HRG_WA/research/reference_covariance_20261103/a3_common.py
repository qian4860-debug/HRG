from pathlib import Path
import sys

HERE=Path(__file__).resolve().parent
A2=HERE.parent/'causal_deembedding_20261103'
sys.path.insert(0,str(A2))
from a2_dsp import (read_json,write_json,write_csv,sha,SosFilter,CausalFrontend,synthesize,
    orientation,design,delay_seconds,calibration_check,noise_upper,corner_sensitivity)


def config(window):
    result=read_json(A2/'config.json');result.update(read_json(HERE/'config.json'))
    result['demod_window_samples']=window
    return result
