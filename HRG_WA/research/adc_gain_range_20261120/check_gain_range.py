"""复核第54号的输入折算LSB、削顶统计、速率与成对增益；汇总逐拍回执。"""
import argparse
import json
import math
from pathlib import Path


def load(file):
    return json.loads(file.read_text(encoding="utf-8"))


def verify(folder, project):
    """逐条检查判据；将训练角和留出角按配置分列，缺帧不评分。"""
    files = sorted(folder.glob("profile_*.json"))
    profiles = [load(file) for file in files]
    ids = {p["profile"] for p in profiles}
    assert set(range(1, 15)) == ids and len(ids) == len(profiles)
    previous = project / "research/split_converter_20261119"
    compressed = []
    for profile in profiles:
        bits, gain, span = (profile[key] for key in ("adc_bits", "gain", "span_Vpp"))
        step = span / 2**bits
        assert math.isclose(profile["input_lsb_uV"], 1e6 * step / gain)
        assert profile["fs_Hz"] == 5_440_000 and profile["split_Hz"] == .05
        cases = {c["rate_mrad_s"]: c for c in profile["cases"]}
        assert len(cases) == len(profile["cases"]) == 5
        assert set(cases) == {-1, -.3, 0, .3, 1}
        pair_stats = []
        for c in cases.values():
            p0, p1 = c["connected_valid_peak_V"]
            m0, m1 = c["connected_valid_margin_V"]
            assert p0 >= p1 >= 0 and m0 <= m1 + 1e-12
            for peak, margin in zip((p0, p1), (m0, m1)):
                assert span/2-step-peak-1e-12 <= margin <= span/2-peak+1e-12
            assert (c["adc_clipped_ticks"] > 0) == (m1 < 0)
            available = c["valid_frames"] == c["frame_count"] and c["adc_clipped_ticks"] == c["dac_clipped_ticks"] == 0
            for w in range(2):
                error = c["corrected_error_mrad_s"][w]
                assert available == (error is not None)
                assert c["individual_pass"][w] == (available and abs(error) <= .25)
                if available:
                    assert math.isclose(c["corrected_rate_mrad_s"][w], error+c["rate_mrad_s"], abs_tol=1e-12)
        for amplitude in (.3, 1):
            for w in range(2):
                pos = cases[amplitude]["corrected_rate_mrad_s"][w]
                neg = cases[-amplitude]["corrected_rate_mrad_s"][w]
                g = None if pos is None or neg is None else (pos-neg)/(2*amplitude)
                correct = g is not None and neg < 0 < pos
                passed = correct and abs(g-1) <= .05 and all(cases[r]["individual_pass"][w] for r in (-amplitude,amplitude))
                pair_stats.append(dict(window_index=w,amplitude_mrad_s=amplitude,gain=g,directions_ok=correct,passed=passed))
        baseline_delta=None
        if profile["profile"] in (1, 8):
            old=load(previous / f"adc{bits}_comparison.json")
            baseline_delta=max(abs(cases[r["truth_mrad_s"]]["corrected_error_mrad_s"][w]-
                                   r["raw_corrected_error_mrad_s"][w][1])
                               for r in old["cases"] if r["phase_deg"]==0 for w in range(2))
            assert baseline_delta < 1e-7
        compressed.append(dict(profile=profile["profile"],bits=bits,gain=gain,span_Vpp=span,beta_deg=profile["beta_deg"],
               input_lsb_uV=profile["input_lsb_uV"],min_connected_margin_V=min(c["connected_valid_margin_V"][0] for c in cases.values()),
               min_valid_margin_V=min(c["connected_valid_margin_V"][1] for c in cases.values()),
               adc_clipped_ticks=sum(c["adc_clipped_ticks"] for c in cases.values()),
               dac_clipped_ticks=sum(c["dac_clipped_ticks"] for c in cases.values()),
               valid_frames=sum(c["valid_frames"] for c in cases.values()),frames=sum(c["frame_count"] for c in cases.values()),
               rate_pass=[sum(c["individual_pass"][w] for c in cases.values()) for w in range(2)],
               pair_pass=[sum(p["passed"] for p in pair_stats if p["window_index"]==w) for w in range(2)],
               pairs=pair_stats,max_history_delta_mrad_s=baseline_delta))
    # 同一量化码宽与限幅范围折算到前置增益之前一致时，速率轨迹应一致。
    for pair in [(2,3), (11,12)]:
        equivalent = [next(p for p in profiles if p["profile"]==i) for i in pair]
        for a,b in zip(equivalent[0]["cases"],equivalent[1]["cases"]):
            assert a["rate_mrad_s"] == b["rate_mrad_s"] and a["adc_clipped_ticks"] == b["adc_clipped_ticks"]
            for x,y in zip(a["corrected_error_mrad_s"],b["corrected_error_mrad_s"]):
                assert (x is None and y is None) or math.isclose(x,y,abs_tol=1e-9)
    baseline=next(p for p in profiles if p["profile"]==1)
    pk=max(c["connected_valid_peak_V"][0] for c in baseline["cases"])
    # 用基线轨迹外推对称峰值给出扫增益起点；真实边界仍须由重跑闭环判定。
    rail=baseline["span_Vpp"]*(.5-2**(-baseline["adc_bits"]))
    return dict(scope="5.44 MSPS noiseless closed loop, 2 window scores; physical overload dynamics excluded",
                baseline_connected_peak_V=pk,baseline_gain_ceiling_if_waveform_unchanged=baseline["gain"]*rail/pk,
                windows_s=[[.02,.06],[.16,.24]],rate_limit_mrad_s=.25,gain_tolerance=.05,profiles=compressed)


if __name__=="__main__":
    here=Path(__file__).resolve().parent
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--folder",type=Path,default=here)
    parser.add_argument("--project",type=Path,default=here.parents[1])
    args=parser.parse_args()
    data=verify(args.folder,args.project)
    (args.folder/"gain_range_scoreboard.json").write_text(json.dumps(data,indent=2,allow_nan=False)+"\n",encoding="utf-8",newline="\n")
    for p in data["profiles"]:
        print(p["profile"],p["rate_pass"],p["pair_pass"],p["min_connected_margin_V"],p["adc_clipped_ticks"])
