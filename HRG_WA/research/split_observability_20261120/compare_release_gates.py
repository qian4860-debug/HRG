"""在相同第53号轨迹上配对比较两个发布门。真值只在离线评分中使用。"""
import argparse
from collections import defaultdict
import hashlib
import json
from pathlib import Path

import numpy as np


# 每0.5秒刷新参考包，闭环一帧为1/1700秒。阶跃时间由被测仿真工况定义。
FRAME_HZ = 1700
FRAMES = 20 * FRAME_HZ
EVENT_S = 10.25
SPLIT_BUDGET_MHZ = 0.71
RATE_BUDGET_MRAD_S = 0.25
LABELS = ["withheld", "released_within_budget", "released_over_budget"]
MODES = {"tdm_shared", "tdm_separate"}
RATES = {-1.0, -0.3, 0.0, 0.3, 1.0}


def read(path):
    return json.loads(path.read_text(encoding="utf-8"))


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def measured_frames(rows, truth):
    """独立地按包的时间区间逐段铺帧。过期值可用于离线诊断，发布门仍丢弃。"""
    clock = np.arange(len(truth)) / FRAME_HZ
    states = np.zeros(len(clock), dtype=int)
    diagnostic = np.full(len(clock), np.nan)
    for i, row in enumerate(rows):
        start = np.searchsorted(clock + 1e-12, row["t_s"])
        stop = (np.searchsorted(clock + 1e-12, rows[i+1]["t_s"])
                if i+1 < len(rows) else len(clock))
        freq = row["split_est_mHz"]
        if freq is None or not np.isfinite(freq):
            continue
        diagnostic[start:stop] = freq
        if not row["valid"] or abs(freq) > 50:
            continue
        end = min(stop, np.searchsorted(clock, row["valid_until_s"]-1e-12))
        if end > start:
            states[start:end] = 1 + (abs(freq-truth[start:end]) > SPLIT_BUDGET_MHZ).astype(int)
    held = states == 0
    finite = np.isfinite(diagnostic)
    could_fit = np.abs(diagnostic-truth) <= SPLIT_BUDGET_MHZ
    rejected = [int(np.sum(held & finite & could_fit)), int(np.sum(held & finite & ~could_fit)),
                int(np.sum(held & ~finite))]
    assert sum(rejected) == int(np.sum(held))
    return states, rejected


def paired(old, new):
    """行代表旧门，列代表新门；同一帧或同一窗口只进入一个格子。"""
    old, new = np.asarray(old,dtype=int), np.asarray(new,dtype=int)
    assert old.shape == new.shape
    return np.bincount(3*old+new,minlength=9).reshape(3,3)


def rate_states(errors):
    """未提供斜率的窗口只能记为拒发。全量窗口分母包括这些窗口。"""
    return [0 if x is None else 1 if abs(x)<=RATE_BUDGET_MRAD_S else 2 for x in errors]


def paired_rate_states(plus,minus,speed):
    """两端均可用才放行该速度对。分别检验正负方向、5%成对增益及两端绝对误差。"""
    states=[]
    for p,n in zip(plus,minus,strict=True):
        if p is None or n is None:
            states.append(0)
            continue
        pos,neg=speed+p,-speed+n
        gain=(pos-neg)/(2*speed)
        success=neg<0<pos and abs(gain-1)<=.05 and max(abs(p),abs(n))<=RATE_BUDGET_MRAD_S
        states.append(1 if success else 2)
    return states


def transitions(matrix):
    total=int(matrix.sum())
    return dict(matrix=matrix.tolist(), total=total,
                old_released=int(matrix[1:,:].sum()),new_released=int(matrix[:,1:].sum()),
                old_false_release=int(matrix[2,:].sum()),new_false_release=int(matrix[:,2].sum()),
                old_good_now_withheld=int(matrix[1,0]),old_bad_now_withheld=int(matrix[2,0]),
                old_bad_now_corrected=int(matrix[2,1]),new_bad_from_prior_good_or_withheld=int(matrix[:2,2].sum()))


