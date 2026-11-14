"""全角陀螺 TDM 读出 ADC 的一阶预算。

用途：把 6.8 kHz 载波、5.44 MS/s、1 Vpp 差分、800 点/窗等系统条件，
换算成位数、采样电容、比较器噪声、SAR 时序、Pipeline 残差放大器、
参考电荷与时间戳相位。所有结果是一阶筛选值，不是晶体管级后仿结论。

单位约定：
- VFS 为差分峰峰值，V；LSB=VFS/2**N。
- 电容为每边采样电容 Cs，F；差分 kT/C 噪声为 sqrt(2kT/Cs)。
- 时间 ns，频率 MHz，电流 uA，功耗 mW，角度 mrad。
"""
from __future__ import annotations

import json
import math
from pathlib import Path

KB = 1.380649e-23
TEMP_K = 300.0
KT = KB * TEMP_K


def noise_table(vfs: float = 1.0, nwin: int = 800, amp: float = 0.5) -> list[dict]:
    """量化、kT/C、比较器、参考噪声的 RSS，以及 800 点 I/Q 后的角度噪声。"""
    rows = []
    for nbits in (10, 12, 14):
        lsb = vfs / 2**nbits
        q = lsb / math.sqrt(12)
        for cs in (2e-12, 4e-12):
            ktc = math.sqrt(2 * KT / cs)
            comp = 50e-6
            ref = 30e-6
            total = math.sqrt(q**2 + ktc**2 + comp**2 + ref**2)
            snr = 20 * math.log10((vfs / (2 * math.sqrt(2))) / total)
            # 整周期、白噪声、单位权重时，单个 I/Q 分量标准差约 sigma*sqrt(2/N)。
            sigma_iq = total * math.sqrt(2 / nwin)
            # 小误差、theta=0 附近的一阶角度灵敏度约为 sigma_IQ/(2a)。
            angle = sigma_iq / (2 * amp)
            rows.append(
                {
                    "bits": nbits,
                    "cs_pF": cs * 1e12,
                    "lsb_uV": lsb * 1e6,
                    "quantization_uV": q * 1e6,
                    "ktc_uV": ktc * 1e6,
                    "comparator_uV": comp * 1e6,
                    "reference_uV": ref * 1e6,
                    "total_uV": total * 1e6,
                    "snr_dB": snr,
                    "sigma_iq_uV": sigma_iq * 1e6,
                    "angle_mrad_first_order": angle * 1e3,
                }
            )
    return rows


def timing_table(vfs: float = 1.0) -> list[dict]:
    """SAR 单次转换时序：N+1 次比较（含 1 位冗余），加跟踪与接口开销。"""
    rows = []
    overhead_ns = 24.0
    for fs in (2.72e6, 5.44e6, 6.8e6):
        period = 1 / fs * 1e9
        for nbits in (10, 12, 14):
            for tbit_ns in (8.0, 10.0):
                for track_ns in (45.0, 55.0):
                    ncomp = nbits + 1
                    conv_ns = ncomp * tbit_ns
                    total_ns = track_ns + conv_ns + overhead_ns
                    rows.append(
                        {
                            "fs_MSs": fs / 1e6,
                            "bits": nbits,
                            "comparisons": ncomp,
                            "tbit_ns": tbit_ns,
                            "track_ns": track_ns,
                            "conversion_ns": conv_ns,
                            "overhead_ns": overhead_ns,
                            "total_ns": total_ns,
                            "period_ns": period,
                            "margin_ns": period - total_ns,
                            "margin_percent": (period - total_ns) / period * 100,
                        }
                    )
    return rows


