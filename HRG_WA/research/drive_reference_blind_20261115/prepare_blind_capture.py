"""把同步采集 CSV 转成盲评分输入，并核对帧、对时及原始码。"""
import argparse
from collections import defaultdict
import csv
import json
from pathlib import Path

import numpy as np

from blind_drive_reference import FS, CARRIER, N, ADC_STEP, synth


FIELDS = ("sample_index", "time_s", "frame_id", "sense_tick", "adc_x_code",
          "adc_y_code", "drive_ref_x_V", "drive_ref_y_V", "adc_clip")
LABELS = ("frame_id", "validated_route", "case", "injection", "truth_beta_rad")
ARMS = {"off", "pos_x", "neg_x", "pos_y", "neg_y", "pos_xy", "neg_xy"}


def prepare(samples, labels, out):
    """逐帧以检测接通为第 0 拍；源序号用于检查遗漏和重排。"""
    groups = defaultdict(list)
    previous = None
    clock_origin = None
    with samples.open(encoding="utf-8-sig", newline="") as f:
        for row in csv.DictReader(f):
            sample, frame, tick, x, y, clip = (int(row[col]) for col in
                ("sample_index", "frame_id", "sense_tick", "adc_x_code", "adc_y_code", "adc_clip"))
            time = float(row["time_s"])
            witness = [float(row[c]) for c in ("drive_ref_x_V", "drive_ref_y_V")]
            if clock_origin is None:
                clock_origin = time-sample/FS
            if not (np.isfinite([time, *witness]).all() and
                    abs(time-(clock_origin+sample/FS)) <= .1/FS):
                raise ValueError("共同时钟对齐超出第 0.1 拍，本入口不能自动修正")
            if not (sample >= 0 and frame >= 0 and clip in (0,1) and
                    all(-32768 <= code <= 32767 for code in (x,y))):
                raise ValueError("序号、ADC 码或过载位超出范围")
            if previous:
                step = (sample-previous[0], frame-previous[1], tick-previous[2])
                if not ((step == (1,0,1)) or
                        (step == (2*N+1,1,1-2*N) and tick == 0)):
                    raise ValueError(f"帧 {frame} 拍 {tick} 缺样、缺帧或顺序错误")
            if tick != len(groups[frame]):
                raise ValueError("检测窗口缺少起点或样本")
            groups[frame].append((x,y,*witness,clip))
            previous = (sample,frame,tick)
    if not groups or any(len(g)!=2*N for g in groups.values()):
        raise ValueError("每帧需要两周期完整采集")
    indexed = {}
    with labels.open(encoding="utf-8-sig", newline="") as f:
        for row in csv.DictReader(f):
            frame, validated = int(row["frame_id"]),int(row["validated_route"])
            truth = float(row["truth_beta_rad"])
            if (frame in indexed or validated not in (0,1) or not row["case"]
                    or row["injection"] not in ARMS or not np.isfinite(truth)):
                raise ValueError(f"无效标签或重复帧 {frame}")
            indexed[frame] = (validated,row["case"],row["injection"],truth)
    if indexed.keys() != groups.keys():
        raise ValueError("标签与采样帧未一一对应")
    ordered = [indexed[k] for k in groups]
    valid, case, injection, truth = zip(*ordered)
    data = np.array(list(groups.values()))
    np.savez_compressed(out, adc_V=data[:,:,:2]*ADC_STEP,drive_ref_V=data[:,:,2:4],
                        adc_clip=np.any(data[:,:,4],axis=1),validated_route=valid,
                        case=case,injection=injection,truth_beta_rad=truth)
    return len(ordered)


def synthetic_example(directory):
    """输出小型采集例，验证 CSV→NPZ→盲评分；数据只来自合成模型。"""
    directory.mkdir(parents=True, exist_ok=True)
    for name, seed, cases, train in [
        ("calibration",98263,["nominal"],True),
        ("blind",192841,["nominal","hidden_in_verified_route"],False),
    ]:
        batch = synth(seed, 14, cases, train)
        with (directory/f"{name}.csv").open("w",newline="",encoding="utf-8") as f, (
               directory/f"{name}_labels.csv").open("w",newline="",encoding="utf-8") as l:
            samples, labels = csv.writer(f),csv.writer(l)
            samples.writerow(FIELDS)
            labels.writerow(LABELS)
            for k,(adc,ref,clip,valid,case,inj,truth) in enumerate(batch):
                labels.writerow((k,int(valid),case,inj,truth))
                for tick,((x,y),(u,v)) in enumerate(zip(adc,ref,strict=True)):
                    index = k*4*N + tick
                    samples.writerow((index,index/FS,k,tick,round(x/ADC_STEP),
                                      round(y/ADC_STEP),u,v,int(clip)))
    metadata = dict(sample_rate_Hz=FS,carrier_Hz=CARRIER,sample_origin="sense_connect",
                    independent_reference=True,calibration_motion_source_off=True,
                    calibration_batch_id="synthetic-calibration",blind_batch_id="synthetic-blind",
                    source="synthetic_csv_selftest")
    (directory/"capture.json").write_text(json.dumps(metadata,indent=2)+"\n",encoding="utf-8")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="action",required=True)
    sample = sub.add_parser("synthetic-example")
    sample.add_argument("directory",type=Path)
    convert = sub.add_parser("convert")
    for item in ("samples","labels","output"):
        convert.add_argument(item,type=Path)
    args = parser.parse_args()
    if args.action == "convert":
        print(f"完整采样帧 {prepare(args.samples,args.labels,args.output)}")
    else:
        synthetic_example(args.directory)