def replay_by_run(payload):
    by_run = defaultdict(dict)
    for row in payload["rows"]:
        run, mode, rate = row["run_id"],row["mode"],row["rate_mrad_s"]
        assert (mode,rate) not in by_run[run]
        by_run[run][mode,rate]=row
    return by_run


def readings_by_run(rows):
    by_run=defaultdict(list)
    for row in rows:
        by_run[row["run_id"]].append(row)
    for group in by_run.values():
        group.sort(key=lambda r:r["t_s"])
        assert [r["t_s"] for r in group] == [k/2 for k in range(1,41)]
        assert all(type(r["valid"]) is bool for r in group)
    return by_run


def compare(old_est, new_est, old_replay, new_replay):
    inputs=[old_est,new_est,old_replay,new_replay]
    old_e, new_e, old_r, new_r = [read(p) for p in inputs]
    assert old_e["budget_mHz"] == new_e["budget_mHz"] == SPLIT_BUDGET_MHZ
    for estimates,replay in [(old_est,old_r),(new_est,new_r)]:
        assert sha256(estimates)==replay["estimate_sha256"]
    assert old_r["windows_s"]==new_r["windows_s"] and len(old_r["windows_s"])==6
    assert old_r["calibration_sha256"]==new_r["calibration_sha256"]
    e0,e1 = readings_by_run(old_e["rows"]),readings_by_run(new_e["rows"])
    r0,r1 = replay_by_run(old_r),replay_by_run(new_r)
    assert e0.keys()==e1.keys()==r0.keys()==r1.keys() and len(e0)==32
    clock = np.arange(FRAMES)/FRAME_HZ
    runs=[]; frame_totals={}; window_totals={}
    for run in sorted(e0):
        a,b=e0[run],e1[run]
        case=a[0]["case_name"]
        first=a[0]["split_true_mHz"]
        truth=np.where((case=="split_step") & (clock>=EVENT_S),25.0,first)
        for p,q in zip(a,b):
            assert p["case_name"]==q["case_name"]==case
            expected=25.0 if case=="split_step" and p["t_s"]>EVENT_S else first
            assert p["split_true_mHz"]==q["split_true_mHz"]==expected
        old, od = measured_frames(a,truth)
        new, nd = measured_frames(b,truth)
        matrix=paired(old,new)
        f=frame_totals.setdefault(case,dict(count=0,matrix=np.zeros((3,3),int),
                                            old_rejected=np.zeros(3,int),new_rejected=np.zeros(3,int)))
        f["count"]+=1
        f["matrix"]+=matrix
        f["old_rejected"]+=od
        f["new_rejected"]+=nd
        rec=dict(run_id=run,case_name=case, frames=transitions(matrix),
                 old_rejected_diagnostics=od,new_rejected_diagnostics=nd,modes={})
        expect={(mode,rate) for mode in MODES for rate in RATES}
        assert r0[run].keys()==r1[run].keys()==expect
        for mode in sorted(MODES):
            metrics=defaultdict(lambda:np.zeros((3,3),int))
            for rate in sorted(RATES):
                op,np_row=r0[run][mode,rate],r1[run][mode,rate]
                assert op["case_name"]==np_row["case_name"]==case
                om,nm=op["methods"],np_row["methods"]
                # 三条不依赖新门的基线必须一致，防止两份回执配错轨迹。
                for base in ("raw","ideal","held50"):
                    assert om[base]==nm[base]
                o,n=om["estimated"],nm["estimated"]
                for states,info in [(old,o),(new,n)]:
                    assert abs((states!=0).mean()-info["frame_coverage"])<=0.5001e-6
                windows={"late_windows":(o["window_errors"][2:],n["window_errors"][2:],4),
                         "all_half_seconds":(o["half_s_errors"],n["half_s_errors"],40)}
                if case=="split_step":
                    windows["after_step"]=(o["post_event_half_s_errors"],n["post_event_half_s_errors"],19)
                for tag,(oe,ne,count) in windows.items():
                    assert len(oe)==len(ne)==count
                    metrics[tag]+=paired(rate_states(oe),rate_states(ne))
            for speed in (0.3,1.0):
                pair=[]
                for replay in (r0,r1):
                    plus=replay[run][mode,speed]["methods"]["estimated"]["window_errors"][2:]
                    minus=replay[run][mode,-speed]["methods"]["estimated"]["window_errors"][2:]
                    pair.append(paired_rate_states(plus,minus,speed))
                metrics[f"late_signed_pair_{speed:g}_mrad_s"]=paired(*pair)
            rec["modes"][mode]={tag:transitions(mat) for tag,mat in metrics.items()}
            for tag,mat in metrics.items():
                key=(case,mode,tag)
                window_totals.setdefault(key,np.zeros((3,3),int))
                window_totals[key]+=mat
        runs.append(rec)
    return dict(scope="paired 20 s witness runs; modes and speeds reuse the same witnesses",
                state_order=LABELS, rejected_diagnostic_order=["finite_within_budget","finite_over_budget","no_finite_candidate"],
                units=dict(frame_threshold_mHz=SPLIT_BUDGET_MHZ,rate_threshold_mrad_s=RATE_BUDGET_MRAD_S),
                sha256=dict(zip(["old_estimates","new_estimates","old_replay","new_replay"],map(sha256,inputs))),
                frame_by_case={key:dict(runs=v["count"],**transitions(v["matrix"]),
                    old_rejected_diagnostics=v["old_rejected"].tolist(),new_rejected_diagnostics=v["new_rejected"].tolist())
                    for key,v in frame_totals.items()},
                rate_by_case_mode=[dict(case_name=c,mode=m,window=w,runs=frame_totals[c]["count"],
                    **transitions(mat)) for (c,m,w),mat in sorted(window_totals.items())],runs=runs)


