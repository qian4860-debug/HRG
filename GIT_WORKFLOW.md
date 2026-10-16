# 项目 Git 版本管理

本地仓库位于本目录，分支为 `main`。源码、参考向量、testbench、运行脚本和验证摘要均纳入管理；论文原件、压缩包、MAT文件、第三方vendor目录及仿真构建缓存保持本地并由 `.gitignore` 排除。未配置远端、未上传文件。

基线提交 `c61523f` 保存2026-10-16开始修改前的模型与RTL，包含此前1698处前端字段差异。标签 `baseline-20261016` 标记此状态。后续修订将RTL/验证和文档证据分开提交。

实现提交 `59842c9` 包含本轮RTL和scoreboard；随后提交验证记录、参考向量溯源与使用文档。标签 `rtl-closed-loop-20261016` 标记交付版本。

常用命令（在项目根目录执行）：

```powershell
git status
git log --oneline --decorate
git diff baseline-20261016 -- HRG_WA_Digital_ASIC_MATLAB_v4_6_5_FRP_validation_fix/HRG_WA
git show baseline-20261016:HRG_WA_Digital_ASIC_MATLAB_v4_6_5_FRP_validation_fix/HRG_WA/src/hrg_dsp_core.v
```

本次自动提交使用命令级作者 `Codex <codex@local>`，没有改写全局用户名或邮箱。后续人工提交可使用用户自己的 Git 身份。
