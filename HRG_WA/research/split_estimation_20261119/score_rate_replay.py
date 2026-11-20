"""把独立测频代理的因果读数接入第49号闭环轨迹，按整窗可用性评分。"""
import argparse
from collections import defaultdict
import hashlib
import json
from pathlib import Path
import numpy as np


WINDOWS = [(0.02, 0.06), (0.08, 0.12), (1, 2), (5, 6), (10, 11), (19, 20)]
METHODS = ("raw", "ideal", "estimated", "held50")


def read(path):
    return json.loads(path.read_text(encoding="utf-8"))


def causal_hold(t, readings):
    """门控只读当前及历史包。新包取代旧包，超龄、超标定范围或无效时留空。"""
    arrivals = np.array([r["t_s"] for r in readings])
    assert np.all(np.diff(arrivals) > 0)
    # 帧时刻由整数采样拍导出；浮点比较只补偿纳秒以下的舍入。
    ix = np.searchsorted(arrivals, t + 1e-12, side="right") - 1
    freq = np.array([r["split_est_mHz"] for r in readings], dtype=float)
    expiry = np.array([r["valid_until_s"] for r in readings])
    valid = np.array([r["valid"] for r in readings], dtype=bool)
    usable = ((ix >= 0) & valid[ix] & (t < expiry[ix]-1e-12)
              & np.isfinite(freq[ix]) & (np.abs(freq[ix]) <= 50))
    return np.where(usable, freq[ix], np.nan)


def slope(t, y):
    x = t-t.mean()
    return float(1000*np.dot(x, y-y.mean())/np.dot(x, x))


def assess(t, dt, angle, bias0, dbias, split, rate, step):
    good = np.isfinite(split)
    # 缺口处零填仅用于中间累计量。只评分全窗连续有效的增量，缺口两端不连线。
    correction = bias0+dbias*(np.nan_to_num(split)/50)**2
    output = angle-np.r_[0., np.cumsum(correction[:-1])*dt]
    def score_window(a, b):
        lo, hi = round(a/dt), round(b/dt)
        if not good[lo:hi].all():
            return None
        return round(slope(t[lo:hi], output[lo:hi])-rate, 8)
    half = [score_window(i/2, (i+1)/2) for i in range(40)]
    result=dict(frame_coverage=round(float(good.mean()), 6),
                window_errors=[score_window(a,b) for a,b in WINDOWS], half_s_errors=half)
    if step:
        # 从事件本身重新起窗，忽略最后不足半秒的片段。空窗会打断连续达标。
        post=[score_window(10.25+i/2,10.25+(i+1)/2) for i in range(19)]
        good_post=[e is not None and abs(e)<=.25 for e in post]
        result["confirmed_after_event_s"]=next(((i+1)/2 for i in range(1,len(post))
            if good_post[i-1] and good_post[i]),None)
        result["post_event_half_s_errors"]=post
    return result


