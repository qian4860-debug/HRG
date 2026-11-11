"""编译并运行五电极 RTL 回放与闭环记分板，使用 MATLAB 导出的对照文件。"""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import tempfile


CASES = {
    # 数字分时、DAC 分频、机电仿真状态数。物理拓扑差异在机电矩阵内。
    "continuous": (0, 1, 26),
    "tdm_shared": (1, 1, 26),
    "tdm_shared_div25": (1, 25, 26),
    "continuous_overload": (0, 1, 26),
    "tdm_shared_overload": (1, 1, 26),
    "tdm_separate": (1, 1, 18),
    "tdm_separate_div25": (1, 25, 18),
}


def find_program(tool, bin_dir):
    # 优先使用显式选择的便携工具目录，支持 Windows 与 Linux。
    search = str(bin_dir) if bin_dir else None
    result = shutil.which(tool, path=search)
    if not result:
        raise SystemExit(f"找不到 {tool}，请设置 PATH 或传入 --bin。")
    return str(Path(result).resolve())


def run_case(stage, toolchain, env, scenario, vcd_dir):
    tdm, divisor, plant_states = CASES[scenario]
    compiler, runtime = toolchain
    # 同一场景先跑逐拍回放，再跑独立机电模型。过载用例使用回放检验失锁。
    tops = ["tb_hrg_five_digital"]
    if not scenario.endswith("_overload"):
        tops.append("tb_hrg_five_closed_loop")
    for top in tops:
        closed_loop = top.endswith("_closed_loop")
        sources = ["hrg_five_digital.v", f"{top}.sv"]
        parameters = [f"-P{top}.TDM={tdm}", f"-P{top}.DAC_DIVISOR={divisor}"]
        if closed_loop:
            sources.append("hrg_five_analog_plant.sv")
            parameters.append(f"-P{top}.PLANT_STATES={plant_states}")
        executable = f"{top}.vvp"
        subprocess.run(
            [
                compiler, "-g2012", "-I.", "-s", top, "-o", executable,
                *parameters, *sources,
            ],
            cwd=stage,
            env=env,
            check=True,
        )
        options = [f"+case={scenario}"]
        if vcd_dir and not closed_loop:
            options.append("+vcd")
        subprocess.run([runtime, executable, *options], cwd=stage, env=env, check=True)
        if vcd_dir and not closed_loop:
            shutil.copyfile(stage / "five_digital.vcd", vcd_dir / f"{scenario}.vcd")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("vectors", type=Path, help="five_rtl_vectors 生成的目录")
    parser.add_argument("--bin", type=Path, help="含 iverilog 和 vvp 的目录")
    parser.add_argument("--cases", nargs="+", choices=CASES, default=list(CASES)[:2])
    parser.add_argument("--vcd-dir", type=Path, help="导出数字核 VCD 波形的目录")
    args = parser.parse_args()
    tools = (find_program("iverilog", args.bin), find_program("vvp", args.bin))
    env = os.environ.copy()
    env["PATH"] = os.pathsep.join([str(Path(tools[0]).parent), env.get("PATH", "")])
    if args.vcd_dir:
        args.vcd_dir.mkdir(parents=True, exist_ok=True)
    source_dir = Path(__file__).resolve().parent
    # 仅将所需源文件和对照数据放在临时工作目录，避免在工程里生成大文件。
    with tempfile.TemporaryDirectory(prefix="five_rtl_") as temp:
        stage = Path(temp)
        for pattern in ("*.v", "*.vh", "*.sv"):
            for source in source_dir.glob(pattern):
                shutil.copyfile(source, stage / source.name)
        for scenario in args.cases:
            for suffix in (".cfg", ".vec", ".plant"):
                if suffix == ".plant" and scenario.endswith("_overload"):
                    continue
                name = scenario + suffix
                shutil.copyfile(args.vectors / name, stage / name)
            run_case(stage, tools, env, scenario, args.vcd_dir)


if __name__ == "__main__":
    main()
