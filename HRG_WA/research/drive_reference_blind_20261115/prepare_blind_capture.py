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
# 这三列来自参考采集器的独立状态与时间标签，需与 ADC 采用同一触发纪元。
WITNESS_FIELDS = ("reference_healthy", "reference_frame_id", "reference_sample_index")
LABELS = ("frame_id", "validated_route", "case", "injection", "truth_beta_rad")
ARMS = {"off", "pos_x", "neg_x", "pos_y", "neg_y", "pos_xy", "neg_xy"}
AD9215_CODINGS = ("offset-binary", "twos-complement-word", "signed")


def ad9215_centered(code, coding):
    """把无符号 10 位总线字或已符号扩展的整数统一成 [-512, 511]。"""
    if coding == "signed":
        if -512 <= code <= 511:
            return code
    elif 0 <= code <= 1023:
        if coding == "offset-binary":
            return code - 512
        if coding == "twos-complement-word":
            return code - 1024 if code >= 512 else code
    raise ValueError(f"AD9215 码 {code} 超出 {coding} 的范围")


def prepare(samples, labels, out, *, coding=None, vpp=None, delay=None):
    """检测接通是第 0 拍。原始模式用后续输出码配对当前参考。"""
    if coding is None:
        if vpp is not None or delay is not None:
            raise ValueError("原始输入需要同时指定 AD9215 码制、差分量程和总延迟")
        step = ADC_STEP
        delay = 0
    else:
        if (coding not in AD9215_CODINGS or vpp is None or not np.isfinite(vpp)
                or not 0 < vpp or type(delay) is not int or not 0 <= delay < 2*N):
            raise ValueError("需指定有效的 AD9215 码制、正差分量程和两周期以内的非负整数总延迟")
        step = vpp / 1024
    raw_count = 2*N + delay
    groups = defaultdict(list)
    previous = None
    clock_origin = None
    with samples.open(encoding="utf-8-sig", newline="") as f:
        reader = csv.DictReader(f)
        witness_columns = set(WITNESS_FIELDS).intersection(reader.fieldnames or ())
        if witness_columns and len(witness_columns) != len(WITNESS_FIELDS):
            raise ValueError("参考健康、参考帧号及参考样本序号必须成组记录")
        witness_records = defaultdict(list)
        for row in reader:
            sample, frame, tick, x, y, clip = (int(row[col]) for col in
                ("sample_index", "frame_id", "sense_tick", "adc_x_code", "adc_y_code", "adc_clip"))
            time = float(row["time_s"])
            witness = [float(row[c]) for c in ("drive_ref_x_V", "drive_ref_y_V")]
            if clock_origin is None:
                clock_origin = time-sample/FS
            if not (np.isfinite(time) and
                    abs(time-(clock_origin+sample/FS)) <= .1/FS):
                raise ValueError("共同时钟对齐超出第 0.1 拍，本入口不能自动修正")
            if not (sample >= 0 and frame >= 0 and clip in (0,1)):
                raise ValueError("序号或过载位超出范围")
            if coding is not None:
                x, y = (ad9215_centered(code, coding) for code in (x,y))
            elif not all(-32768 <= code <= 32767 for code in (x,y)):
                raise ValueError("已对齐的有符号 16 位 ADC 码超出范围")
            if previous:
                index_step = (sample-previous[0], frame-previous[1], tick-previous[2])
                if not ((index_step == (1,0,1)) or
                        (index_step == (4*N-raw_count+1,1,1-raw_count) and tick == 0)):
                    raise ValueError(f"帧 {frame} 拍 {tick} 缺样、缺帧或顺序错误")
            if tick != len(groups[frame]):
                raise ValueError("检测窗口缺少起点或样本")
            groups[frame].append((x,y,*witness,clip))
            # 仅参考信号的检测窗参与核验，尾部 ADC 流水延迟拍不参与参考健康判断。
            if witness_columns and tick < 2*N:
                healthy, ref_frame, ref_sample = (int(row[k]) for k in WITNESS_FIELDS)
                if healthy not in (0, 1):
                    raise ValueError("参考健康位必须为 0 或 1")
                witness_records[frame].append((healthy, ref_frame, ref_sample == sample))
            previous = (sample,frame,tick)
    if not groups or any(len(g)!=raw_count for g in groups.values()):
        raise ValueError(f"每帧需要 {raw_count} 拍，包括原始码的尾部延迟拍")
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
    # ADC 过载位与输出码同拍。独立参考、sense_tick 和时标仍属于采样拍。
    output = data[:,delay:raw_count,:]
    clip_samples = output[:,:,4].astype(bool)
    status = {}
    if witness_columns:
        witnesses = list(witness_records.values())
        status = dict(reference_healthy=[all(row[0] for row in frame) for frame in witnesses],
                      reference_frame_id=[frame[0][1] for frame in witnesses],
                      adc_frame_id=list(groups),
                      reference_samples_aligned=[all(row[2] and row[1] == key for row in frame)
                                                 for key, frame in witness_records.items()])
    np.savez_compressed(out, adc_V=output[:,:,:2]*step,drive_ref_V=data[:,:2*N,2:4],
                        adc_clip=np.any(clip_samples,axis=1),adc_clip_samples=clip_samples,
                        adc_code_format=coding or "aligned-signed16", adc_LSB_V=step,
                        adc_delay_cycles=delay, validated_route=valid,
                        case=case,injection=injection,truth_beta_rad=truth, **status)
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
            samples.writerow(FIELDS + WITNESS_FIELDS)
            labels.writerow(LABELS)
            for k,(adc,ref,clip,valid,case,inj,truth) in enumerate(batch):
                labels.writerow((k,int(valid),case,inj,truth))
                for tick,((x,y),(u,v)) in enumerate(zip(adc,ref,strict=True)):
                    index = k*4*N + tick
                    samples.writerow((index,index/FS,k,tick,round(x/ADC_STEP),
                                      round(y/ADC_STEP),u,v,int(clip),1,k,index))
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
    convert.add_argument("--ad9215-coding",choices=AD9215_CODINGS)
    convert.add_argument("--differential-vpp",type=float)
    convert.add_argument("--observed-delay-cycles",type=int)
    args = parser.parse_args()
    if args.action == "convert":
        count = prepare(args.samples,args.labels,args.output, coding=args.ad9215_coding,
                        vpp=args.differential_vpp, delay=args.observed_delay_cycles)
        print(f"完整采样帧 {count}")
    else:
        synthetic_example(args.directory)