def self_test():
    """用手算九格、阈值边沿、跨频差阶跃的旧包、过期与上电空帧自检。"""
    statuses=[0,0,0,1,1,1,2,2,2]
    nine=paired(statuses,[0,1,2,0,1,2,0,1,2])
    assert np.array_equal(nine,np.ones((3,3),int))
    assert rate_states([None,-.25,.25001])==[0,1,2]
    assert paired_rate_states([0,.2,.35,None],[.01,0,.35,0],.3)==[1,2,2,0]
    rows=[dict(t_s=1/FRAME_HZ,split_est_mHz=50,valid=True,valid_until_s=4/FRAME_HZ),
          dict(t_s=5/FRAME_HZ,split_est_mHz=50.1,valid=True,valid_until_s=7/FRAME_HZ)]
    truth=np.array([50,50,50,25,25,25,25])
    st,diag=measured_frames(rows,truth)
    assert st.tolist()==[0,1,1,2,0,0,0] and diag==[0,3,1]
    print("Paired transitions, truth step, estimator expiry, calibration edge and rate boundary passed.")


if __name__=="__main__":
    cli=argparse.ArgumentParser(description=__doc__)
    for name in ["old-estimates","new-estimates","old-replay","new-replay","output"]:
        cli.add_argument("--"+name,type=Path)
    cli.add_argument("--self-test",action="store_true")
    args=cli.parse_args()
    if args.self_test:
        self_test()
    if args.output:
        if None in (args.old_estimates,args.new_estimates,args.old_replay,args.new_replay):
            cli.error("需同时提供新旧测频与速率回执")
        result=compare(args.old_estimates,args.new_estimates,args.old_replay,args.new_replay)
        args.output.write_text(json.dumps(result,indent=2,ensure_ascii=False,allow_nan=False)+"\n",
                               encoding="utf-8",newline="\n")
        print(f"{len(result['runs'])} paired runs verified.")
    elif not args.self_test:
        cli.error("请指定 --output 或 --self-test")