def pipeline_ota_table(vfs: float = 1.0, tsettle_ns: float = 35.0) -> list[dict]:
    """闭环 MDAC 的建立、GBW、gm 与静态电流。

    误差分配为 0.25 个输入 LSB；输出误差 = 0.25*LSB*G。
    建立阶跃取 0.5 V 差分，按单极点 ln(step/error) 个时间常数估算。
    """
    rows = []
    for nbits, gain in ((12, 16), (14, 32)):
        beta = 1 / gain
        lsb = vfs / 2**nbits
        err_out = 0.25 * lsb * gain
        ntau = math.log(0.5 / err_out)
        tau = tsettle_ns * 1e-9 / ntau
        f3 = 1 / (2 * math.pi * tau)
        gbw = f3 / beta
        gm = 2 * math.pi * gbw * 1e-12
        for gm_id in (15, 20, 25):
            i_gm = gm / gm_id
            # 0.5 V 差分跳变、每端 0.25 V、负载 1 pF、10 ns 压摆。
            i_slew = 0.25 * 1e-12 / 10e-9
            i_total = 1.2 * (i_gm + i_slew)  # 预留 20% CMFB/偏置
            rows.append(
                {
                    "bits": nbits,
                    "gain": gain,
                    "beta": beta,
                    "error_out_mV": err_out * 1e3,
                    "ntau": ntau,
                    "tau_ns": tau * 1e9,
                    "f3_MHz": f3 / 1e6,
                    "gbw_MHz": gbw / 1e6,
                    "gm_mS": gm * 1e3,
                    "gm_id": gm_id,
                    "i_gm_uA": i_gm * 1e6,
                    "i_slew_uA": i_slew * 1e6,
                    "i_total_uA": i_total * 1e6,
                    "p_total_mW": i_total * 1.8 * 1e3,
                }
            )
    return rows


def latency_table(f0: float = 6.8e3, fs: float = 5.44e6) -> list[dict]:
    """固定流水延迟折算到载波相位；时间戳对齐后可消除该固定相移。"""
    return [
        {
            "cycles": n,
            "latency_us": n / fs * 1e6,
            "phase_deg": 360 * f0 * n / fs,
            "window_percent": n / fs / 147.06e-6 * 100,
        }
        for n in (2, 3, 5)
    ]


def reference_table(vfs: float = 1.0) -> list[dict]:
    """参考电荷与去耦初估；实际由缓冲输出阻抗、ESR/ESL 与局部去耦共同决定。"""
    rows = []
    for cs_pf in (1.0, 2.0, 4.0):
        charge = cs_pf * 1e-12 * vfs
        for droop_mv in (0.06104, 1.0, 10.0):
            rows.append(
                {
                    "cs_pF": cs_pf,
                    "charge_pC": charge * 1e12,
                    "droop_mV": droop_mv,
                    "cdec_nF": charge / (droop_mv * 1e-3) * 1e9,
                }
            )
    return rows


def fom_table() -> list[dict]:
    """Walden FOM 的量级对照；用于说明 12b/5.44MS/s 不可能靠 FOM 取胜。"""
    rows = []
    for power_mw in (0.2, 0.3, 0.5, 1.0):
        for nbits, fs in ((12, 5.44e6), (14, 5.44e6)):
            rows.append(
                {
                    "bits": nbits,
                    "fs_MSs": fs / 1e6,
                    "power_mW": power_mw,
                    "fom_fJ_per_step": power_mw * 1e-3 / (2**nbits * fs) * 1e12,
                }
            )
    return rows


def main() -> None:
    out = {
        "assumptions": {
            "temperature_K": TEMP_K,
            "vfs_diff_Vpp": 1.0,
            "signal_peak_V": 0.5,
            "window_samples": 800,
            "window_us": 147.06,
            "carrier_Hz": 6.8e3,
            "fs_Hz": 5.44e6,
            "note": "一阶预算；角度灵敏度按 theta=0 附近 sigma_IQ/(2a) 估算，精确值用系统模型雅可比。",
        },
        "noise": noise_table(),
        "timing": timing_table(),
        "pipeline_ota": pipeline_ota_table(),
        "latency": latency_table(),
        "reference": reference_table(),
        "fom": fom_table(),
    }
    path = Path(__file__).with_name("adc_budget.json")
    path.write_text(json.dumps(out, indent=2, ensure_ascii=False) + "\n", encoding="utf-8", newline="\n")
    print(json.dumps(out, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
