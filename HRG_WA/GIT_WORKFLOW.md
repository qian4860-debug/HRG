# 项目 Git 版本管理

本地仓库位于本目录，分支为 `main`。源码、参考向量、testbench、运行脚本和验证摘要均纳入管理；论文原件、压缩包、MAT文件、第三方vendor目录及仿真构建缓存保持本地并由 `.gitignore` 排除。

2026-10-21按用户授权配置远端 `origin=https://github.com/qian4860-debug/HRG.git`，将已提交工程以普通子目录 `HRG_WA/` 导入 HRG 仓库。导入提交同时连接远端历史和本地历史，原提交哈希及其文件字节保持不变；远端标签使用 `HRG_WA/` 前缀。旧版仍是初次导入时的快照，不表示还原了旧版开发历史。未跟踪的本地文件不会上传。

本地 `main` 保持工程根目录布局，远端 `main` 使用父仓库布局，因此不要在本地直接执行 `git pull origin main` 或 `git push origin main`。后续本地修改验证并提交后，使用：

```powershell
python tools/sync_github_subproject.py             # 生成并校验本地导入提交，不推送
python tools/sync_github_subproject.py --push      # 获得该次推送授权后执行
# 如需使用当前 Windows 系统代理，可追加 --proxy http://127.0.0.1:7897
```

脚本保留父仓库其他目录，校验子目录树对象完全相同，并拒绝覆盖本地历史中不存在的远端子项目修改；推送不使用 force，分支和标签原子提交。`codex/github-hrg-wa` 为本地生成的导入分支。GitHub 上直接编辑过子项目时需先协调这些修改，不能直接覆盖。

基线提交 `c61523f` 保存2026-10-16开始修改前的模型与RTL，包含此前1698处前端字段差异。标签 `baseline-20261016` 标记此状态。后续修订将RTL/验证和文档证据分开提交。

实现提交 `59842c9` 包含本轮RTL和scoreboard；随后提交验证记录、参考向量溯源与使用文档。标签 `rtl-closed-loop-20261016` 标记交付版本。

2026-10-18增加单文件表头配置、MATLAB/SPI生成和RTL构建参数核对。使用说明位于 `HRG_WA_Digital_ASIC_MATLAB_v4_6_5_FRP_validation_fix/HRG_WA/config/README_表头配置.md`；默认参数仍标为未实测。配置文件、生成的默认输出、已完成构建清单与验证记录一并纳入Git。

常用命令（在项目根目录执行）：

```powershell
git status
git log --oneline --decorate
git diff baseline-20261016 -- HRG_WA_Digital_ASIC_MATLAB_v4_6_5_FRP_validation_fix/HRG_WA
git show baseline-20261016:HRG_WA_Digital_ASIC_MATLAB_v4_6_5_FRP_validation_fix/HRG_WA/src/hrg_dsp_core.v
```

本次自动提交使用命令级作者 `Codex <codex@local>`，没有改写全局用户名或邮箱。后续人工提交可使用用户自己的 Git 身份。