def score(cache, estimate_path, calibration_path):
    by_run = defaultdict(list)
    for row in read(estimate_path)["rows"]:
        by_run[row["run_id"]].append(row)
    previous = read(calibration_path)
    tables = {m["mode"]: np.array(m["calibration_rad_s"]) for m in previous["modes"]}
    result = []
    for case in read(cache/"catalog.json"):
        dt, rate = case["dt_s"], case["rate_mrad_s"]
        z, raw = np.fromfile(cache/case["file"], dtype="<f8").reshape(-1,2).T
        t = np.arange(len(z))*dt
        assert len(z) == case["frames"] == 34000
        h = np.column_stack([np.ones_like(z), np.cos(z), np.sin(z), np.cos(2*z), np.sin(2*z)])
        b0, b50 = (h @ tables[case["mode"]]).T
        step = case["split_mHz"] == -1
        truth = np.where(t < 10.25, 50., 25.) if step else np.full(len(t),case["split_mHz"])
        # 分配实验工况用发生器标签；送入因果门控的只有测频字段。理想和旧值仅作对照。
        common = {name: assess(t,dt,raw,b0*(name!="raw"),(b50-b0)*(name!="raw"),freq,rate,step)
                  for name,freq in [("raw",truth),("ideal",truth),("held50",np.full_like(t,50.))]}
        for run, readings in by_run.items():
            if (readings[0]["case_name"]=="split_step") != step or readings[0]["split_true_mHz"]!=truth[0]:
                continue
            actual = assess(t,dt,raw,b0,b50-b0,causal_hold(t,readings),rate,step)
            result.append(dict(mode=case["mode"], rate_mrad_s=rate, run_id=run,
                               case_name=readings[0]["case_name"], split_start_mHz=int(truth[0]),
                               methods={**common,"estimated":actual}))
    assert len(result)==320 and len(by_run)==32
    # 与第49号独立已提交回执比较相同初角/频差/转速的理想补偿和原始角。
    max_error=0.
    for m in previous["modes"]:
        for ref in m["cases"]:
            if ref["beta_deg"]!=28.125 or ref["supplied_split_Hz"]!=ref["plant_split_Hz"] or ref["plant_split_Hz"]<0:
                continue
            matches=[r for r in result if r["mode"]==m["mode"] and r["case_name"]=="nominal"
                     and r["split_start_mHz"]==1000*ref["plant_split_Hz"] and r["rate_mrad_s"]==1000*ref["truth_rad_s"]]
            if matches:
                for j,key in enumerate(["raw","ideal"]):
                    actual=matches[0]["methods"][key]["window_errors"]
                    max_error=max(max_error,float(np.max(np.abs(np.array(actual)-np.array(ref["error_raw_corrected_mrad_s"])[:,j]))))
    # 本评分器按整数帧划窗；旧入口按浮点秒区间划窗，边沿可能相差一帧。
    assert max_error<1e-5, max_error
    return result, max_error


def summarize(rows):
    summary=[]
    for mode,case_name in sorted({(r["mode"],r["case_name"]) for r in rows}):
        selected=[r for r in rows if (r["mode"],r["case_name"])==(mode,case_name)]
        group={(r["run_id"],r["rate_mrad_s"]):r for r in selected}
        for method in METHODS:
            ms=[r["methods"][method] for r in selected]
            late=[x for m in ms for x in m["window_errors"][2:] if x is not None]
            gains=[]
            for (run,rate), plus in group.items():
                if rate<=0:
                    continue
                minus=group[(run,-rate)]
                for p,n in zip(plus["methods"][method]["window_errors"][2:],minus["methods"][method]["window_errors"][2:]):
                    if p is not None and n is not None:
                        gains.append((1+(p-n)/(2*rate),p+rate>0 and n-rate<0))
            summary.append(dict(mode=mode,case_name=case_name,method=method,trajectory_replays=len(ms),
                frame_coverage=float(np.mean([m["frame_coverage"] for m in ms])),
                late_total=4*len(ms), late_scored=len(late),late_pass=sum(abs(x)<=.25 for x in late),
                worst_late_mrad_s=max(map(abs,late),default=None),pair_windows=len(gains),
                pair_sign_pass=sum(ok for _,ok in gains),pair_gain_sign_pass=sum(abs(g-1)<=.05 and ok for g,ok in gains)))
    return summary


if __name__=="__main__":
    folder=Path(__file__).resolve().parent
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("cache",type=Path)
    parser.add_argument("--estimate",type=Path,default=folder/"estimates.json")
    parser.add_argument("--calibration",type=Path,default=folder.parent/"three_angle_observation_20261115/split_bias_verification.json")
    parser.add_argument("--output",type=Path,default=folder/"rate_replay.json")
    args=parser.parse_args()
    rows,delta=score(args.cache,args.estimate,args.calibration)
    report=dict(scope="separate synthetic ringdown witness and noiseless TDM plant, shared scenario clock",
        estimate_sha256=hashlib.sha256(args.estimate.read_bytes()).hexdigest(),
        calibration_sha256=hashlib.sha256(args.calibration.read_bytes()).hexdigest(),
        reused_estimator_runs=32,plant_trajectories=40,legacy_max_delta_mrad_s=delta,
        windows_s=WINDOWS,methods=list(METHODS),summary=summarize(rows),rows=rows)
    args.output.write_text(json.dumps(report,ensure_ascii=False,allow_nan=False)+"\n",encoding="utf-8")
