# 全角陀螺一级引用文献获取记录

获取批次始于2026-10-23，登记完成于2026-10-24。范围为既有目录中26篇本地全角/紧密相关论文及学位论文，以及原80条网上记录中新增37项学术种子的一级引用；不递归扩展新下载论文的引用。网上题录原始级别不因取得引用元数据而升级为全文已读。

归并后 1170 组题录，844 个已核对 DOI。没有 DOI 的异写题录仍可能重复，不能将该组数称为完全去重的独立论文数。

新增且通过字节/PDF检查的文章文件 109 份；另有修复种子综述1份、Bryan原始期刊卷1份。Bryan摘页包含在新增文章文件中，未重复计数。

本地目录：`D:/学习资料/资料/全角陀螺/引用文献_20261023`。原始PDF、未完成下载和缓存不上传GitHub；代码、引用关系、获取状态和哈希纳入工程Git。下载并不等于全文已读或公式已核验。

## Bryan 与 Lynch

- Bryan 1890：已从原卷获得全文，印刷页101–111；原卷PDF175–185页。另存11页摘页，各页内容流与原卷相同，整卷字节数和MD5与档案馆记录相符。末页同时开始下一篇文章，保留整页并注明边界。
- Lynch 1995平均法论文：尚未取得可验证全文，不能用引用它的论文或题录代替。
- Lynch 1998 Coriolis Vibratory Gyros：找到会议目录及IEEE1431附录B重印的出处线索，尚未取得可验证全文。IEEE官方页面列为购买/订阅访问。

## 聚合来源及限制

公开检索、Crossref出版方引用登记、OpenAlex公开版本位置、出版方直链、作者实验室及大学仓储、互联网档案馆。Scholar曾读到首页，但查询/后续连接失败；WoS仅看到用户打开的检索标签，未取得结果正文或导出，未计入已完成搜索。

HTML、目录PDF、身份不匹配、类型冲突和缺尾PDF不计为目标全文成功。公开服务器403不自动等同于付费墙，具体失败原因保留在记录中。

|状态|归并题录组数|
|---|---|
|downloaded_verified|104|
|existing_local|11|
|fulltext_unavailable_from_checked_sources|733|
|needs_bibliographic_version_review|5|
|needs_search_no_verified_identifier|295|
|nonpaper_reference_not_downloaded|21|
|related_version_not_cited_work|1|

## 可复查文件

- `sources.json`：种子文件、哈希、解析范围、缺号人工恢复、出版方参考文献数。
- `online_seed_coverage.json`：原有80条网上记录的逐项覆盖、重复、非论文与失败状态。
- `references.json`：全部提取异写、引用关系、元数据和获取尝试。
- `canonical_works.json`：按DOI/明确题名归并的工作索引。
- `fulltext_manifest.json`：实际文件字节哈希、PDF页数和最终检查。
- `manual_citation_corrections.json`、`manual_download_links.json`：人工补充的依据。
- `bryan_original_receipt.json`：公版原卷与摘页的对应关系。

- `rejected_local_matches.json`：最终审计拒绝的4条本地误匹配及原因；这些文件未被当作目标论文成功计数。

## 复核入口

`python -m unittest discover -s tools -p test_wa_acquisition.py`检查身份识别边界；`python tools/finalize_wa_acquisition.py`重新核对已保存文件及清单；`python tools/install_wa_acquisition_index.py`更新本机参考技能索引。

原始引文提取入口`tools/acquire_wa_citations.py extract`会重建原始记录，不应对已补充人工证据的最终清单无备份直接重跑。网络获取命令的输出必须再次执行文件审计后才计为最终结果。依赖版本见`tools/requirements-wa-acquisition.txt`。

## 逐项清单

|ID|题名|DOI/待核标识|状态|本地文件|
|---|---|---|---|---|
| W0001 | Vibratory gyro analysis by the method of averaging |  | needs_search_no_verified_identifier |  |
| W0002 | Coriolis Vibratory Gyros |  | existing_local | D:/学习资料/资料/全角陀螺/High_quality_factor_MEMS_gyroscope_with_whole_angle_mode_of_operation.pdf |
| W0003 | On the beats in the vibrations of a revolving cylinder or bell |  | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/Bryan_1890_On_the_beats_original_pages_101-111.pdf |
| W0004 | Micromechanical Rate Integrating Gyroscope With Angle-Dependent Bias Compensation Using a Self-Precession Method | 10.1109/jsen.2018.2810843 | fulltext_unavailable_from_checked_sources |  |
| W0005 | HRG by SAFRAN: The game-changing technology | 10.1109/isiss.2018.8358163 | fulltext_unavailable_from_checked_sources |  |
| W0006 | SpaceNaute® the HRG Based Inertial Reference System of Ariane 6 European space launcher | 10.1134/s2075108719010036 | fulltext_unavailable_from_checked_sources |  |
| W0007 | The hemispherical resonator gyro: From wineglass to the planets |  | needs_search_no_verified_identifier |  |
| W0008 | 半球谐振陀螺误差建模补偿与力平衡控制方法研究 |  | needs_search_no_verified_identifier |  |
| W0009 | 基于最小均方算法的半球谐振子特征参数辨识方 法 | 10.13695/j.cnki.12 | fulltext_unavailable_from_checked_sources |  |
| W0010 | Adaptive compensation of damping asymmetry in whole-angle hemispherical resonator gyroscope | 10.1063/5.0026821 | fulltext_unavailable_from_checked_sources |  |
| W0011 | 0.00016 deg/√hr Angle Random Walk (ARW) and 0.0014 deg/hr Bias Instability (BI) from a 5.2M-Q and 1-cm Precision Shell Integrating (PSI) Gyroscope | 10.1109/inertial48129.2020.9090086 | fulltext_unavailable_from_checked_sources |  |
| W0012 | Decreasing Frequency Splits of Hemispherical Resonators by Chemical Etching | 10.3390/s18113772 | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R0014_Decreasing Frequency Splits of Hemispherical Resonators by Chemical Etching.pdf |
| W0013 | High sensitivity rate-integrating hemispherical resonator gyroscope with dead area compensation for damping asymmetry | 10.1038/s41598-020-80885-y | existing_local | D:/学习资料/资料/全角陀螺/新增资料_20260825/02_控制与信号处理/2021_Dead_Area_Compensation_Rate_Integrating_HRG.pdf |
| W0014 | Identification of Gain Mismatches in Control Electronics of Rate Integrating CVGs | 10.1109/inertial51137.2021.9430479 | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R0016_Identification of Gain Mismatches in Control Electronics of Rate Integrating CVGs.pdf |
| W0015 | A Novel Compensation Method for Eliminating Precession Angular-Rate Bias in MEMS Rate-Integrating Gyroscopes | 10.1109/access.2020.3014661 | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R0017_A Novel Compensation Method for Eliminating Precession Angular-Rate Bias in MEMS Rate-Integrating Gyroscopes.pdf |
| W0016 | Modeling and Compensation of Assembly Inclination Error of Micro Hemispherical Resonator Gyroscope Under Force-to-Rebalance Mode | 10.1109/jsen.2021.3072046 | fulltext_unavailable_from_checked_sources |  |
| W0017 | Modeling, identification and compensation for assembly error of whole-angle mode hemispherical resonator gyro | 10.1016/j.measurement.2022.112064 | fulltext_unavailable_from_checked_sources |  |
| W0018 | Overcoming limitations of Rate Integrating Gyroscopes by virtual rotation | 10.1109/isiss.2016.7435531 | fulltext_unavailable_from_checked_sources |  |
| W0019 | Rate-Integration Gyroscope (RIG) With Gain Self Calibration | 10.1109/jsen.2020.3027739 | fulltext_unavailable_from_checked_sources |  |
| W0020 | SkyNaute by Safran – How the HRG technological breakthrough benefits to a disruptive IRS (Inertial Reference System) for commercial aircraft | 10.1109/iss46986.2019.8943759 | fulltext_unavailable_from_checked_sources |  |
| W0021 | Theory and error analysis of vibrating-member gyroscope | 10.1109/tac.1978.1101785 | fulltext_unavailable_from_checked_sources |  |
| W0022 | The Synthesis Model of Flat-Electrode Hemispherical Resonator Gyro | 10.3390/s19071690 | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R0033_The Synthesis Model of Flat-Electrode Hemispherical Resonator Gyro.pdf |
| W0023 | Virtually rotated MEMS whole angle gyroscope using independently controlled CW/CCW oscillations | 10.1109/isiss.2018.8358135 | fulltext_unavailable_from_checked_sources |  |
| W0024 | 半球谐振陀螺发展综述 |  | needs_search_no_verified_identifier |  |
| W0025 | 半球谐振陀螺的分析与研究 |  | needs_search_no_verified_identifier |  |
| W0026 | 半球谐振陀螺研究现状、关键技术和发展趋势分析 |  | needs_search_no_verified_identifier |  |
| W0027 | 基于最小均方算法的半球谐振子特征参数辨识方法 |  | needs_search_no_verified_identifier |  |
| W0028 | 检测信号非线性引起的 全角半球谐振陀螺漂移模型 |  | needs_search_no_verified_identifier |  |
| W0029 | 半球谐振陀螺研究现状与发展趋势 | 10.19306/j.cnki.2095 | fulltext_unavailable_from_checked_sources |  |
| W0030 | 3D Dual-Shell Micro-Resonators for Harsh Environments | 10.1109/plans46316.2020.9109972 | fulltext_unavailable_from_checked_sources |  |
| W0031 | Balancing of hemispherical resonator gyros by chemical etching | 10.1134/s2075108715030025 | fulltext_unavailable_from_checked_sources |  |
| W0032 | Compensation of Assembly Eccentricity Error of Micro Hemispherical Resonator Gyroscope | 10.1109/rose52750.2021.9611757 | fulltext_unavailable_from_checked_sources |  |
| W0033 | Design and Verification of a Digital Controller for a 2-Piece Hemispherical Resonator Gyroscope | 10.3390/s16040555 | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R0038_Design and Verification of a Digital Controller for a 2-Piece Hemispherical Resonator Gyroscope.pdf |
| W0034 | Effect of Uneven Electrostatic Forces on the Dynamic Characteristics of Capacitive Hemispherical Resonator Gyroscopes | 10.3390/s19061291 | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R0039_Effect of Uneven Electrostatic Forces on the Dynamic Characteristics of Capacitive Hemispherical Resonator Gyroscop.pdf |
| W0035 | Electronic Gain Error Compensation For Whole-Angle Mode Coriolis Vibrating Gyroscopes With High Q Factor | 10.1109/inertial48129.2020.9090062 | fulltext_unavailable_from_checked_sources |  |
| W0036 | A MEMS Rate-Integrating Gyroscope (RIG) With In-Run Automatic Mode-Matching | 10.1109/jsen.2021.3137245 | fulltext_unavailable_from_checked_sources |  |
| W0037 | 2019 DGON Inertial Sensors and Systems (ISS) | 10.1109/iss46986.2019 | fulltext_unavailable_from_checked_sources |  |
| W0038 | Hemipherical wineglass shells fabricated by a Chemical Foaming Process | 10.1109/icept.2015.7236736 | fulltext_unavailable_from_checked_sources |  |
| W0039 | HRG and marine applications | 10.1134/s2075108714020047 | fulltext_unavailable_from_checked_sources |  |
| W0040 | HRG by Sagem from laboratory to mass production | 10.1109/isiss.2016.7435530 | fulltext_unavailable_from_checked_sources |  |
| W0041 | Kalihman, D.M |  | needs_search_no_verified_identifier |  |
| W0042 | Micro Hemispherical Resonator Gyroscope With Teeth-Like Tines | 10.1109/jsen.2021.3065818 | fulltext_unavailable_from_checked_sources |  |
| W0043 | Microsacle PolySilicon Hemispherical Shell Resonating Gyroscopes with Integrated Three-dimensional Curved Electrodes | 10.1088/1742-6596/986/1/012022 | fulltext_unavailable_from_checked_sources |  |
| W0044 | Milli-HRG inertial navigation system | 10.1134/s2075108712040086 | fulltext_unavailable_from_checked_sources |  |
| W0045 | Milli-HRG inertial sensor assembly – a reality | 10.1109/isiss.2015.7102386 | fulltext_unavailable_from_checked_sources |  |
| W0046 | Motion equations of hemispherical resonator and analysis of frequency split caused by slight mass non-uniformity | 10.1016/j.cja.2020.04.011 | fulltext_unavailable_from_checked_sources |  |
| W0047 | NonlinearEffectsinHigh-QDiskResonatorGyroscopes |  | needs_search_no_verified_identifier |  |
| W0048 | Painter and A |  | needs_search_no_verified_identifier |  |
| W0049 | Precision mode tuning towards a low angle drift MEMS rate integrating gyroscope | 10.1016/j.mechatronics.2017.04.007 | fulltext_unavailable_from_checked_sources |  |
| W0050 | A new control mode greatly improving performance of axisymmetrical vibrating gyroscopes | 10.1134/s2075108711040134 | fulltext_unavailable_from_checked_sources |  |
| W0051 | Researched on the bias stability of the HRG affected by the temperature and the standing wave azimuth | 10.1177/0020294020952465 | fulltext_unavailable_from_checked_sources |  |
| W0052 | Retrospective Correction of Angular Gain by Virtual Carouseling in MEMS Gyroscopes | 10.1109/isiss.2019.8739340 | fulltext_unavailable_from_checked_sources |  |
| W0053 | In-Run Automatic Mode-Matching of Whole-Angle Micro-Hemispherical Resonator Gyroscope Based on Standing Wave Self-Precession | 10.1109/jsen.2022.3181302 | fulltext_unavailable_from_checked_sources |  |
| W0054 | Sagem Coriolis Vibrating Gyros: A vision realized | 10.1109/inertialsensors.2014.7049409 | fulltext_unavailable_from_checked_sources |  |
| W0055 | Shell-in-Shell (SiS): 3D Shell Resonator with 3D Conformal Shell Electrodes | 10.1109/inertial48129.2020.9090010 | fulltext_unavailable_from_checked_sources |  |
| W0056 | An automatically mode-matched MEMS gyroscope with 50 Hz bandwidth | 10.1109/memsys.2012.6170231 | needs_bibliographic_version_review |  |
| W0057 | Disk resonator gyroscope with whole-angle mode operation | 10.1109/isiss.2015.7102360 | fulltext_unavailable_from_checked_sources |  |
| W0058 | A new electronic feedback compensation method for rate integrating gyroscopes | 10.1109/isiss.2016.7435532 | fulltext_unavailable_from_checked_sources |  |
| W0059 | The control algorithm of whole angle mode for HRG based on the vector composition | 10.1186/s13638-021-01913-7 | existing_local | D:/学习资料/资料/全角陀螺/新增资料_20260825/02_控制与信号处理/2021_Whole_Angle_Control_Vector_Composition.pdf |
| W0060 | The operation and mechanization of the hemispherical resonator gyroscope | 10.1109/plans.2018.8373357 | fulltext_unavailable_from_checked_sources |  |
| W0061 | Theoretical Consideration of Mismatch Compensation for MEMS Resonator Having Unaligned Principle Axes | 10.1109/inertial51137.2021.9430491 | fulltext_unavailable_from_checked_sources |  |
| W0062 | mHRG: Miniature CVG with beyond navigation grade performance and real time self-calibration | 10.1109/isiss.2016.7435537 | fulltext_unavailable_from_checked_sources |  |
| W0063 | On Correlation of Anisoelasticity, Angular Gain, and Temperature in Whole-Angle CVGs | 10.1109/jsen.2021.3139920 | fulltext_unavailable_from_checked_sources |  |
| W0064 | Wafer-Level Fabrication Process for Micro Hemispherical Resonators |  | needs_search_no_verified_identifier |  |
| W0065 | 全角半球谐振陀螺建模、测试及误差补偿技术 |  | needs_search_no_verified_identifier |  |
| W0066 | 全角模式半球谐振陀螺控制电路误差参数辨识研究 |  | needs_search_no_verified_identifier |  |
| W0067 | 分时复用半球谐振陀螺数字控制平台设计 |  | needs_search_no_verified_identifier |  |
| W0068 | 力反馈半球谐振陀螺建模、误差分析与抑制方法研究 |  | needs_search_no_verified_identifier |  |
| W0069 | 半球谐振子频率裂解分析与陀螺仪误差抑制方法研究 |  | needs_search_no_verified_identifier |  |
| W0070 | 半球谐振陀螺 (HRG) 研究现状及发展趋势 |  | needs_search_no_verified_identifier |  |
| W0071 | 半球谐振陀螺惯性敏感器及其空间应用 |  | nonpaper_reference_not_downloaded |  |
| W0072 | 半球谐振陀螺技术 |  | needs_search_no_verified_identifier |  |
| W0073 | 半球谐振陀螺电路增益非对称分析及抑制方法 |  | needs_search_no_verified_identifier |  |
| W0074 | 吕志清．半球谐振陀螺(HRG)信号处理技术 |  | needs_search_no_verified_identifier |  |
| W0075 | 基于 RLS 算法的全角模式半球谐振陀螺自补偿 控制 |  | needs_search_no_verified_identifier |  |
| W0076 | 基于主动驱动旋转的全角模式半球谐振陀螺驻波漂移补偿方法 |  | needs_search_no_verified_identifier |  |
| W0077 | 基于数字技术的硅微陀螺仪性能稳定性研究 |  | needs_search_no_verified_identifier |  |
| W0078 | 微半球谐振陀螺技术研究进展 |  | needs_search_no_verified_identifier |  |
| W0079 | 抑制耦合干扰的半球谐振陀螺信号分频调制检 测方法 |  | needs_search_no_verified_identifier |  |
| W0080 | 科氏振动陀螺全角模式阻 尼误差与补偿 |  | needs_search_no_verified_identifier |  |
| W0081 | 赵万良，杨浩，王伟，等．半球谐振陀螺全角模式控 制技术研究 |  | needs_search_no_verified_identifier |  |
| W0082 | Monolithic Strong Coupling of Topological Surface Acoustic Wave Resonators on Lithium Niobate | 10.1002/adma.202312861 | fulltext_unavailable_from_checked_sources |  |
| W0083 | Diamagnetic Composites for High‐Q Levitating Resonators | 10.1002/advs.202203619 | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R0089_Diamagnetic Composites for High_Q Levitating Resonators.pdf |
| W0084 | Wafer-level manufacturing of MEMS H2 sensing chips based on Pd nanoparticles modi ﬁed SnO2 ﬁlm patterns | 10.1002/advs.202302614(2023 | fulltext_unavailable_from_checked_sources |  |
| W0085 | Automated frequency and quality‐factor matching method for frequency modulated / rate integrating gyroscope | 10.1002/eej.23248 | fulltext_unavailable_from_checked_sources |  |
| W0086 | 3D Printing of Metals with sub‐10 µm Resolution | 10.1002/smll.202406518 | fulltext_unavailable_from_checked_sources |  |
| W0087 | Coupled effect of curved surface and interface on stress state of wrinkled thin film coating at the nanoscale | 10.1002/zamm.202000202 | fulltext_unavailable_from_checked_sources |  |
| W0088 | Atomic Layer Deposition Niobium Nitride Films for High-Q Resonators | 10.1007/s10909-020-02336-2 | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R0094_Atomic Layer Deposition Niobium Nitride Films for High-Q Resonators.pdf |
| W0089 | Highly precise Ti/Pt/Cr/Au thin‐film temperature sensor embedded in a microfluidic device | 10.1007/s12598-019-01301-7 | needs_bibliographic_version_review |  |
| W0090 | Vibration-induced nanoscale friction modulation on piezoelectric materials | 10.1007/s40544-021-0552-y | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R0096_Vibration-induced nanoscale friction modulation on piezoelectric materials.pdf |
| W0091 | Anelastic behavior of copper thin films on silicon substrates: Damping associated with dislocations | 10.1016/j.actamat.2005.10.003 | fulltext_unavailable_from_checked_sources |  |
| W0092 | Strain transfer through film-substrate interface and surface curvature evolution during a tensile test | 10.1016/j.apsusc.2017.09.164 | fulltext_unavailable_from_checked_sources |  |
| W0093 | Research on magnetron sputtering thin films as electrode materials for supercapacitors | 10.1016/j.cej.2025.161242 | fulltext_unavailable_from_checked_sources |  |
| W0094 | Effect of magnetron sputtering parameters on adhesion properties of tungsten-rhenium thin film thermocouples | 10.1016/j.ceramint.2018.08.334 | fulltext_unavailable_from_checked_sources |  |
| W0095 | Influence of substrate temperature and bias voltage on the properties of magnetron sputtered TiBx films | 10.1016/j.ceramint.2025.05.422 | fulltext_unavailable_from_checked_sources |  |
| W0096 | Standing wave drift of hemispherical resonator with quality factor non-uniformity under a ring electrode excitation | 10.1016/j.cja.2021.05.012 | fulltext_unavailable_from_checked_sources |  |
| W0097 | Continuum mechanics based beam elements for linear and nonlinear analyses of multi-layered composite beams with interlayer slips | 10.1016/j.compstruct.2019.111740 | fulltext_unavailable_from_checked_sources |  |
| W0098 | In situ TEM studies of relaxation dynamics and crystal nucleation in thin film nanoglasses | 10.1080/21663831.2023.2278597 | fulltext_unavailable_from_checked_sources |  |
| W0099 | Frequency splitting of hemispherical resonators trimmed with focused ion beams | 10.1016/j.ijmecsci.2023.108682 | fulltext_unavailable_from_checked_sources |  |
| W0100 | Investigations on the effect of substrate temperature on the propertie s of reactively sputtered zirconium carbide thin ﬁlms | 10.1016/j.jallcom.2016.10.225(2017 | fulltext_unavailable_from_checked_sources |  |
| W0101 | Initial vacuum effects on the properties of sputter deposited Ga-doped ZnO thin films | 10.1016/j.jallcom.2017.03.189 | fulltext_unavailable_from_checked_sources |  |
| W0102 | Kinetics of phase transformations in the peridynamic formulation of continuum mechanics | 10.1016/j.jmps.2006.04.001 | fulltext_unavailable_from_checked_sources |  |
| W0103 | Determination of the elastic moduli and residual stresses of freestanding Au-TiW bilayer thin films by nanoindentation | 10.1016/j.matdes.2016.06.003 | fulltext_unavailable_from_checked_sources |  |
| W0104 | High-precision synchronous test method of vibration performance parameters for fused quartz hemispherical resonator | 10.1016/j.measurement.2021.109924 | fulltext_unavailable_from_checked_sources |  |
| W0105 | Overview and analysis of MEMS Coriolis vibratory ring gyroscope | 10.1016/j.measurement.2021.109704 | fulltext_unavailable_from_checked_sources |  |
| W0106 | Self-calibration of hemispherical resonator gyroscopes under drastic changes of ambient temperature based on mode reversal | 10.1016/j.sna.2023.114986 | fulltext_unavailable_from_checked_sources |  |
| W0107 | A rate hemispherical resonator gyroscope with bias stability of 0.0056°/h with compensation of phase delay | 10.1016/j.sna.2024.115494 | fulltext_unavailable_from_checked_sources |  |
| W0108 | Research on the damage mechanism of low current 50 keV electron beam on the micro structure, composition and vacuum tribological performance of MoS2-Ti films deposited by unbalanced magnetron sputtering | 10.1016/j.surfcoat.2020.126708 | fulltext_unavailable_from_checked_sources |  |
| W0109 | Effect of magnetic field on the thickness uniformity of thin film deposited on inner surface | 10.1016/j.surfcoat.2021.127974 | fulltext_unavailable_from_checked_sources |  |
| W0110 | In-situ crystalline TiNi thin films deposited by HiPIMS at a low substrate temperature | 10.1016/j.surfcoat.2022.129196 | fulltext_unavailable_from_checked_sources |  |
| W0111 | FIB-DIC ring-core measurement of the residual stress on HiPIMS W/Cu and Cr/Cu multilayer thin films | 10.1016/j.surfcoat.2024.130768 | fulltext_unavailable_from_checked_sources |  |
| W0112 | Fabrication of highly homogeneous metal films for hemispherical resonators by a 3D mask based on a sputter-coating process | 10.1016/j.tsf.2025.140684 | fulltext_unavailable_from_checked_sources |  |
| W0113 | Effect of Metallization on Quality Factor and Noise Characteristics in Fused Silica Dual-Shell Gyroscopes | 10.1109/jmems.2022.3199231 | fulltext_unavailable_from_checked_sources |  |
| W0114 | 3D Printing of Glass Micro-Optics with Subwavelength Features on Optical Fiber Tips | 10.1021/acsnano.3c11030 | fulltext_unavailable_from_checked_sources |  |
| W0115 | Micro 3D printing of a functional MEMS accelerometer | 10.1038/s41378-022-00440-9 | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R0122_Micro 3D printing of a functional MEMS accelerometer.pdf |
| W0116 | 3D printing of micro-nano devices and their applications | 10.1038/s41378-024-00812-3 | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R0697_3D printing of micro-nano devices and their applications.pdf |
| W0117 | Real-time correction of gain nonlinearity in electrostatic actuation for whole-angle micro-shell resonator gyroscope | 10.1038/s41378-024-00818-x | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R0496_Real-time correction of gain nonlinearity in electrostatic actuation for whole-angle micro-shell resonator gyroscop.pdf |
| W0118 | 0.32 mHz frequency mismatch of micro-shell resonator gyroscope without tuning electrodes achieved by ultra-precision mechanical trimming | 10.1038/s41378-025-00872-z | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R0126_Yu_ S. et al. 0.32 mHz frequency mismatch of micro-shell resonator gyroscope without tuning electrodes achieved by.pdf |
| W0119 | Micro-3D sculptured metastructures with deep trenches for sub-10 μm resolution | 10.1038/s41378-025-00888-5 | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R0127_Micro-3D sculptured metastructures with deep trenches for sub-10_μm resolution.pdf |
| W0120 | Identification and trimming of the unbalanced mass in micro hemispherical resonators based on an elastic electrode substrate | 10.1038/s41378-025-00932-4 | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R0128_Identification and trimming of the unbalanced mass in micro hemispherical resonators based on an elastic electrode.pdf |
| W0121 | Ultrahigh-quality-factor micro- and nanomechanical resonators using dissipation dilution | 10.1038/s41565-023-01597-8 | fulltext_unavailable_from_checked_sources |  |
| W0122 | Effective quality factor tuning mechanisms in micromechanical resonators | 10.1063/1.5027850 | fulltext_unavailable_from_checked_sources |  |
| W0123 | Application of conductive graphene films for high-performance hemispherical resonator gyroscopes | 10.1063/5.0230846 | fulltext_unavailable_from_checked_sources |  |
| W0124 | Mechanical spectroscopy of nanocrystalline aluminum films: effects of frequency and grain size on internal friction | 10.1088/0957-4484/23/15/155701 | fulltext_unavailable_from_checked_sources |  |
| W0125 | Effect of circuit phase delay on bias stability of MEMS gyroscope under force rebalance detection and self-compensation method | 10.1088/1361-6439/ab27e8 | fulltext_unavailable_from_checked_sources |  |
| W0126 | Identification and suppression of driving force misalignment angle for a MEMS gyroscope using parametric excitation | 10.1088/1361-6439/acbfc6 | fulltext_unavailable_from_checked_sources |  |
| W0127 | 4.11-million Q-factor whole-angle MEMS hemispherical resonator gyroscope with 0.013°/h bias instability | 10.1088/1361-6501/ad6fc3 | fulltext_unavailable_from_checked_sources |  |
| W0128 | Mechanism of frequency splitting in micro hemispherical resonator with T-shape masses: study on the harmonic error order characteristics | 10.1088/1361-6501/adeba6 | fulltext_unavailable_from_checked_sources |  |
| W0129 | Engineering the Dissipation of Crystalline Micromechanical Resonators | 10.1103/physrevapplied.13.044007 | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R0137_Engineering the Dissipation of Crystalline Micromechanical Resonators.pdf |
| W0130 | Stick-Slip Friction and Energy Dissipation in Boundary Lubrication | 10.1103/physrevlett.107.147801 | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R0138_Stick-Slip Friction and Energy Dissipation in Boundary Lubrication.pdf |
| W0131 | A Robust 24mW 60GHz Receiver in 90nm Standard CMOS | 10.1109/i | fulltext_unavailable_from_checked_sources |  |
| W0132 | Calibration and Compensation of The Misalignment Angle Errors For The Disk Resonator Gyroscopes | 10.1109/inertial48129.2020.9090094 | fulltext_unavailable_from_checked_sources |  |
| W0133 | Ultra-fast Characterization of Detection Electrode Errors under Whole-angle Mode in 10 Seconds | 10.1109/inertial53425.2022.9787737 | fulltext_unavailable_from_checked_sources |  |
| W0134 | Effect of metal annealing on the Q-factor of metal- coated fused silica micro shell resonators | 10.1109/isiss.2015.7102361 | fulltext_unavailable_from_checked_sources |  |
| W0135 | A Rate Integrating Hemispherical Resonant Gyro Angular Rate Output Method Based on Frequency Demodulation | 10.1109/isstc59603.2023.10281165 | fulltext_unavailable_from_checked_sources |  |
| W0136 | A Microcantilever Platform for Measuring Internal Friction in Thin Films Using Thermoelastic Damping for Calibration | 10.1109/jmems.2011.2140357 | fulltext_unavailable_from_checked_sources |  |
| W0137 | Thermoelastic Dissipation in Micromachined Birdbath Shell Resonators | 10.1109/jmems.2017.2715319 | fulltext_unavailable_from_checked_sources |  |
| W0138 | Q-Factor Enhancement of Micro Hemispherical Resonators via Optimization of Film Distribution | 10.1109/jmems.2025.3589654 | fulltext_unavailable_from_checked_sources |  |
| W0139 | Single-Channel Control for Hemispherical Resonator Gyro Based on Time Division Multiplexing and Demultiplexing | 10.1109/jsen.2021.3103115 | fulltext_unavailable_from_checked_sources |  |
| W0140 | 0.79 ppm scale-factor nonlinearity whole-angle microshell gyroscope realized by real-time calibration of capacitive displacement detection | 10.1038/s41378-021-00306-6 | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R0490_0.79_ppm scale-factor nonlinearity whole-angle microshell gyroscope realized by real-time calibration of capacitive.pdf |
| W0141 | Investigation of Angle Drift Induced by Actuation Electrode Errors for Whole-Angle Micro-Shell Resonator Gyroscope | 10.1109/jsen.2022.3140799 | fulltext_unavailable_from_checked_sources |  |
| W0142 | Identification and Correction of Phase Error for Whole-Angle Micro-Shell Resonator Gyroscope | 10.1109/jsen.2022.3204631 | fulltext_unavailable_from_checked_sources |  |
| W0143 | Rate Integrating Hemispherical Resonator Gyroscope Detection Error Analysis and Compensation | 10.1109/jsen.2023.3246044 | fulltext_unavailable_from_checked_sources |  |
| W0144 | High Precision Mass Balancing Method for the Fourth Harmonic of Mass Defect of Fused Quartz Hemispherical Resonator Based on Ion Beam Etching Process | 10.1109/tie.2022.3212381 | fulltext_unavailable_from_checked_sources |  |
| W0145 | Reconstruction of 3-D CAD Model of Workpiece With Internal Defect Based on Industry CT Image | 10.1109/tim.2022.3219478 | fulltext_unavailable_from_checked_sources |  |
| W0146 | High Precision Assembly and Welding Method for Flat-Electrode Hemispherical Resonator Gyro | 10.1109/tim.2023.3295462 | fulltext_unavailable_from_checked_sources |  |
| W0147 | In-flight refocusing and MTF assessment of SPOT5 HRG and HRS cameras | 10.1117/12.462639 | fulltext_unavailable_from_checked_sources |  |
| W0148 | 基于分次吹制工艺的微半球陀螺制作 | 10.11977/j.issn.1004-2474.2021.01.030 | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R0164_基于分次吹制工艺的微半球陀螺制作.pdf |
| W0149 | 微型半球陀螺仪的误差源研究 | 10.13873/j.1000 | fulltext_unavailable_from_checked_sources |  |
| W0150 | 2018 年国外惯性技术发展与回顾 | 10.16338/j.issn.1009 | fulltext_unavailable_from_checked_sources |  |
| W0151 | 半球谐振陀螺发展的技术特征 | 10.19306/j.cnki.2095-8110.2019.04.016 | fulltext_unavailable_from_checked_sources |  |
| W0152 | 半球谐振陀螺研究现状、 关键技术和发展趋势分析 | 10.19519/j.cnki.1672 | fulltext_unavailable_from_checked_sources |  |
| W0153 | SpaceNaute®: HRG technological breakthrough for advanced space launcher inertial reference system | 10.23919/icins.2018.8405891 | fulltext_unavailable_from_checked_sources |  |
| W0154 | Current State of Wave Solid-State Gyroscopes. Development Prospects in Applied Gyroscopy | 10.23919/icins51816.2023.10168310 | fulltext_unavailable_from_checked_sources |  |
| W0155 | In-flight Characterization of Cassini Inertial Reference Units | 10.2514/6.2007-6340 | fulltext_unavailable_from_checked_sources |  |
| W0156 | 半球谐振陀螺全角模式驻波漂移特性研究 | 10.26914/c.cn | fulltext_unavailable_from_checked_sources |  |
| W0157 | 半球谐振子质量不平衡对 Q 值的影响分析 | 10.26914/c.cnkihy.2020.047666 | fulltext_unavailable_from_checked_sources |  |
| W0158 | 半球谐振陀螺全角模式驻波漂移特性研究 | 10.26914/c.cnkihy.2021.050325 | fulltext_unavailable_from_checked_sources |  |
| W0159 | 力平衡模式下半球谐振陀螺的正交控制技术研究 | 10.27060/d.cnki.ghbcu.2020.000595 | fulltext_unavailable_from_checked_sources |  |
| W0160 | 速率积分半球谐振陀螺建模与控制方法研究 | 10.27061/d.cnki.ghgdu.2020.004059 | fulltext_unavailable_from_checked_sources |  |
| W0161 | 全角模式半球谐振陀螺控制电路设计与实现 | 10.27061/d.cnki.ghgdu.2021.004017 | fulltext_unavailable_from_checked_sources |  |
| W0162 | 半球谐振子金属化镀膜工艺与关键特性研究 | 10.27157/d.cnki.ghzku.2021.002317 | fulltext_unavailable_from_checked_sources |  |
| W0163 | 大动态半球谐振陀螺控制方式及其误差补偿方法研究 | 10.27241/d.cnki.gnjgu.2021.000072 | fulltext_unavailable_from_checked_sources |  |
| W0164 | Electronics 9, 499. https ://doi.org/10.3390/elect ronic s9030 499 (2020) | 10.3390/elect | fulltext_unavailable_from_checked_sources |  |
| W0165 | MEMS Gyroscope Temperature Compensation Based on Drive Mode Vibration Characteristic Control | 10.3390/mi10040248 | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R0397_MEMS Gyroscope Temperature Compensation Based on Drive Mode Vibration Characteristic Control.pdf |
| W0166 | Automatic Mode-Matching Method for MEMS Disk Resonator Gyroscopes Based on Virtual Coriolis Force | 10.3390/mi11020210 | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R0182_Automatic Mode-Matching Method for MEMS Disk Resonator Gyroscopes Based on Virtual Coriolis Force.pdf |
| W0167 | The Recent Progress of MEMS/NEMS Resonators | 10.3390/mi12060724 | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R0183_The Recent Progress of MEMS_NEMS Reso- nators.pdf |
| W0168 | A Review of Symmetric Silicon MEMS Gyroscope Mode-Matching Technologies | 10.3390/mi13081255 | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R0184_Microm- achines 2022_ 13_ 1255. https___doi.org_10.3390_mi13081255.pdf |
| W0169 | A Digital Closed-Loop Sense MEMS Disk Resonator Gyroscope Circuit Design Based on Integrated Analog Front-end | 10.3390/s20030687 | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R0186_A Digital Closed-Loop Sense MEMS Disk Resonator Gyroscope Circuit Design Based on Integrated Analog Front-end.pdf |
| W0170 | 2008年"校长论坛"文集: 华校发展的回顾与前瞻 |  | nonpaper_reference_not_downloaded |  |
| W0171 | 2020 年国外惯性技术发展与回顾 |  | needs_search_no_verified_identifier |  |
| W0172 | 2022年国外惯性技术发 展与回顾 |  | needs_search_no_verified_identifier |  |
| W0173 | Hemispherical Resonator Gyros (An Overview of Publications) | 10.1134/s2075108723010054 | fulltext_unavailable_from_checked_sources |  |
| W0174 | A.A. Severov, A.A. L’vov “Algorithm for Estimating the Parameters of Mathematical Models of Linear and Nonlinear Systems ”. Bulletin of the Saratov State Technical University , 2009. Vol. 4. No.2 (43). pp. 77‒81.(in Russian) |  | needs_search_no_verified_identifier |  |
| W0175 | A Novel Capacitive Detection Scheme With Inherent Self-Calibration | 10.1109/jmems.2007.906077 | fulltext_unavailable_from_checked_sources |  |
| W0176 | A.A. Trusov, A.R. Schoﬁeld, A.M. Shkel, Micromachined tuning fork gyroscopes with ultra-high sensitivity and shock rejection, U.S. patent application 20 100 313 657 (2010b) |  | needs_search_no_verified_identifier |  |
| W0177 | A. A. Trusov, A. R. Schoﬁeld, and A. M. Shkel, “Micromachined tuning fork gyroscopes with ultra-high sensitivity and shock rejection,” 2012, US Patent 8,322,213 |  | needs_search_no_verified_identifier |  |
| W0178 | Force rebalance, whole angle, and self-calibration mechanization of silicon MEMS quad mass gyro | 10.1109/isiss.2014.6782537 | fulltext_unavailable_from_checked_sources |  |
| W0179 | Flat is not dead: Current and future performance of Si-MEMS Quad Mass Gyro (QMG) system | 10.1109/plans.2014.6851383 | fulltext_unavailable_from_checked_sources |  |
| W0180 | A Standalone Programmable Signal Processing Unit for Versatile Characterization of MEMS Gyroscopes | 10.1109/icsens.2007.4388382 | fulltext_unavailable_from_checked_sources |  |
| W0181 | Low-Dissipation Silicon Tuning Fork Gyroscopes for Rate and Whole Angle Measurements | 10.1109/jsen.2011.2160338 | fulltext_unavailable_from_checked_sources |  |
| W0182 | Acceleration drift mechanism analysis and compensation for hemispherical resonant gyro based on dynamics | 10.1007/s00542-019-04327-0 | fulltext_unavailable_from_checked_sources |  |
| W0183 | Acceleration insensitive hemispherical shell resonators using pop-up rings | 10.1109/memsys.2018.8346716 | fulltext_unavailable_from_checked_sources |  |
| W0184 | milli-HRG inertial sensor assembly — A reality | 10.1109/plans.2018.8373359 | fulltext_unavailable_from_checked_sources |  |
| W0185 | A high symmetry polysilicon micro hemispherical resonating gyroscope with spherical electrodes | 10.1109/icsens.2017.8233984 | fulltext_unavailable_from_checked_sources |  |
| W0186 | A high-performance self-clocked digital-output quartz gyroscope | 10.1109/icsens.2015.7370471 | fulltext_unavailable_from_checked_sources |  |
| W0187 | Vibratory rotation sensor | 10.1121/1.402328 | needs_bibliographic_version_review |  |
| W0188 | A. Matthews, G. T. Varty, P. C. N guyen, and D. D. Lynch, “Extraction of double-oscillation-frequency sinusoi ds in vibratory rotation sensors,” U.S. Patent 6 158 282. Dec. 12, 2000 |  | needs_search_no_verified_identifier |  |
| W0189 | A MEMS Doubly Decoupled Gyroscope With Wide Driving Frequency Range |  | needs_search_no_verified_identifier |  |
| W0190 | Amplitude control contour in a hemispherical resonator gyro with automa tic compensation for difference in Q-factors |  | needs_search_no_verified_identifier |  |
| W0191 | A.M. Shkel, R.T. Howe, Micro-machined angle measuring gyroscope, U.S. patent 6 481 285 (2002) |  | needs_search_no_verified_identifier |  |
| W0192 | A Novel High Transduction Efficiency Micro Shell Resonator Gyroscope With 16 T-Shape Masses Using Out-of-Plane Electrodes | 10.1109/jsen.2019.2903199 | fulltext_unavailable_from_checked_sources |  |
| W0193 | Apostolyuk V．Theory and designofmicromechanical vibratory gyroscopes |  | nonpaper_reference_not_downloaded |  |
| W0194 | Versatile vacuum packaging for experimental study of resonant MEMS | 10.1109/memsys.2010.5442453 | fulltext_unavailable_from_checked_sources |  |
| W0195 | A Sub-0.2$^{\circ}/$hr Bias Drift Micromechanical Silicon Gyroscope With Automatic CMOS Mode-Matching | 10.1109/jssc.2009.2016996 | fulltext_unavailable_from_checked_sources |  |
| W0196 | Dynamics and control of micromachined gyroscopes | 10.1109/acc.1999.786303 | fulltext_unavailable_from_checked_sources |  |
| W0197 | High quality factor MEMS gyroscope with whole angle mode of operation | 10.1109/isiss.2018.8358148 | existing_local | D:/学习资料/资料/全角陀螺/High_quality_factor_MEMS_gyroscope_with_whole_angle_mode_of_operation.pdf |
| W0198 | Ultra-high Q silicon gyroscopes with interchangeable rate and whole angle modes of operation | 10.1109/icsens.2010.5690867 | fulltext_unavailable_from_checked_sources |  |
| W0199 | Automated Frequency and Quality-Factor Matching Method for Frequency Modulated / Rate Integrating Gyroscope | 10.1541/ieejsmas.139.219 | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R0219_Automated Frequency and Quality-Factor Matching Method for Frequency Modulated _ Rate Integrating Gyroscope.pdf |
| W0200 | Automatic Rate and Rate-Integrating Mode-Switchable Axisymmetric Gyroscope | 10.3390/s22124334 | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R0220_Automatic Rate and Rate-Integrating Mode-Switchable Axisymmetric Gyroscope.pdf |
| W0201 | A.马特维耶夫 . 固体波动陀螺 : 译文集 |  | nonpaper_reference_not_downloaded |  |
| W0202 | A.马特维耶夫,马特维耶夫,利帕特尼科夫,等. 固体波动陀螺 |  | nonpaper_reference_not_downloaded |  |
| W0203 | Imperfection Parameter Observer and Drift Compensation Controller Design of Hemispherical Resonator Gyros | 10.5139/ijass.2013.14.4.379 | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R0224_Imperfection Parameter Observer and Drift Compensation Controller Design of Hemispherical Resonator Gyros.pdf |
| W0204 | Bias Modulation of Force-to-Rebalanced Micro Hemispherical Resonator Gyroscope Based on Mode-Rotation | 10.1109/jsen.2022.3188287 | fulltext_unavailable_from_checked_sources |  |
| W0205 | Temperature Dependence of Quality Factor in MEMS Resonators | 10.1109/jmems.2008.924253 | fulltext_unavailable_from_checked_sources |  |
| W0206 | Book-Review - an Introduction to the Coriolis Force |  | needs_search_no_verified_identifier |  |
| W0207 | In-Flight Performance of the Cassini Hemispherical Quartz Resonator Gyro Inertial Reference Units | 10.2514/6.2013-4630 | fulltext_unavailable_from_checked_sources |  |
| W0208 | Mode ordering in tuning fork structures with negative structural coupling for mitigation of common-mode g-sensitivity | 10.1109/icsens.2015.7370333 | fulltext_unavailable_from_checked_sources |  |
| W0209 | The on-chip temperature compensation and temperature control research for the silicon micro-gyroscope | 10.1007/s00542-014-2271-z | fulltext_unavailable_from_checked_sources |  |
| W0210 | A universal electronics approach for Rate Integrating Gyroscopes | 10.1109/isiss.2017.7935687 | fulltext_unavailable_from_checked_sources |  |
| W0211 | Characterization and Compensation of Detection Electrode Errors for Whole-Angle Micro-Shell Resonator Gyroscope | 10.1109/jmems.2021.3123082 | fulltext_unavailable_from_checked_sources |  |
| W0212 | Characterization, Control and Compensation of MEMS Rate and Rate-Integrating Gyroscopes |  | needs_search_no_verified_identifier |  |
| W0213 | Online Identification and Compensation of Drive and Phase Errors for Whole-Angle Hemispherical Resonator Gyroscope Based on Sinusoidal Self-Excitation | 10.1109/jsen.2024.3504581 | fulltext_unavailable_from_checked_sources |  |
| W0214 | Design and Implementation of an Optimized Double Closed-Loop Control System for MEMS Vibratory Gyroscope | 10.1109/jsen.2013.2271586 | fulltext_unavailable_from_checked_sources |  |
| W0215 | 3-Dimensional Blow Torch-Molding of Fused Silica Microstructures | 10.1109/jmems.2013.2279165 | fulltext_unavailable_from_checked_sources |  |
| W0216 | Chou and C.-O |  | needs_search_no_verified_identifier |  |
| W0217 | An FPGA-Based Interface System for High-Frequency Bulk-Acoustic-Wave Microgyroscopes With In-Run Automatic Mode-Matching | 10.1109/tim.2019.2914295 | fulltext_unavailable_from_checked_sources |  |
| W0218 | Continuously self-calibrating CVG system using hemispherical resonator gyroscopes | 10.1109/isiss.2015.7102362 | fulltext_unavailable_from_checked_sources |  |
| W0219 | Control and damping imperfection compensation for a rate integrating MEMS gyroscope | 10.1109/inertialsensors.2015.7314258 | fulltext_unavailable_from_checked_sources |  |
| W0220 | Control and self -calibration of microscale rate integrating gyrosco pes (MRIGs) |  | nonpaper_reference_not_downloaded |  |
| W0221 | Control System Based on Double-Frequency Drive and Single-Channel Detection for Rate Integrating Vibratory Gyroscope | 10.1109/jsen.2024.3378916 | fulltext_unavailable_from_checked_sources |  |
| W0222 | Convergence Properties of the Nelder--Mead Simplex Method in Low Dimensions | 10.1137/s1052623496303470 | fulltext_unavailable_from_checked_sources |  |
| W0223 | Coriolis Vibrating Gyros for Aeronautical Applications | 10.4271/2011-01-2731 | fulltext_unavailable_from_checked_sources |  |
| W0224 | Corpus V N, Corpus G T, Corpus C T. METHOD AND APPARATUS FOR GENERATI NG ENERGY2015 |  | needs_search_no_verified_identifier |  |
| W0225 | Countering the Effects of Nonlinearity in Rate-Integrating Gyroscopes | 10.1109/jsen.2016.2533480 | fulltext_unavailable_from_checked_sources |  |
| W0226 | Active structural error suppression in MEMS vibratory rate integrating gyroscopes | 10.1109/jsen.2003.817165 | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R0252_Active structural error suppression in MEMS vibratory rate integrating gyroscopes.pdf |
| W0227 | CVGs utilizing non-axisymmetric structures operating in whole-angle mode | 10.1109/isiss.2014.6782508 | fulltext_unavailable_from_checked_sources |  |
| W0228 | D.D. Lynch, R.R. Savava, J.J. Campanile, Hemispherical Resonator Gyro Control. USA: 7,318,347 B2, Jan. 15, 2008 |  | needs_search_no_verified_identifier |  |
| W0229 | D. D. Lynch, R. R. Savaya, and J. J. Campanile, “Hemispherical resonant gyro control,” U.S. Patent 2006 ˙0 248 953. Nov. 9, 2006 |  | needs_search_no_verified_identifier |  |
| W0230 | Area optimized CORDIC-based numerically controlled oscillator for electrical bio-impedance spectroscopy | 10.1109/fcs.2016.7546728 | fulltext_unavailable_from_checked_sources |  |
| W0231 | Demonstration of a Three-dimensional Negative Index Medium Operated at Multiple-angle Incidences by Monolithic Metallic Hemispherical Shells | 10.1038/srep45549 | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R0262_Demonstration of a Three-dimensional Negative Index Medium Operated at Multiple-angle Incidences by Monolithic Meta.pdf |
| W0232 | Separation, Identification, and Compensation of Damping, Detection, and Actuation Errors for Rate-Integrating Hemispherical Resonator Gyroscopes | 10.1109/tim.2025.3555670 | fulltext_unavailable_from_checked_sources |  |
| W0233 | HRG strapdown navigator | 10.1109/plans.1990.66164 | fulltext_unavailable_from_checked_sources |  |
| W0234 | Differential mode of operation for Coriolis vibratory gyro with ring-like resonator | 10.1109/elnano.2014.6873426 | fulltext_unavailable_from_checked_sources |  |
| W0235 | Digital Control System for the MEMS Tuning Fork Gyroscope Based on Synchronous Integral Demodulator | 10.1109/jsen.2015.2451080 | fulltext_unavailable_from_checked_sources |  |
| W0236 | D. Lynch, A. Matthews, and G. T. Varty, “Innovative mechanization to optimize inertial sensors for high or low rate operations,” in Proc. Symp. Gyro Technol., vol. 6. Stuttgart, Germany, Sep. 1997, pp. 16–17 |  | needs_search_no_verified_identifier |  |
| W0237 | Minimal realization of dynamically balanced lumped mass WA gyroscope: dual foucault pendulum | 10.1109/isiss.2015.7102394 | fulltext_unavailable_from_checked_sources |  |
| W0238 | D. Senkal, E. Ng, V . Hong, Y . Y ang, C. Ahn, T. Kenny, and A. M. Shkel, “Parametric drive of a toroidal MEMS rate integrating gyroscope demonstrating <20 PPM scale factor stability,” in IEEE Int. Micro Electro Mechanical Systems (MEMS), Estoril, Portugal , Jan 2015 |  | needs_search_no_verified_identifier |  |
| W0239 | D. Senkal, S. A. Zotov, and A. M. Shkel. Fully balanced micro-machined inertial sensor, April 2 2019. US Patent 10,247,554 |  | needs_search_no_verified_identifier |  |
| W0240 | Silicon microgyroscope temperature prediction and control system based on BP neural network and Fuzzy-PID control method | 10.1088/0957-0233/26/2/025101 | fulltext_unavailable_from_checked_sources |  |
| W0241 | Microgyroscope Temperature Effects and Compensation-Control Methods | 10.3390/s91008349 | fulltext_unavailable_from_checked_sources |  |
| W0242 | Dynamic error mechanism analysis of HRG | 10.1109/isscaa.2008.4776369 | fulltext_unavailable_from_checked_sources |  |
| W0243 | Dynamics of rotating and vibrating thin hemispherical shell with mass and damping imperfections and parametrically driven by discrete electrodes | 10.1134/s2075108711010093 | fulltext_unavailable_from_checked_sources |  |
| W0244 | Dzhandzhgava, K |  | needs_search_no_verified_identifier |  |
| W0245 | Медикон Научно-Производственное Предприятие. Выполненные проекты[ EB/OL].[2021- 11-15]. https://www.medicon -miass.ru/completed |  | needs_search_no_verified_identifier |  |
| W0246 | Effective bias warm-up time reduction for MEMS gyroscopes based on active suppression of the coupling stiffness | 10.1038/s41378-019-0057-2 | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R0278_Effective bias warm-up time reduction for MEMS gyroscopes based on active suppression of the coupling stiffness.pdf |
| W0247 | Effect of drive-axis displacement on MEMS Birdbath Resonator Gyroscope performance | 10.1109/isiss.2017.7935697 | fulltext_unavailable_from_checked_sources |  |
| W0248 | Effects of Nonlinearity on the Angular Drift Error of an Electrostatic MEMS Rate Integrating Gyroscope | 10.1109/jsen.2019.2929352 | fulltext_unavailable_from_checked_sources |  |
| W0249 | E. J. Loper and D. D. Lynch, “Projected system performance based on recent HRG test result,” in Proc. IEEE/AIAA 5th Digit. Avionics Syst. Conf., Seattle, WA, USA, Oct./Nov. 1983, pp. 1811–1816 |  | needs_search_no_verified_identifier |  |
| W0250 | Electrical characterization of ALD-coated silicon dioxide micro-hemispherical shell resonators | 10.1109/memsys.2014.6765715 | fulltext_unavailable_from_checked_sources |  |
| W0251 | Comparison of long-term stability of AM versus FM gyroscopes | 10.1109/memsys.2016.7421790 | fulltext_unavailable_from_checked_sources |  |
| W0252 | В о л ч и х и н И А , В о л ч и х и н А И , М а л ю т и н Д М , et al. Волновые твердотельные гироскопы (аналитический обзор)[ J]. Известия Тульского государственного университета. Технические науки, 2017 (9 -2): 59-78 |  | needs_search_no_verified_identifier |  |
| W0253 | Ettus Research, LLC, http://www.ettus.com/ Retrieved 3/27/2001 |  | needs_search_no_verified_identifier |  |
| W0254 | Extended Kalman filtering based parameter estimation and drift compensation for a MEMS rate integrating gyroscope | 10.1016/j.sna.2016.09.019 | fulltext_unavailable_from_checked_sources |  |
| W0255 | Temperature Sensitivity and Shape Optimization of Solid-State Wave Gyroscopes | 10.1109/jsen.2016.2580670 | fulltext_unavailable_from_checked_sources |  |
| W0256 | Fabrication and characterization of microscale hemispherical shell resonatorwithdiamondelectrodesonsiliconsubstrate |  | needs_search_no_verified_identifier |  |
| W0257 | Fabrication and testing of hemispherical MEMS wineglass resonators | 10.1109/memsys.2013.6474333 | fulltext_unavailable_from_checked_sources |  |
| W0258 | Fabrication of hemispherical fused silica micro-resonator with tailored stiffness and mass distribution | 10.1109/memsys.2018.8346727 | fulltext_unavailable_from_checked_sources |  |
| W0259 | Bandwidth and noise analysis of high-Q MEMS gyroscope under force rebalance closed-loop control | 10.1088/1361-6439/abf32e | fulltext_unavailable_from_checked_sources |  |
| W0260 | Finite-window RLS algorithms | 10.1016/j.sigpro.2022.108599 | fulltext_unavailable_from_checked_sources |  |
| W0261 | Force to Rebalance Control of HRG and Suppression of Its Errors on the Basis of FPGA | 10.3390/s111211761 | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R0531_Force to Rebalance Control of HRG and Suppression of Its Errors on the Basis of FPGA.pdf |
| W0262 | Force-To-Rebalance Mode of a Resonator Gyro and Angular Rate Measurement Tests | 10.5302/j.icros.2014.13.1983 | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R0296_Force-To-Rebalance Mode of a Resonator Gyro and Angular Rate Measurement Tests.pdf |
| W0263 | Foucault pendulum on a chip: Rate integrating silicon MEMS gyroscope | 10.1016/j.sna.2012.01.029 | existing_local | C:/Users/11725/Desktop/HRG_WA/全角陀螺/新增资料_20261021_WoS/pdf/系统与控制/2012_Foucault_Pendulum.pdf |
| W0264 | Foucault, Sur un nouvelle demonstration experimentale du mouvement de la terre fondee sur la ﬁxite du plan de rotation, Comptes Rendus De L Academie Des Sciences 35 (1852) 421 |  | needs_search_no_verified_identifier |  |
| W0265 | Free vibration of rotating hollow spheres containing acoustic media | 10.1016/j.jsv.2008.11.020 | fulltext_unavailable_from_checked_sources |  |
| W0266 | Full Digital Control of Hemispherical Resonator Gyro Under Force-to-Rebalance Mode | 10.1109/jsen.2014.2339229 | existing_local | D:/学习资料/资料/全角陀螺/Full_Digital_Control_of_Hemispherical_Resonator_Gyro_Under_Force-to-Rebalance_Mode.pdf |
| W0267 | Fully-differential single resonator FM/whole angle gyroscope using CW/CCW mode separator | 10.1109/memsys.2017.7863610 | fulltext_unavailable_from_checked_sources |  |
| W0268 | Fused Quartz Dual-Shell Resonator Gyroscope | 10.1109/jmems.2022.3166213 | fulltext_unavailable_from_checked_sources |  |
| W0269 | Principles of a Micro-Rate Integrating Ring Gyroscope | 10.1109/taes.2012.6129662 | fulltext_unavailable_from_checked_sources |  |
| W0270 | Girard O, Caron J M, Berthier P. HRG technology: a promising gyrometer space equipment |  | needs_search_no_verified_identifier |  |
| W0271 | GnuRadio Community, “GnuRadio – Trac,” Feb. 2009; http://www.gnuradio.org/trac |  | needs_search_no_verified_identifier |  |
| W0272 | Gyroscopic measurement in a navigation system: U.S. Patent 9,217,640 |  | nonpaper_reference_not_downloaded |  |
| W0273 | Gyroscopic sensorUS: 2001 |  | needs_search_no_verified_identifier |  |
| W0274 | A Novel Temperature Compensation Method for a MEMS Gyroscope Oriented on a Periphery Circuit | 10.5772/56881 | fulltext_unavailable_from_checked_sources |  |
| W0275 | Optimization and Experimentation of Dual-Mass MEMS Gyroscope Quadrature Error Correction Methods | 10.3390/s16010071 | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R0313_Optimization and Experimentation of Dual-Mass MEMS Gyroscope Quadrature Error Correction Methods.pdf |
| W0276 | Design, Fabrication and Experiment of Double U-Beam MEMS Vibration Ring Gyroscope | 10.3390/mi10030186 | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R0314_Design_ Fabrication and Experiment of Double U-Beam MEMS Vibration Ring Gyroscope.pdf |
| W0277 | Temperature Energy Influence Compensation for MEMS Vibration Gyroscope Based on RBF NN‐GA‐KF Method | 10.1155/2018/2830686 | fulltext_unavailable_from_checked_sources |  |
| W0278 | Pole-Zero Temperature Compensation Circuit Design and Experiment for Dual-Mass MEMS Gyroscope Bandwidth Expansion | 10.1109/tmech.2019.2898098 | fulltext_unavailable_from_checked_sources |  |
| W0279 | Height Adjustment of 3-D Axisymmetric Microumbrella Shells for Tailoring Wineglass Frequency | 10.1109/tcpmt.2018.2886957 | fulltext_unavailable_from_checked_sources |  |
| W0280 | A State-Space Phase-Noise Model for Nonlinear MEMS Oscillators Employing Automatic Amplitude Control | 10.1109/tcsi.2009.2018932 | fulltext_unavailable_from_checked_sources |  |
| W0281 | Hemispherical glass shell resonators fabricated using Chemical Foaming Process | 10.1109/ectc.2015.7159911 | fulltext_unavailable_from_checked_sources |  |
| W0282 | &lt;title&gt;Hemispherical resonator gyro for precision pointing applications&lt;/title&gt; | 10.1117/12.211500 | fulltext_unavailable_from_checked_sources |  |
| W0283 | Hemispherical resonator gyro: Status report and test results |  | needs_search_no_verified_identifier |  |
| W0284 | High-precision control scheme for hemispherical resonator gyroscopes with application to aerospace navigation systems | 10.1016/j.ast.2021.107168 | fulltext_unavailable_from_checked_sources |  |
| W0285 | High Precision Hemispherical Resonator Gyroscopes With Oven Control Systems | 10.1109/jsen.2021.3050206 | fulltext_unavailable_from_checked_sources |  |
| W0286 | High-quality-factor viscoelastic nanomechanical resonators from moiré superlattices | 10.1038/s41467-025-58981-2 | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R0330_High-quality-factor viscoelastic nanomechanical resonators from moiré superlattices.pdf |
| W0287 | High Scale-Factor Stability Frequency-Modulated MEMS Gyroscope: 3-Axis Sensor and Integrated Electronics Design | 10.1109/tie.2017.2772212 | fulltext_unavailable_from_checked_sources |  |
| W0288 | Медикон Научно- Производственное Предприятие. HRG’s Production Line Project[EB/OL].[2023-5-12 ]. https://www.medicon -miass.ru/en/article/hrgs - production- line-project |  | needs_search_no_verified_identifier |  |
| W0289 | A mode-matched force-rebalance control for a MEMS vibratory gyroscope | 10.1016/j.sna.2018.02.016 | fulltext_unavailable_from_checked_sources |  |
| W0290 | HU Z， GALLACHER B． Extended Kalman filtering based parameter estimation and drift compensation for a MEMs mte integrating gyroscope |  | needs_search_no_verified_identifier |  |
| W0291 | A systematic approach for precision electrostatic mode tuning of a MEMS gyroscope | 10.1088/0960-1317/24/12/125003 | fulltext_unavailable_from_checked_sources |  |
| W0292 | Identification and compensation method for unbalance error in signal detection chain of Rate-Integrating hemispherical resonator gyro | 10.1016/j.measurement.2024.115599 | fulltext_unavailable_from_checked_sources |  |
| W0293 | Identification and Compensation Method of Unbalanced Error in Driving Chain for Rate-Integrating Hemispherical Resonator Gyro | 10.3390/s24134328 | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R0342_Identification and Compensation Method of Unbalanced Error in Driving Chain for Rate-Integrating Hemispherical Reso.pdf |
| W0294 | Identification and Compensation of Gain Mismatches for Whole-Angle Microhemispherical Resonator Gyroscope Based on Modal Reversal | 10.1109/jsen.2023.3332067 | fulltext_unavailable_from_checked_sources |  |
| W0295 | A MEMS-Based Three-Ring Capacitive Angular Position Sensor With an Absolute Zero Position Feature | 10.1109/tie.2024.3409884 | fulltext_unavailable_from_checked_sources |  |
| W0296 | A study on the fabrication of curved surfaces using magnetorheological fluid finishing | 10.1016/j.ijmachtools.2007.05.007 | fulltext_unavailable_from_checked_sources |  |
| W0297 | Investigation on Influences of Phase Delay on Performance of Resonator Gyroscopes |  | needs_search_no_verified_identifier |  |
| W0298 | Foucault pendulum on a chip: angle measuring silicon MEMS gyroscope | 10.1109/memsys.2011.5734386 | fulltext_unavailable_from_checked_sources |  |
| W0299 | North-finding with 0.004 radian precision using a silicon MEMS quadruple mass gyroscope with Q-factor of 1 million | 10.1109/memsys.2012.6170119 | fulltext_unavailable_from_checked_sources |  |
| W0300 | Sub-degree-per-hour silicon MEMS rate sensor with 1 million Q-factor | 10.1109/transducers.2011.5969216 | fulltext_unavailable_from_checked_sources |  |
| W0301 | Novel mismatch compensation methods for rate-integrating gyroscopes | 10.1109/plans.2012.6236889 | fulltext_unavailable_from_checked_sources |  |
| W0302 | A micromachined comb-drive tuning fork rate gyroscope | 10.1109/memsys.1993.296932 | fulltext_unavailable_from_checked_sources |  |
| W0303 | J. Cho, J. A. Gregory, K. Najafi, “Single -Cyrstal-Silicon vibratory cylindrical rate integrating gyroscope,” IEEE Transducers 2011, Beijing, China, 2011. CONTACT * K. Najafi, tel: 1-734-763-6650; najafi@umich.edu Table 2: All Software Control Performance Sampling 12bit, 64MS/s Loop Delay Adjustable |  | needs_search_no_verified_identifier |  |
| W0304 | MEMS rate and rate-integrating gyroscope control with commercial software defined radio hardware | 10.1109/transducers.2011.5969596 | existing_local | C:/Users/11725/Desktop/HRG_WA/全角陀螺/新增资料_20261021_WoS/pdf/电路与数字实现/2011_MEMS_Rate_Control.pdf |
| W0305 | Whole-angle-mode micromachined fused-silica birdbath resonator gyroscope (WA-BRG) | 10.1109/memsys.2014.6765563 | fulltext_unavailable_from_checked_sources |  |
| W0306 | Control of MEMS Disc Resonance Gyroscope (DRG) using a FPGA Platform | 10.1109/aero.2008.4526488 | fulltext_unavailable_from_checked_sources |  |
| W0307 | Kim D J, M’Closkey R T. A systematic method for tuning the dynamics of electrostatical ly actuated vibratory gyros |  | needs_search_no_verified_identifier |  |
| W0308 | A configurable single axis Si-MEMS Gyro | 10.1109/iss52949.2021.9619806 | fulltext_unavailable_from_checked_sources |  |
| W0309 | Performance of MEMS inertial sensors | 10.1109/plans.1998.669861 | fulltext_unavailable_from_checked_sources |  |
| W0310 | Leger, “Quapason- A new low-cost vibrating gyroscope,” in 3rd St |  | needs_search_no_verified_identifier |  |
| W0311 | Litres, 2022 |  | needs_search_no_verified_identifier |  |
| W0312 | Bias self-calibration techniques using silicon disc resonator gyroscope | 10.1109/isiss.2015.7102375 | fulltext_unavailable_from_checked_sources |  |
| W0313 | Loveday P W．Analysis and compensation of imper fection effects in piezoelectric vibratory gyroscopes |  | needs_search_no_verified_identifier |  |
| W0314 | Application of Federal Kalman Filter with Neural Networks in the Velocity and Attitude Matching of Transfer Alignment | 10.1155/2018/3039061 | fulltext_unavailable_from_checked_sources |  |
| W0315 | Lunin, V.A. Matveev, M.A. Besarab Volnovoy tverdotel'ny'i giroskop. Teoriya i tekhnologii [Hemispher ical resonator gyroscpe. Theory and technologies]. М.: Radiotehnika, 2014. 176 s. (in Russian) |  | needs_search_no_verified_identifier |  |
| W0316 | Northrop/Grumman Ad | 10.1109/mm.2008.30 | fulltext_unavailable_from_checked_sources |  |
| W0317 | MRIG frequency mismatch and quadrature control | 10.1109/isiss.2014.6782503 | fulltext_unavailable_from_checked_sources |  |
| W0318 | LYNCH D D．Vibratory gyro analysis by the melhod of averaging |  | needs_search_no_verified_identifier |  |
| W0319 | Lynch “Vibration-included drift in the hemispherical resonator gyro” Proc. of the Annual Meeting of the Institute of Navigation, 23-25 June, 1987 |  | needs_search_no_verified_identifier |  |
| W0320 | Quadrature control of Hemispherical Resonator Gyro based on FPGA | 10.1109/icemi.2011.6037926 | fulltext_unavailable_from_checked_sources |  |
| W0321 | Martynenko, I.V |  | needs_search_no_verified_identifier |  |
| W0322 | Comparison of hemispherical resonator gyro and optical gyros | 10.1109/62.257091 | fulltext_unavailable_from_checked_sources |  |
| W0323 | Matthews, “Vibratory rotation sensor with scanning-tunneling- transducer readout,” U.S |  | needs_search_no_verified_identifier |  |
| W0324 | Matveev, B.S. Lunin, M.A. Besarab Navigatsionny'e sistems na volnovy'kh tverdotel'ny'kh guroskopakh [Navigation systems based on hemispherical resonator gyroscopes], М.: Fismatlit, 2008. 240 s. (in Russian) |  | needs_search_no_verified_identifier |  |
| W0325 | Measurement method of frequency splitting for high- Q hemispherical resonator based on standing wave swing effect | 10.1109/inertial48129.2020.9090058 | fulltext_unavailable_from_checked_sources |  |
| W0326 | MEMS环形陀螺仪正交误差校正系统设计与实验 |  | needs_search_no_verified_identifier |  |
| W0327 | Merkuriev, V.V. Polpalkov Dinamika m icromehanicheskogo i volnovogo tverdotel'nogo giroskopov [Dynamics of micromechanical and hemesperical resonator gyroscopes]. М.: Fizmatlit, 2009. 228 s. ISBN 978-5- 9221-1125-6 (in Russian) |  | needs_search_no_verified_identifier |  |
| W0328 | Metallic Glass Hemispherical Shell Resonators | 10.1109/jmems.2014.2363581 | fulltext_unavailable_from_checked_sources |  |
| W0329 | M. F. Hutton and B. Friedland. Control system for angular displacement sensor, November 23 1976. US Patent 3,992,952 |  | needs_search_no_verified_identifier |  |
| W0330 | An Ultrahigh Vacuum Packaging Process Demonstrating Over 2 Million Q-Factor in MEMS Vibratory Gyroscopes | 10.1109/lsens.2017.2762287 | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R0404_An Ultrahigh Vacuum Packaging Process Demonstrating Over 2 Million Q-Factor in MEMS Vibratory Gyroscopes.pdf |
| W0331 | High Quality Factor Mode Ordered Dual Foucault Pendulum Gyroscope | 10.1109/icsens.2018.8589896 | fulltext_unavailable_from_checked_sources |  |
| W0332 | Micro Fountain-Like Resonators | 10.1109/ectc.2019.00139 | fulltext_unavailable_from_checked_sources |  |
| W0333 | Micro Hemispherical Resonators with Quality Factor of 1.18 Million Fabricated Via Laser Ablation | 10.1109/mems51782.2021.9375376 | fulltext_unavailable_from_checked_sources |  |
| W0334 | Micromachined 3-D glass-blown wineglass structures for vibratory MEMS applications |  | needs_search_no_verified_identifier |  |
| W0335 | An In-Run Automatic Demodulation Phase Error Compensation Method for MEMS Gyroscope in Full Temperature Range | 10.3390/mi15070825 | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R0410_An In-Run Automatic Demodulation Phase Error Compensation Method for MEMS Gyroscope in Full Temperature Range.pdf |
| W0336 | M. Kranz, G. Fedder, Micromechanical vibratory rate gyroscopes fabricated in conventional CMOS, in: Proc. Symposium Gyro Technology, Stuttgart, Germany, 1997, pp. 3.0–3.8 |  | needs_search_no_verified_identifier |  |
| W0337 | Model of the hemispherical resonator gyroscope construction damping | 10.20537/vm190108 | fulltext_unavailable_from_checked_sources |  |
| W0338 | Readout and Control Electronics for a Microelectromechanical Gyroscope | 10.1109/imtc.2006.328223 | fulltext_unavailable_from_checked_sources |  |
| W0339 | Control scheme and error suppression method for micro rate integrating gyroscopes | 10.1109/cgncc.2016.7829163 | fulltext_unavailable_from_checked_sources |  |
| W0340 | Microelectromechanical instrument and systems development at the Charles Stark Draper Laboratory, Inc | 10.1109/dasc.1997.637288 | fulltext_unavailable_from_checked_sources |  |
| W0341 | Energy loss in MEMS resonators and the impact on inertial and RF devices | 10.1109/sensor.2009.5285418 | fulltext_unavailable_from_checked_sources |  |
| W0342 | A Mode-Matched Silicon-Yaw Tuning-Fork Gyroscope With Subdegree-Per-Hour Allan Deviation Bias Instability | 10.1109/jmems.2008.2004794 | fulltext_unavailable_from_checked_sources |  |
| W0343 | Calibrated Data Simplification for Energy-Efficient Location Sensing in Internet of Things | 10.1109/jiot.2018.2869671 | fulltext_unavailable_from_checked_sources |  |
| W0344 | Natural Frequency Split Estimation for Inextensional Vibration of Imperfect Hemispherical Shell. J. Sound Vib. 2011, 330, 2094–2106 |  | needs_search_no_verified_identifier |  |
| W0345 | NavkiteTM—Protection of Inertial Navigation System Based on Interference Detection and Mitigation Solution |  | needs_search_no_verified_identifier |  |
| W0346 | A New Fuzzy PID Control System Based on Fuzzy PID Controller and Fuzzy Control Process | 10.1007/s40815-020-00904-y | fulltext_unavailable_from_checked_sources |  |
| W0347 | A new generation of IRS with innovative architecture based on HRG for satellite launch vehicles | 10.1134/s2075108716030135 | fulltext_unavailable_from_checked_sources |  |
| W0348 | Nguyen, Micromechanical Signal Processors, Ph.D. thesis, Univ. of Califor- nia, Berkeley, 1994 |  | needs_search_no_verified_identifier |  |
| W0349 | Asymptotic methods in the theory of non-linear oscillations | 10.1109/proc.1963.1739 | needs_bibliographic_version_review |  |
| W0350 | Nonlinearity Reduction in Disk Resonator Gyroscopes Based on the Vibration Amplification Effect | 10.1109/tie.2019.2939971 | fulltext_unavailable_from_checked_sources |  |
| W0351 | Painter, Micromachined Vibratory Gyroscopes with Imperfections, Ph.D. the- sis, Univ. of California, Irvine, 2005 |  | needs_search_no_verified_identifier |  |
| W0352 | An ARMA-Based Digital Twin for MEMS Gyroscope Drift Dynamics Modeling and Real-Time Compensation | 10.1109/jsen.2020.3028140 | fulltext_unavailable_from_checked_sources |  |
| W0353 | A Polysilicon Microhemispherical Resonating Gyroscope | 10.1109/jmems.2014.2327107 | fulltext_unavailable_from_checked_sources |  |
| W0354 | The development of a MEMS gyroscope for absolute angle measurement | 10.1109/tcst.2004.839568 | fulltext_unavailable_from_checked_sources |  |
| W0355 | Characterization of MEMS Resonator Nonlinearities Using the Ringdown Response | 10.1109/jmems.2016.2529296 | fulltext_unavailable_from_checked_sources |  |
| W0356 | Precision curved micro hemispherical resonator shells fabricated by poached-egg micro-molding | 10.1109/icsens.2012.6411085 | fulltext_unavailable_from_checked_sources |  |
| W0357 | Compensation of drifts in high-Q MEMS gyroscopes using temperature self-sensing | 10.1016/j.sna.2012.12.024 | fulltext_unavailable_from_checked_sources |  |
| W0358 | A MICROMACHINED VIBRATING RING GYROSCOPE | 10.31438/trf.hh1994.49 | related_version_not_cited_work | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R0438_A MICROMACHINED VIBRATING RING GYROSCOPE.pdf |
| W0359 | Bias Thermal Stability Improvement of Mode-Matching MEMS Gyroscope Using Mode Deflection | 10.1109/jmems.2022.3218723 | fulltext_unavailable_from_checked_sources |  |
| W0360 | P.Ward and A. Duwel. Oscillator phase noise: Systematic construction of an analytical model encompassing nonlinearity. IEEE Transactions on Ultrasonics, Ferroelectrics, and Frequency Control, vol. 58, no. 1, pp. 195–205, January 2011 |  | needs_search_no_verified_identifier |  |
| W0361 | Quasistatic nature of subsurface densification of soda lime silicate glass under nano- and Vickers indentation | 10.1016/j.ceramint.2024.06.054 | fulltext_unavailable_from_checked_sources |  |
| W0362 | 3-D hemispherical micro glass-shell resonator with integrated electrostatic excitation and capacitive detection transducers | 10.1109/memsys.2014.6765730 | fulltext_unavailable_from_checked_sources |  |
| W0363 | Rate Integrating Gyroscope Using Independently Controlled CW and CCW Modes on Single Resonator | 10.1109/jmems.2020.3039241 | fulltext_unavailable_from_checked_sources |  |
| W0364 | R. Candler, H. Li, M. Lutz, W.-T. Park, A. Partridge, G. Yama, T. Kenny, Investigation of energy loss mechanisms in micromechanical resonators, in: TRANSDUCERS, 12th International Conference on Solid-State Sensors, Actua- tors and Microsystems, 2003, vol. 1, 2003, pp. 332–335 |  | needs_search_no_verified_identifier |  |
| W0365 | RC}ZELLE D M．The hemispherical resonator gyro： From wineglass tO the planets |  | needs_search_no_verified_identifier |  |
| W0366 | Research on precise mechanical trimming of a micro shell resonator with T-shape masses using femtosecond laser ablation | 10.1016/j.sna.2019.03.025 | fulltext_unavailable_from_checked_sources |  |
| W0367 | Resonant pitch and roll silicon gyroscopes with sub-micron-gap slanted electrodes: Breaking the barrier toward high-performance monolithic inertial measurement units | 10.1038/micronano.2016.92 | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R0450_Resonant pitch and roll silicon gyroscopes with sub-micron-gap slanted electrodes_ Breaking the barrier toward high.pdf |
| W0368 | Rozelle, The hemispherical resonator gyro: from wineglass to the planets (AAS 09-176), in: Proc. 19th AAS/AIAA Space Flight Mechanics Meeting, 2009, pp. 1157–1178 |  | needs_search_no_verified_identifier |  |
| W0369 | Rozelle, “The hemispherical resonator gyro: From wineglass to the planets,” in Proc. 19th AAS/AIAA Space Flight Mech |  | needs_search_no_verified_identifier |  |
| W0370 | Inertial Technology for the Future | 10.1109/taes.1984.4502062 | fulltext_unavailable_from_checked_sources |  |
| W0371 | R.V. Ermakov, A.A. Lvov “Error analysis of an angle measuring stand based on an optical non -contact angle sensor.” Proc. of the IV Int . Sci. Conf. “Problems of control, information processing and transmission”. Saratov, Wright-Expo, 2015. Vol. 2. pp. 116‒123. (in Russian) |  | needs_search_no_verified_identifier |  |
| W0372 | METHOD FOR EVALUATING ANGULAR VELOCITY OF A PRECISION ROTARY TABLE | 10.21672/2074-1707.2019.48.4.144-164 | fulltext_unavailable_from_checked_sources |  |
| W0373 | Methods for testing and test results of inertial sensors intended for operation in helicopter-type aircraft | 10.23919/icins.2017.7995638 | fulltext_unavailable_from_checked_sources |  |
| W0374 | R.V. Ermakov, D.M. Kalihman, D.V. Kondratov, A.A. Lvov. “Investigation of the distribution of errors laws for sensors included in the test benches for setting angular velocities” Mathematical modeling, computer and full-scale experiment in the natural sciences. 2016. № 3. pp. 9‒16 |  | needs_search_no_verified_identifier |  |
| W0375 | R.V. Ermakov, D.V. Kondratov, A.A. L'vov, E.N. Skripal “Features of the application of micromechanical inertial sensors in operation on helicopter type aircraft”. Proc. of Int. Symp. "Reliability and Quality" , Penza, 2017, Vol. 2, p. 122–124. (in Russian) |  | needs_search_no_verified_identifier |  |
| W0376 | Development of a vibrational error model of a hemispherical resonator gyroscope | 10.23919/icins.2018.8405894 | fulltext_unavailable_from_checked_sources |  |
| W0377 | High-precision identification and compensation of nonlinear error in hemispherical resonator gyro | 10.1016/j.measurement.2024.114945 | fulltext_unavailable_from_checked_sources |  |
| W0378 | Self-calibration method for assembly errors of hemispherical resonator gyroscope | 10.1016/j.ijmecsci.2025.110811 | fulltext_unavailable_from_checked_sources |  |
| W0379 | NEAR-NAVIGATION GRADE QUAD MASS GYROSCOPE WITH Q-FACTOR LIMITED BY THERMO-ELASTIC DAMPING | 10.31438/trf.hh2016.68 | fulltext_unavailable_from_checked_sources |  |
| W0380 | Demonstration of a wide dynamic range angular rate sensor based on frequency modulation | 10.1109/icsens.2011.6127269 | fulltext_unavailable_from_checked_sources |  |
| W0381 | Temperature drift modeling of MEMS gyroscope based on genetic-Elman neural network | 10.1016/j.ymssp.2015.11.004 | fulltext_unavailable_from_checked_sources |  |
| W0382 | 1 MILLION Q-FACTOR DEMONSTRATED ON MICRO-GLASSBLOWN FUSED SILICA WINEGLASS RESONATORS WITH OUT-OF-PLANE ELECTROSTATIC TRANSDUCTION | 10.31438/trf.hh2014.18 | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R0467_1 MILLION Q-FACTOR DEMONSTRATED ON MICRO-GLASSBLOWN FUSED SILICA WINEGLASS RESONATORS WITH OUT-OF-PLANE ELECTROSTAT.pdf |
| W0383 | A drive error identification and compensation method for whole angle mode hemispherical resonator gyroscope | 10.1016/j.sna.2025.116402 | existing_local | D:/学习资料/资料/全角陀螺/1-s2.0-S0924424725002080-main.pdf |
| W0384 | ShaoP,MayberryCL,GaoX,etal. APolysiliconMicrohemisphericalResonatingGyroscope |  | needs_search_no_verified_identifier |  |
| W0385 | Shkel, Microtechnology comes of age, in: GPS World, 2011, pp. 43–50 |  | needs_search_no_verified_identifier |  |
| W0386 | Type I and Type II Micromachined Vibratory Gyroscopes | 10.1109/plans.2006.1650648 | fulltext_unavailable_from_checked_sources |  |
| W0387 | 2020 IEEE 33rd International Conference on Micro Electro Mechanical Systems (MEMS) | 10.1109/mems46641.2020 | fulltext_unavailable_from_checked_sources |  |
| W0388 | Gyroscopic drift compensation by using low cost sensors for improved attitude determination | 10.1016/j.measurement.2017.11.003 | fulltext_unavailable_from_checked_sources |  |
| W0389 | SONG M，ZHOU B，ZHANG Y，et a1．Contml scheme and error suppression method fbr micro rate integrating gyroscopes |  | needs_search_no_verified_identifier |  |
| W0390 | Dynamics and control of a MEMS angle measuring gyroscope | 10.1016/j.sna.2007.12.033 | fulltext_unavailable_from_checked_sources |  |
| W0391 | Control Scheme to Reduce the Effect of Structural Imperfections in a Rate Integrating MEMS Gyroscope | 10.1109/jsen.2014.2347238 | fulltext_unavailable_from_checked_sources |  |
| W0392 | Standing Wave Binding of Hemispherical Resonator Containing First–Third Harmonics of Mass Imperfection under Linear Vibration Excitation | 10.3390/s20195454 | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R0484_Standing Wave Binding of Hemispherical Resonator Containing First_Third Harmonics of Mass Imperfection under Linear.pdf |
| W0393 | Structural Changes in YBa2Cu3O7 Thin Films Modified with He+Focused Ion Beam for High-Temperature Superconductive Nanoelectronics | 10.1021/acsanm.4c00247.s001 | fulltext_unavailable_from_checked_sources |  |
| W0394 | Studies of frictional sliding contact by molecular dynamics assisted continuum mechanics | 10.1080/15376494.2022.2137885 | fulltext_unavailable_from_checked_sources |  |
| W0395 | Study on the thermoforming process of Hemispherical Resonator Gyros (HRGs) | 10.1109/isiss.2017.7935693 | fulltext_unavailable_from_checked_sources |  |
| W0396 | Substrate-decoupled 3D micro-shell resonators | 10.1109/icsens.2016.7808779 | fulltext_unavailable_from_checked_sources |  |
| W0397 | Substrate-decoupled, bulk-acoustic wave gyroscopes: Design and evaluation of next-generation environmentally robust devices | 10.1038/micronano.2016.15 | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R0489_Substrate-decoupled_ bulk-acoustic wave gyroscopes_ Design and evaluation of next-generation environmentally robust.pdf |
| W0398 | Synchronous integrator based on digital control system for silicon micromachined gyroscope | 10.1109/isiss.2015.7102389 | fulltext_unavailable_from_checked_sources |  |
| W0399 | Frequency modulation based angular rate sensor | 10.1109/memsys.2011.5734490 | fulltext_unavailable_from_checked_sources |  |
| W0400 | Investigation on influences of phase delay on performance of resonator gyroscopes | 10.1109/iss55898.2022.9926385 | fulltext_unavailable_from_checked_sources |  |
| W0401 | Temperature Drift Compensation for Hemispherical Resonator Gyro Based on Natural Frequency | 10.3390/s120506434 | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R0504_Temperature Drift Compensation for Hemispherical Resonator Gyro Based on Natural Frequency.pdf |
| W0402 | Temperature Drift of a Hemispherical Resonator Gyro (HRG) | 10.3103/s0025654418070014 | fulltext_unavailable_from_checked_sources |  |
| W0403 | The error analysis of Hemispherical Resonator Gyro based on a vibration model | 10.1109/iaeac.2017.8054399 | fulltext_unavailable_from_checked_sources |  |
| W0404 | The GYTRIX Quartz Crystal Axisymmetric Mems GYRO: Preliminary measurements | 10.1109/inertial60399.2024.10502036 | fulltext_unavailable_from_checked_sources |  |
| W0405 | The hemispherical resonator gyro: From wineglass to the planets. 19th AAS AIAA Space Flight Mechanics Meeting, Vol 134, 1157–1178 (2013) |  | needs_search_no_verified_identifier |  |
| W0406 | The influence of mass imperfections on the evolution of standing waves in slowly rotating spherical bodies | 10.1016/j.jsv.2010.08.001 | fulltext_unavailable_from_checked_sources |  |
| W0407 | The modeling of hemispherical resonator gyro and its space applications | 10.1117/12.903641 | fulltext_unavailable_from_checked_sources |  |
| W0408 | Theory of plates and shells |  | nonpaper_reference_not_downloaded |  |
| W0409 | The time division multiplexing errors introduced by the system are optimized |  | needs_search_no_verified_identifier |  |
| W0410 | Trebukhov, K.A. Bakhonin, S.P. Redkin, A.V. Nekrasov Razrabotka BINS na osnovetverdotel'nogo volnovogo giroskopa [Strapdown INS design basing on hemispherical resonator gyroscope] Proc. oftheconf. "Navigation, hydrography and Oceanology, St. Petersburg, 2011 |  | needs_search_no_verified_identifier |  |
| W0411 | Vandebeuque P .Gyroscopic sensor and method for manufacturing such a sensor:13/5095 36 |  | nonpaper_reference_not_downloaded |  |
| W0412 | Virtual Precession Self-Calibration Method for Hemispherical Resonator Gyro Based on Sinusoidal Injection | 10.1109/tim.2024.3502765 | fulltext_unavailable_from_checked_sources |  |
| W0413 | Modeling, Characterization, and Compensation of Detection and Actuation Coupling Errors for Whole-Angle Micro Hemispherical Resonant Gyroscope | 10.1109/tim.2024.3418096 | fulltext_unavailable_from_checked_sources |  |
| W0414 | Weak Capacitance Detection Circuit of Micro-Hemispherical Gyroscope Based on Common-Mode Feedback Fusion Modulation and Demodulation | 10.3390/mi14061161 | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R0523_Weak Capacitance Detection Circuit of Micro-Hemispherical Gyroscope Based on Common-Mode Feedback Fusion Modulation.pdf |
| W0415 | Whole‐Angle MEMS Gyroscopes | 10.1002/9781119441908 | fulltext_unavailable_from_checked_sources |  |
| W0416 | Enhanced temperature stability of sensitivity for MEMS gyroscope based on frequency mismatch control | 10.1007/s00542-016-3114-x | fulltext_unavailable_from_checked_sources |  |
| W0417 | W. W. Stripling, D. D. Lynch, and J. R. Baskett, “Hemispherical resonator gyro: Principle, design, and performance,” in Proc. Symp. Gyro Technol., Stuttgart, Germany, Sep. 1992, pp. 22–23 |  | needs_search_no_verified_identifier |  |
| W0418 | Hybrid methods for MEMS gyro signal noise reduction with fast convergence rate and small steady-state error | 10.1016/j.sna.2017.11.013 | fulltext_unavailable_from_checked_sources |  |
| W0419 | Nonlinearity Harmonic Error Compensation Method Based on Intelligent Identification for Rate Integrating Resonator Gyroscope | 10.3390/act14020068 | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R0533_Nonlinearity Harmonic Error Compensation Method Based on Intelligent Identification for Rate Integrating Resonator.pdf |
| W0420 | Yan et al., “Self-excitation enabled decoupling, calibration, and com- pensation of errors for whole-angle hemispherical resonator gyroscope,” IEEE Trans |  | needs_search_no_verified_identifier |  |
| W0421 | Design and Verification of a Structure for Isolating Packaging Stress in SOI MEMS Devices | 10.1109/jsen.2016.2646723 | fulltext_unavailable_from_checked_sources |  |
| W0422 | Closed loop driving and detect circuit of piezoelectric solid-state micro gyroscope | 10.1007/s00542-013-1889-6 | fulltext_unavailable_from_checked_sources |  |
| W0423 | Yu S, Wu X, Xi X, et al. A high-precision mode matching method for rate-integrating honey- comb disk resonator gyroscope |  | needs_search_no_verified_identifier |  |
| W0424 | Modeling and compensation of MEMS gyroscope output data based on support vector machine | 10.1016/j.measurement.2012.02.001 | fulltext_unavailable_from_checked_sources |  |
| W0425 | Research on the method to improve the vibration stability of vibratory cylinder gyroscopes under temperature variation | 10.1007/s12541-017-0210-5 | fulltext_unavailable_from_checked_sources |  |
| W0426 | A Sub-0.1°/h Bias-Instability Split-Mode MEMS Gyroscope With CMOS Readout Circuit | 10.1109/jssc.2018.2844285 | fulltext_unavailable_from_checked_sources |  |
| W0427 | Z. Gao, R. Xu, F. Nan, Y . Han, D. Li, and Y . Zhang, “Identiﬁcation and calibration of the detection signal distortion in whole angle mode hemispherical resonator gyro,” IEEE Trans. Instrum. Meas. , vol. 73, pp. 1–9, 2024 |  | needs_search_no_verified_identifier |  |
| W0428 | Modeling and Compensation of Readout, Actuation, and Damping Errors for Whole-Angle Hemispherical Resonator Gyroscope | 10.1109/jsen.2025.3529863 | fulltext_unavailable_from_checked_sources |  |
| W0429 | Adaptive mismatch compensation for vibratory gyroscopes | 10.1109/isiss.2014.6782514 | fulltext_unavailable_from_checked_sources |  |
| W0430 | ZhangY,YuS,GuoK,etal. AHigh-PerformanceRate-IntegratingHemisphericalResonantGyros (cid:14) with 0.00753 /h Bias Instability |  | needs_search_no_verified_identifier |  |
| W0431 | A High-Performance Rate-Integrating Hemispherical Resonant Gyros with 0.00753°/h Bias Instability | 10.1109/inertial51137.2021.9430490 | fulltext_unavailable_from_checked_sources |  |
| W0432 | The Energy Compensation of the HRG Based on the Double-Frequency Parametric Excitation of the Discrete Electrode | 10.3390/s20123549 | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R0547_The Energy Compensation of the HRG Based on the Double-Frequency Parametric Excitation of the Discrete Electrode.pdf |
| W0433 | Precision mode matching of MEMS gyroscope by feedback control | 10.1109/icsens.2011.6126998 | fulltext_unavailable_from_checked_sources |  |
| W0434 | Zhuralev , “Controlled Foucault pendulum as a model of a class of free gyros,” Mechanics of Solids, v. 32, n. 6, p. 21-28, 1997 |  | needs_search_no_verified_identifier |  |
| W0435 | Zhuravlyov, D.M. Klimov Volnovoy tverdotel'ny'i giroskop [Hemispherical resonator gyroscope]. М.: Nauka, 1985. (in Russian) |  | needs_search_no_verified_identifier |  |
| W0436 | Analysis and Compensation of Bias Drift of Force-to-Rebalanced Micro-Hemispherical Resonator Gyroscope Caused by Assembly Eccentricity Error | 10.1109/jmems.2022.3228268 | fulltext_unavailable_from_checked_sources |  |
| W0437 | 一种半球谐振陀螺谐振子动力学建模方法 |  | needs_search_no_verified_identifier |  |
| W0438 | 一种速率积分半球谐振陀螺自校准方法 |  | needs_search_no_verified_identifier |  |
| W0439 | 严隆辉，江黎，蒋春桥，等．力反馈模式半球谐振陀螺幅 度控制方法优化 |  | needs_search_no_verified_identifier |  |
| W0440 | 伊国兴，魏振楠，王常虹，等．半球谐振陀螺控制及 补偿技术 |  | needs_search_no_verified_identifier |  |
| W0441 | 伊国兴，魏振楠，王常虹，等．半球谐振陀螺控制及补偿 技术EJ]．宇航学报，2020，41(6)：780—789． YI Guoxing，WEI Zhennan，WANG Changhong，et a1． Hemispherical resonator gyro control and compensation technology |  | needs_search_no_verified_identifier |  |
| W0442 | 全角模式半球谐振陀螺建模与控制算法研究 |  | needs_search_no_verified_identifier |  |
| W0443 | 全角模式半球谐振陀螺振型控制与角度检测 |  | needs_search_no_verified_identifier |  |
| W0444 | 全角模式半球谐振陀螺 的阻尼误差修调与补偿技术研究 |  | needs_search_no_verified_identifier |  |
| W0445 | 全角模式半球谐振陀螺阻尼误差补偿方法研究 |  | needs_search_no_verified_identifier |  |
| W0446 | 六波腹金属杯形陀螺控制系统研究 |  | needs_search_no_verified_identifier |  |
| W0447 | 分时复用半球谐振陀螺数字控制平台设计[A]. 惯性技术发展 动态发展方向研讨会文集 ——惯性传感器技术与应用 |  | needs_search_no_verified_identifier |  |
| W0448 | 刘吉利，李建朋，武志忠，等．半球谐振陀螺零偏温 度漂移的自补偿 |  | needs_search_no_verified_identifier |  |
| W0449 | 刘鸿文 ，林建兴 ，曹曼玲. 板壳理论 |  | nonpaper_reference_not_downloaded |  |
| W0450 | 力平衡模式下半球谐振陀螺 正交误差控制 |  | needs_search_no_verified_identifier |  |
| W0451 | 加速度对半球谐振陀螺控制系统影响分析及抑制方法 |  | needs_search_no_verified_identifier |  |
| W0452 | 半球谐振子磁流变抛光的关键技术研究 |  | needs_search_no_verified_identifier |  |
| W0453 | 半球谐振子金属化镀膜工艺与关键特性研究 |  | needs_search_no_verified_identifier |  |
| W0454 | 半球谐振子金属化镀膜残余应力与膜厚均匀性研究 |  | needs_search_no_verified_identifier |  |
| W0455 | 半球谐振陀螺 (HRG) 信号处理技术 |  | needs_search_no_verified_identifier |  |
| W0456 | 半球谐振陀螺仪研制历程及关键技术 |  | needs_search_no_verified_identifier |  |
| W0457 | 半球谐振陀螺仪谐振子振动特性的有限元分 析 |  | needs_search_no_verified_identifier |  |
| W0458 | 半球谐振陀螺发展的技术特征 |  | needs_search_no_verified_identifier |  |
| W0459 | 半球谐振陀螺惯性系统设计探讨 |  | needs_search_no_verified_identifier |  |
| W0460 | 半球谐振陀螺技术发展概述 |  | needs_search_no_verified_identifier |  |
| W0461 | 半球谐振陀螺技术发展趋 势 |  | needs_search_no_verified_identifier |  |
| W0462 | 半球谐振陀螺振子耦合振动的近似解析分析 |  | needs_search_no_verified_identifier |  |
| W0463 | 半球谐振陀螺控制技术研究 |  | needs_search_no_verified_identifier |  |
| W0464 | 半球谐振陀螺温漂误 差补偿方法分析简述 |  | needs_search_no_verified_identifier |  |
| W0465 | 半球谐振陀螺的关键技术──信号闭环检测理论及电路 |  | needs_search_no_verified_identifier |  |
| W0466 | 半球谐振陀螺的机理分析 |  | needs_search_no_verified_identifier |  |
| W0467 | 半球谐振陀螺真空度要求分析 |  | needs_search_no_verified_identifier |  |
| W0468 | 半球谐振陀螺研究现状与发展趋势 |  | needs_search_no_verified_identifier |  |
| W0469 | 半球谐振陀螺精密集成组装技术探讨 |  | needs_search_no_verified_identifier |  |
| W0470 | 半球谐振陀螺组合在轨应用及数据分析方法 |  | needs_search_no_verified_identifier |  |
| W0471 | 半球谐振陀螺组合零偏稳定性提升技术研究 |  | needs_search_no_verified_identifier |  |
| W0472 | 半球谐振陀螺误差分析和滤波方法研究 |  | needs_search_no_verified_identifier |  |
| W0473 | 半球谐振陀螺调平技术发展综述 |  | needs_search_no_verified_identifier |  |
| W0474 | 半球谐振陀螺静电驱动建模与分析 |  | needs_search_no_verified_identifier |  |
| W0475 | 半球谐振陀螺频率裂解机理与平衡方法研究 [D ]. 哈尔滨工业大学， 2019. |  | needs_search_no_verified_identifier |  |
| W0476 | 半球陀螺谐振子的力学性能及振动特性分析 |  | needs_search_no_verified_identifier |  |
| W0477 | 南方伯，郜中星，徐睿东，等．全角半球谐振陀螺控 制回路的动态特性研究 |  | needs_search_no_verified_identifier |  |
| W0478 | 基于 FPGA 的压电半球谐振陀螺数字测控系 统设计 |  | needs_search_no_verified_identifier |  |
| W0479 | 基于二维质点振动模型的半球谐振陀螺谐振子进 动分析 |  | needs_search_no_verified_identifier |  |
| W0480 | 基于优化半球陀螺谐振子性能的工艺技术 |  | needs_search_no_verified_identifier |  |
| W0481 | 基于分次吹制工艺的微半球陀螺制作 |  | needs_search_no_verified_identifier |  |
| W0482 | 基于半球谐振陀螺仪的姿态测 量系统研究 |  | needs_search_no_verified_identifier |  |
| W0483 | 基于多电极的半球谐振陀螺信号检测 |  | needs_search_no_verified_identifier |  |
| W0484 | 基于平板电极的半球谐振陀螺全角技术研究 |  | needs_search_no_verified_identifier |  |
| W0485 | 基于超快激光技术的半球谐振陀螺点式修调方 法 |  | needs_search_no_verified_identifier |  |
| W0486 | 壳体谐振陀螺仪的动力学分析 |  | needs_search_no_verified_identifier |  |
| W0487 | 复杂结构薄壁件小直径永磁球头磁流变抛光技术 |  | needs_search_no_verified_identifier |  |
| W0488 | 实践-9 卫星创中国航天技术多项第一 |  | needs_search_no_verified_identifier |  |
| W0489 | 张岚昕，赵万良，李绍良，等．半球谐振陀螺全角模 式信号处理控制方法 |  | needs_search_no_verified_identifier |  |
| W0490 | 弹性力学第五版下册 |  | nonpaper_reference_not_downloaded |  |
| W0491 | 彭丁聪．卡尔曼滤波的基本原理及应用 |  | needs_search_no_verified_identifier |  |
| W0492 | 微半球振动陀螺的装配误差分析与精密微调机构设计 |  | needs_search_no_verified_identifier |  |
| W0493 | 微半球谐振陀螺仪零位温度特性与补偿技术研究 |  | needs_search_no_verified_identifier |  |
| W0494 | 惯性器件的现状与发展动向 |  | needs_search_no_verified_identifier |  |
| W0495 | 惯性导航 . 第 2 版 |  | nonpaper_reference_not_downloaded |  |
| W0496 | 提高数字信号信噪比的最佳波形平均方法 |  | needs_search_no_verified_identifier |  |
| W0497 | 新型熔融石英微半球谐振陀螺关键技术研究 |  | needs_search_no_verified_identifier |  |
| W0498 | 曹慧亮，李宏生，王寿荣，等．MEMs陀螺仪结构模 型及系统仿真 |  | needs_search_no_verified_identifier |  |
| W0499 | 李建朋，夏悦，付明睿，等．面向商业航天的基于新 型固态谐振陀螺的敏感器设计 |  | needs_search_no_verified_identifier |  |
| W0500 | 李建朋，武志忠，刘吉利，等．一种半球谐振陀螺振 幅控制方法 |  | needs_search_no_verified_identifier |  |
| W0501 | 熔融石英微半球谐振结构工艺优化与品质因数提升技术研究 |  | needs_search_no_verified_identifier |  |
| W0502 | 王铎，程靳. 理论力学 |  | nonpaper_reference_not_downloaded |  |
| W0503 | 球谐振陀螺模型分析与控制电路技术研究 |  | needs_search_no_verified_identifier |  |
| W0504 | 石英半球谐振子精密加工技术探讨 |  | needs_search_no_verified_identifier |  |
| W0505 | 硅微机械陀螺仪数字化静电补偿与调谐技术研究和实验 |  | needs_search_no_verified_identifier |  |
| W0506 | 秦永元. 惯性导航 |  | nonpaper_reference_not_downloaded |  |
| W0507 | 童余德，周永余，陈永冰，等．基于MATLAB的卡尔 曼滤波法参数辨识与仿真 |  | needs_search_no_verified_identifier |  |
| W0508 | 系统辨识理论及 MATLAB 仿真 |  | nonpaper_reference_not_downloaded |  |
| W0509 | 系统辨识理论及应用 |  | nonpaper_reference_not_downloaded |  |
| W0510 | 翁智远,王远功. 弹性薄壳理论 |  | nonpaper_reference_not_downloaded |  |
| W0511 | 自适应信号处理技术 |  | nonpaper_reference_not_downloaded |  |
| W0512 | 董景新. 微惯性仪表 |  | nonpaper_reference_not_downloaded |  |
| W0513 | 误差理论与数据处理 |  | nonpaper_reference_not_downloaded |  |
| W0514 | 谐振子密度偏差引起的频率裂解的分析 |  | needs_search_no_verified_identifier |  |
| W0515 | 谐振陀螺及半球壳谐振子陀螺仪 |  | needs_search_no_verified_identifier |  |
| W0516 | 赵万良，成宇翔，孙殿竣，等．MEMS半球谐振陀螺 的角速度积分及其FPGA设计 |  | needs_search_no_verified_identifier |  |
| W0517 | 赵明洋．全角模式半球谐振陀螺控制电路设计与实 现 |  | needs_search_no_verified_identifier |  |
| W0518 | 载体运 动条件下半球谐振陀螺的运动方程 |  | needs_search_no_verified_identifier |  |
| W0519 | 速率积分半球谐振陀螺建模与控制方法研究 |  | needs_search_no_verified_identifier |  |
| W0520 | 速率积分半球谐振陀螺误差建模及控制方法研究 |  | needs_search_no_verified_identifier |  |
| W0521 | 郜中星，徐睿东，张勇刚．基于最小均方算法的半球 谐振子特征参数辨识方法 |  | needs_search_no_verified_identifier |  |
| W0522 | 陈小娟，李恺，王德钊，等．半球谐振陀螺力反馈控 制回路设计 |  | needs_search_no_verified_identifier |  |
| W0523 | 非线性跟踪─微分器 |  | needs_search_no_verified_identifier |  |
| W0524 | 马特维耶夫，巴萨拉布，利帕特尼科夫，克拉夫琴科，阿廖欣（著） ，杨亚 非，赵辉（译） . 固体波动陀螺 |  | nonpaper_reference_not_downloaded |  |
| W0525 | 高精度石英半球裸振子微应力制造 |  | needs_search_no_verified_identifier |  |
| W0526 | Solid-state wave gyroscope: A new-generation inertial sensor | 10.23919/icins.2017.7995651 | fulltext_unavailable_from_checked_sources |  |
| W0527 | Delhaye. 2018. 1 |  | needs_search_no_verified_identifier |  |
| W0528 | Li. 2020. 1 |  | needs_search_no_verified_identifier |  |
| W0529 | Wang. 2024 |  | needs_search_no_verified_identifier |  |
| W0530 | Hemispherical resonator gyro: Principle, design, and performance |  | needs_search_no_verified_identifier |  |
| W0531 | Projected system performance based on recent HRG test result |  | needs_search_no_verified_identifier |  |
| W0532 | Vibration of a hemispherical shell gyro excited by an electrostatic field | 10.3233/jae-1999-159 | fulltext_unavailable_from_checked_sources |  |
| W0533 | Strapdown inertial navigation system based on a hemispherical resonance gyro | 10.1134/s2075108710020021 | fulltext_unavailable_from_checked_sources |  |
| W0534 | Innovative mechanization to optimize inertial sensors for high or low rate operations |  | needs_search_no_verified_identifier |  |
| W0535 | Extraction of double-oscillation-frequency sinusoids in vibratory rotation sensors |  | needs_search_no_verified_identifier |  |
| W0536 | Hemispherical resonant gyro control |  | needs_search_no_verified_identifier |  |
| W0537 | Vibratory rotation sensor with scanning-tunneling-transducer readout |  | needs_search_no_verified_identifier |  |
| W0538 | Navkite™ - Protection of inertial navigation system based on interference detection and mitigation solution | 10.1109/iss58390.2023.10361936 | fulltext_unavailable_from_checked_sources |  |
| W0539 | A System-Level Calibration and Integrated Navigation Technology of HRG-based SINSDVL System for Underwater Vehicles | 10.1109/icma57826.2023.10216258 | fulltext_unavailable_from_checked_sources |  |
| W0540 | Natural frequency split estimation for inextensional vibration of imperfect hemispherical shell | 10.1016/j.jsv.2010.11.014 | fulltext_unavailable_from_checked_sources |  |
| W0541 | A Temperature Error Parallel Processing Model for MEMS Gyroscope based on a Novel Fusion Algorithm | 10.3390/electronics9030499 | fulltext_unavailable_from_checked_sources |  |
| W0542 | $0.0062\ {}^{\circ}/\sqrt{hr}$ Angle Random Walk and $0.027\ {}^{\circ}/hr$ Bias Instability from a Micro-Shell Resonator Gyroscope with Surface Electrodes | 10.1109/mems46641.2020.9056391 | fulltext_unavailable_from_checked_sources |  |
| W0543 | Influence of Ti and Cr Adhesion Layers on Ultrathin Au Films | 10.1021/acsami.7b10136 | fulltext_unavailable_from_checked_sources |  |
| W0544 | Investigations on the effect of substrate temperature on the properties of reactively sputtered zirconium carbide thin films | 10.1016/j.jallcom.2016.10.225 | fulltext_unavailable_from_checked_sources |  |
| W0545 | Review of the effect and progress in uniform films prepared by the magnetron sputtering method | 10.1039/d5ce00515a | fulltext_unavailable_from_checked_sources |  |
| W0546 | Reaching silicon-based NEMS performances with 3D printed nanomechanical resonators | 10.1038/s41467-021-26353-1 | fulltext_unavailable_from_checked_sources |  |
| W0547 | Wafer‐Level Manufacturing of MEMS H<sub>2</sub> Sensing Chips Based on Pd Nanoparticles Modified SnO<sub>2</sub> Film Patterns | 10.1002/advs.202302614 | fulltext_unavailable_from_checked_sources |  |
| W0548 | Structural Changes in YBa<sub>2</sub>Cu<sub>3</sub>O<sub>7</sub> Thin Films Modified with He<sup>+</sup>-Focused Ion Beam for High-Temperature Superconductive Nanoelectronics | 10.1021/acsanm.4c00247 | fulltext_unavailable_from_checked_sources |  |
| W0549 | Hydrogen annealing induced physical properties of ZnTe thin films | 10.1016/j.ijhydene.2022.02.169 | fulltext_unavailable_from_checked_sources |  |
| W0550 | Microtechnology comes of age |  | needs_search_no_verified_identifier |  |
| W0551 | Performance of MEMS inertial sensors | 10.2514/6.1998-4400 | fulltext_unavailable_from_checked_sources |  |
| W0552 | Investigation of energy loss mechanisms in micromechanical resonators | 10.1109/sensor.2003.1215320 | fulltext_unavailable_from_checked_sources |  |
| W0553 | Sur un nouvelle demonstration experimentale du mouvement de la terre fondee sur la fixite du plan de rotation |  | needs_search_no_verified_identifier |  |
| W0554 | An Automatically Mode-Matched MEMS Gyroscope With Wide and Tunable Bandwidth | 10.1109/jmems.2014.2299234 | fulltext_unavailable_from_checked_sources |  |
| W0555 | Electromechanical Systems in Microtechnology and Mechatronics | 10.1007/978-3-642-10806-8 | fulltext_unavailable_from_checked_sources |  |
| W0556 | A high-order theory of a thermoelastic beams and its application to the MEMS/NEMS analysis and simulations | 10.1007/s00419-015-1090-8 | fulltext_unavailable_from_checked_sources |  |
| W0557 | Micromachined inertial sensors | 10.1109/5.704269 | fulltext_unavailable_from_checked_sources |  |
| W0558 | Theory of the Vibrating String as an Angular Motion Sensor | 10.1115/1.3629671 | fulltext_unavailable_from_checked_sources |  |
| W0559 | A novel piezoelectrically actuated flexural/torsional vibrating beam gyroscope | 10.1016/j.jsv.2007.10.017 | fulltext_unavailable_from_checked_sources |  |
| W0560 | A numerical efficiency study on the active vibration control for a FGPM beam | 10.1016/j.compstruct.2017.09.036 | fulltext_unavailable_from_checked_sources |  |
| W0561 | Effect of geometrical electrode defects on the bias and sensitivity of tuning fork angular rate sensor | 10.1109/freq.2001.956287 | fulltext_unavailable_from_checked_sources |  |
| W0562 | Microcrystalline diamond micromechanical resonators with quality factor limited by thermoelastic damping | 10.1063/1.4793234 | fulltext_unavailable_from_checked_sources |  |
| W0563 | Support Loss and Q Factor Enhancement for a Rocking Mass Microgyroscope | 10.3390/s111009807 | fulltext_unavailable_from_checked_sources |  |
| W0564 | Vibration sensitivity analytical analysis for rocking mass microgyroscope | 10.1007/s00542-014-2197-5 | fulltext_unavailable_from_checked_sources |  |
| W0565 | Design and development of a MEMS butterfly resonator using synchronizing beam and out of plane actuation | 10.1007/s00542-019-04705-8 | fulltext_unavailable_from_checked_sources |  |
| W0566 | A Novel High-Sensitivity Butterfly Gyroscope Driven by Horizontal Driving Force | 10.1109/jsen.2018.2886019 | fulltext_unavailable_from_checked_sources |  |
| W0567 | Influences of the Structure Parameters on Sensitivity and Brownian Noise of the Disk Resonator Gyroscope | 10.1109/jmems.2017.2679726 | fulltext_unavailable_from_checked_sources |  |
| W0568 | Vibration modeling of disk resonator gyroscope by wave propagation | 10.1016/j.jsv.2018.12.020 | fulltext_unavailable_from_checked_sources |  |
| W0569 | Investigation on the Quality Factor Limit of the (111) Silicon Based Disk Resonator | 10.3390/mi9010025 | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R0769_Investigation on the Quality Factor Limit of the _111_ Silicon Based Disk Resonator.pdf |
| W0570 | Quality Factor Improvement in the Disk Resonator Gyroscope by Optimizing the Spoke Length Distribution | 10.1109/jmems.2018.2820101 | fulltext_unavailable_from_checked_sources |  |
| W0571 | An investigation on the ring thickness distribution of disk resonator gyroscope with high mechanical sensitivity | 10.1016/j.ijmecsci.2016.08.020 | fulltext_unavailable_from_checked_sources |  |
| W0572 | Q-factor optimization in disk resonator gyroscopes via geometric parameterization | 10.1109/memsys.2016.7421800 | fulltext_unavailable_from_checked_sources |  |
| W0573 | System Identification of a MEMS Gyroscope | 10.1115/1.1369360 | fulltext_unavailable_from_checked_sources |  |
| W0574 | A HARPSS polysilicon vibrating ring gyroscope | 10.1109/84.925732 | fulltext_unavailable_from_checked_sources |  |
| W0575 | 100K Q-factor toroidal ring gyroscope implemented in wafer-level epitaxial silicon encapsulation process | 10.1109/memsys.2014.6765564 | fulltext_unavailable_from_checked_sources |  |
| W0576 | A Novel Mechanical Frequency Tuning Method Based on Mass-Stiffness Decoupling for MEMS Gyroscopes | 10.3390/mi13071052 | fulltext_unavailable_from_checked_sources |  |
| W0577 | Performance and design of a silicon micromachined gyro |  | needs_search_no_verified_identifier |  |
| W0578 | Design of a Multiple Folded-Beam Disk Resonator with High Quality Factor | 10.3390/mi13091468 | fulltext_unavailable_from_checked_sources |  |
| W0579 | 0.015 Degree-Per-Hour Honeycomb Disk Resonator Gyroscope | 10.1109/jsen.2020.3046716 | fulltext_unavailable_from_checked_sources |  |
| W0580 | A Novel Vibration Mode Testing Method for Cylindrical Resonators Based on Microphones | 10.3390/s150101954 | fulltext_unavailable_from_checked_sources |  |
| W0581 | Static balancing of metal resonators of cylindrical resonator gyroscopes | 10.1134/s2075108714040038 | fulltext_unavailable_from_checked_sources |  |
| W0582 | Research on cylindrical resonators’ damping asymmetry trimming method utilizing damping characteristic of piezoelectric electrodes | 10.1063/1.5016484 | fulltext_unavailable_from_checked_sources |  |
| W0583 | Batch-fabricated high Q-factor microcrystalline diamond cylindrical resonator | 10.1109/memsys.2015.7051080 | fulltext_unavailable_from_checked_sources |  |
| W0584 | A 5.86 Million Quality Factor Cylindrical Resonator with Improved Structural Design Based on Thermoelastic Dissipation Analysis | 10.3390/s20216003 | fulltext_unavailable_from_checked_sources |  |
| W0585 | A study on Q factor of the trimmed resonator for vibratory cupped gyroscopes | 10.1016/j.sna.2014.07.016 | fulltext_unavailable_from_checked_sources |  |
| W0586 | Characterization of the Bell-Shaped Vibratory Angular Rate Gyro | 10.3390/s130810123 | fulltext_unavailable_from_checked_sources |  |
| W0587 | Frequency Split Elimination Method for a Solid-State Vibratory Angular Rate Gyro with an Imperfect Axisymmetric-Shell Resonator | 10.3390/s150203204 | fulltext_unavailable_from_checked_sources |  |
| W0588 | Design and experiment of a novel bell-shaped vibratory gyro | 10.1016/j.sna.2015.10.036 | fulltext_unavailable_from_checked_sources |  |
| W0589 | Vibration analysis of a piezoelectric micromachined modal gyroscope (PMMG) | 10.1088/0960-1317/19/12/125008 | fulltext_unavailable_from_checked_sources |  |
| W0590 | Modeling analysis of piezoelectric micromachined modal gyroscope (PMMG) | 10.1109/nems.2009.5068583 | fulltext_unavailable_from_checked_sources |  |
| W0591 | Microscale pierced shallow shell resonators: A test vehicle to study surface loss | 10.1109/memsys.2017.7863614 | fulltext_unavailable_from_checked_sources |  |
| W0592 | Highly-symmetric silicon dioxide shallow shell resonators with angstrom-level roughness | 10.1109/icsens.2015.7370486 | fulltext_unavailable_from_checked_sources |  |
| W0593 | Whispering gallery mode based on-chip glass microbubble resonator for thermal sensing | 10.1109/transducers.2017.7994128 | fulltext_unavailable_from_checked_sources |  |
| W0594 | Investigation of wine glass mode resonance in 200-µm-diameter cenosphere-derived borosilicate hemispherical shells | 10.1088/0960-1317/23/5/055013 | fulltext_unavailable_from_checked_sources |  |
| W0595 | The concept of "collapsed electrodes" for glassblown spherical resonators demonstrating 200:1 aspect ratio gap definition | 10.1109/isiss.2015.7102382 | fulltext_unavailable_from_checked_sources |  |
| W0596 | Three-Dimensional Spherical Shell Resonator Gyroscope Fabricated Using Wafer-Scale Glassblowing | 10.1109/jmems.2012.2189364 | fulltext_unavailable_from_checked_sources |  |
| W0597 | Microscale Glass-Blown Three-Dimensional Spherical Shell Resonators | 10.1109/jmems.2011.2127453 | fulltext_unavailable_from_checked_sources |  |
| W0598 | 3D-soule: A fabrication process for large scale integration and micromachining of spherical structures | 10.1109/memsys.2011.5734358 | fulltext_unavailable_from_checked_sources |  |
| W0599 | 3-D MICROMACHINED SPHERICAL SHELL RESONATORS WITH INTEGRATED ELECTROMAGNETIC AND ELECTROSTATIC TRANSDUCERS | 10.31438/trf.hh2010.3 | fulltext_unavailable_from_checked_sources |  |
| W0600 | Inertial Navigation Sensors, Charles Stark Draper Lab Inc |  | needs_search_no_verified_identifier |  |
| W0601 | Effect of Geometric and Material Properties on Thermoelastic Damping (TED) of 3D Hemispherical Inertial Resonator | 10.1115/imece2016-66277 | fulltext_unavailable_from_checked_sources |  |
| W0602 | Effect of annealing on mechanical quality factor of fused quartz hemispherical resonator | 10.1109/isiss.2014.6782512 | fulltext_unavailable_from_checked_sources |  |
| W0603 | Hemispherical wineglass resonators fabricated from the microcrystalline diamond | 10.1088/0960-1317/23/12/125016 | fulltext_unavailable_from_checked_sources |  |
| W0604 | A review of analyses related to vibrations of rotating piezoelectric bodies and gyroscopes | 10.1109/tuffc.2005.1503958 | fulltext_unavailable_from_checked_sources |  |
| W0605 | An investigation on thermoelastic damping of high-Q ring resonators | 10.1016/j.ijmecsci.2015.12.023 | fulltext_unavailable_from_checked_sources |  |
| W0606 | Distributed Mass Hemispherical Resonator Gyroscope. (EP 2 463 623 A2), European Patent |  | needs_search_no_verified_identifier |  |
| W0607 | Effects of electrostatic nonlinearity on the rate measuring performance of ring based Coriolis Vibrating Gyroscopes (CVGs) | 10.1016/j.sna.2022.113539 | fulltext_unavailable_from_checked_sources |  |
| W0608 | Hemispherical Resonator Gyro Control. (7,318,347 B2), U.S |  | needs_search_no_verified_identifier |  |
| W0609 | Milli-HRG inertial navigation system | 10.1109/plans.2012.6236860 | fulltext_unavailable_from_checked_sources |  |
| W0610 | Excellent Scale Factor Performance for Whole-Angle Micro-Shell Resonator Gyroscope | 10.1109/mems51670.2022.9699461 | fulltext_unavailable_from_checked_sources |  |
| W0611 | Fused-Silica Micro Birdbath Resonator Gyroscope ($\mu$-BRG) | 10.1109/jmems.2013.2291534 | fulltext_unavailable_from_checked_sources |  |
| W0612 | MEMS-based hemispherical resonator gyroscopes | 10.1109/icsens.2012.6411346 | fulltext_unavailable_from_checked_sources |  |
| W0613 | Adaptable test-bed for characterization of micro-wineglass resonators | 10.1109/memsys.2013.6474280 | fulltext_unavailable_from_checked_sources |  |
| W0614 | Electrostatic and mechanical characterization of 3-D micro-wineglass resonators | 10.1016/j.sna.2014.02.001 | fulltext_unavailable_from_checked_sources |  |
| W0615 | Micro-Glassblowing Paradigm for Realization of Rate Integrating Gyroscopes, Mechanical and Aerospace Engineering Department, University of Claifornia |  | needs_search_no_verified_identifier |  |
| W0616 | Ultra conformal high aspect-ratio small-gap capacitive electrode formation technology for 3D micro shell resonators | 10.1109/memsys.2017.7863623 | fulltext_unavailable_from_checked_sources |  |
| W0617 | Demonstration of 1 Million &lt;inline-formula&gt; &lt;tex-math notation="LaTeX"&gt;$Q$ &lt;/tex-math&gt;&lt;/inline-formula&gt;-Factor on Microglassblown Wineglass Resonators With Out-of-Plane Electrostatic Transduction | 10.1109/jmems.2014.2365113 | fulltext_unavailable_from_checked_sources |  |
| W0618 | Isotropic etching of 111 SCS for wafer-scale manufacturing of perfectly hemispherical silicon molds | 10.1109/transducers.2011.5969536 | fulltext_unavailable_from_checked_sources |  |
| W0619 | Vibration Transmission and Support Loss in MEMS Sensors, University of Nottingham |  | needs_search_no_verified_identifier |  |
| W0620 | Hemispherical resonator gyro technology |  | needs_search_no_verified_identifier |  |
| W0621 | Hemispherical micro-resonators from atomic layer deposition | 10.1088/0960-1317/24/12/125028 | fulltext_unavailable_from_checked_sources |  |
| W0622 | Three-Dimensional Shell Fabrication Using Blow Molding of Bulk Metallic Glass | 10.1109/jmems.2010.2090495 | fulltext_unavailable_from_checked_sources |  |
| W0623 | FUSED SILICA MICRO BIRDBATH SHELL RESONATORS WITH 1.2 MILLION Q AND 43 SECOND DECAY TIME CONSTANT | 10.31438/trf.hh2014.28 | fulltext_unavailable_from_checked_sources |  |
| W0624 | Glass Blowing on a Wafer Level | 10.1109/jmems.2007.892887 | fulltext_unavailable_from_checked_sources |  |
| W0625 | Method and Apparatus for Wafer-Level Micro-Glass-Blowing. (7,694,531), U.S |  | needs_search_no_verified_identifier |  |
| W0626 | Demonstration of sub-1 Hz structural symmetry in micro-glassblown wineglass resonators with integrated electrodes | 10.1109/transducers.2013.6627035 | fulltext_unavailable_from_checked_sources |  |
| W0627 | High temperature micro-glassblowing process demonstrated on fused quartz and ULE TSG | 10.1016/j.sna.2012.11.040 | fulltext_unavailable_from_checked_sources |  |
| W0628 | TITANIA SILICATE / FUSED QUARTZ GLASSBLOWING FOR 3-D FABRICATION OF LOW INTERNAL LOSS WINEGLASS MICRO-STRUCTURES | 10.31438/trf.hh2012.72 | fulltext_unavailable_from_checked_sources |  |
| W0629 | Achieving Sub-Hz Frequency Symmetry in Micro-Glassblown Wineglass Resonators | 10.1109/jmems.2013.2286820 | fulltext_unavailable_from_checked_sources |  |
| W0630 | Study of High Aspect Ratio NLD Plasma Etching and Postprocessing of Fused Silica and Borosilicate Glass | 10.1109/jmems.2015.2442596 | fulltext_unavailable_from_checked_sources |  |
| W0631 | MEMS Micro-glassblowing Paradigm for Wafer-level Fabrication of Fused Silica Wineglass Gyroscopes | 10.1016/j.proeng.2014.11.580 | fulltext_unavailable_from_checked_sources |  |
| W0632 | Out-of-plane electrode architecture for fused silica micro-glassblown 3-D wineglass resonators | 10.1109/icsens.2014.6985170 | fulltext_unavailable_from_checked_sources |  |
| W0633 | Fused Silica Micro Shell Resonator With T-Shape Masses for Gyroscopic Application | 10.1109/jmems.2017.2773563 | fulltext_unavailable_from_checked_sources |  |
| W0634 | Design, fabrication, and characterization of a micromachined glass-blown spherical resonator with insitu integrated silicon electrodes and ALD tungsten interior coating | 10.1109/memsys.2015.7051081 | fulltext_unavailable_from_checked_sources |  |
| W0635 | Fused Quartz Dual Shell Resonator | 10.1109/isiss.2019.8739671 | fulltext_unavailable_from_checked_sources |  |
| W0636 | High-Q fused silica birdbath and hemispherical 3-D resonators made by blow torch molding | 10.1109/memsys.2013.6474206 | fulltext_unavailable_from_checked_sources |  |
| W0637 | A high-Q birdbath resonator gyroscope (BRG) | 10.1109/transducers.2013.6627150 | fulltext_unavailable_from_checked_sources |  |
| W0638 | Simulation of Blowtorch Reflow of Fused Silica Micro-Shell Resonators | 10.1109/jmems.2017.2693291 | fulltext_unavailable_from_checked_sources |  |
| W0639 | Micromachined high-Q fused silica bell resonator with complex profile curvature realized using 3D micro blowtorch molding | 10.1109/transducers.2015.7181172 | fulltext_unavailable_from_checked_sources |  |
| W0640 | 259 Second ring-down time and 4.45 million quality factor in 5.5 kHz fused silica birdbath shell resonator | 10.1109/transducers.2017.7994167 | fulltext_unavailable_from_checked_sources |  |
| W0641 | High-Q Navigation-Grade Fused-Silica Micro Birdbath Resonator Gyroscope | 10.1109/sensors47087.2021.9639559 | fulltext_unavailable_from_checked_sources |  |
| W0642 | Resonant Characteristics of Birdbath Shell Resonator in n =3 Wine-Glass Mode | 10.1109/icsens.2018.8589738 | fulltext_unavailable_from_checked_sources |  |
| W0643 | Anchor Loss in Hemispherical Shell Resonators | 10.1109/jmems.2016.2636080 | fulltext_unavailable_from_checked_sources |  |
| W0644 | A high-q all-fused silica solid-stem wineglass hemispherical resonator formed using micro blow torching and welding | 10.1109/memsys.2015.7051085 | fulltext_unavailable_from_checked_sources |  |
| W0645 | Micro shell resonator with T-shape masses for improving out-of-plane electrostatic transduction efficiency | 10.1109/isiss.2016.7435549 | fulltext_unavailable_from_checked_sources |  |
| W0646 | Investigation on precise frequency trimming of a micro shell resonator with T-shape masses using low-power femtosecond laser ablation | 10.1109/isiss.2018.8358119 | fulltext_unavailable_from_checked_sources |  |
| W0647 | Micro shell resonator with T-shape masses fabricated by improved process using whirling platform and femtosecond laser ablation | 10.1109/isiss.2017.7935654 | fulltext_unavailable_from_checked_sources |  |
| W0648 | Effective mechanical trimming of micro shell resonator with T-shape masses | 10.1109/transducers.2017.7994252 | fulltext_unavailable_from_checked_sources |  |
| W0649 | Decoupling design of stiffness and mass for micro shell resonator with high sensitivity | 10.1109/memsys.2018.8346724 | fulltext_unavailable_from_checked_sources |  |
| W0650 | Micro shell resonator with T-shape masses fabricated by micro blow-torching using whirling platform | 10.1109/transducers.2017.7994441 | fulltext_unavailable_from_checked_sources |  |
| W0651 | Application of micro-blowtorching process with whirling platform for enhancing frequency symmetry of microshell structure | 10.1088/1361-6439/aad730 | fulltext_unavailable_from_checked_sources |  |
| W0652 | Ultrafast laser in fabrication of micro hemispherical resonators with quality factor over millions | 10.1088/1361-6439/abedcc | fulltext_unavailable_from_checked_sources |  |
| W0653 | Design and Fabrication of Micro Hemispheric Shell Resonator with Annular Electrodes | 10.3390/s16121991 | fulltext_unavailable_from_checked_sources |  |
| W0654 | Manufacture of Hemispherical Shell and Surrounding Eave-Shaped Electrodes | 10.3390/mi12070815 | fulltext_unavailable_from_checked_sources |  |
| W0655 | WINEGLASS-ON-A-CHIP | 10.31438/trf.hh2012.74 | fulltext_unavailable_from_checked_sources |  |
| W0656 | A 3D-HARPSS Polysilicon Microhemispherical Shell Resonating Gyroscope: Design, Fabrication, and Characterization | 10.1109/jsen.2015.2431857 | fulltext_unavailable_from_checked_sources |  |
| W0657 | 3-D micromachined hemispherical shell resonators with integrated capacitive transducers | 10.1109/memsys.2012.6170120 | fulltext_unavailable_from_checked_sources |  |
| W0658 | Invar-36 Micro Hemispherical Shell Resonators | 10.1109/memsys.2014.6765568 | fulltext_unavailable_from_checked_sources |  |
| W0659 | Microscale three-dimensional hemispherical shell resonators fabricated from metallic glass | 10.1109/isiss.2014.6782500 | fulltext_unavailable_from_checked_sources |  |
| W0660 | High Q diamond hemispherical resonators: fabrication and energy loss mechanisms | 10.1088/0960-1317/25/8/085006 | fulltext_unavailable_from_checked_sources |  |
| W0661 | A MEMS diamond hemispherical resonator | 10.1088/0960-1317/23/12/125007 | fulltext_unavailable_from_checked_sources |  |
| W0662 | Fabrication and characterisation of microscale hemispherical shell resonator with diamond electrodes on the Si substrate | 10.1049/mnl.2018.5601 | fulltext_unavailable_from_checked_sources |  |
| W0663 | Micromachined polycrystalline diamond hemispherical shell resonators | 10.1109/transducers.2013.6627293 | fulltext_unavailable_from_checked_sources |  |
| W0664 | Micromachining 3D hemispherical features in silicon via micro-EDM | 10.1109/memsys.2012.6170151 | fulltext_unavailable_from_checked_sources |  |
| W0665 | A study on the optimal fabrication method for micro-scale gyroscopes using a hybrid process consisting of electric discharge machining, chemical etching or micro-mechanical milling | 10.1016/j.cirp.2013.03.035 | fulltext_unavailable_from_checked_sources |  |
| W0666 | A batch-mode micromachining process for spherical structures | 10.1088/0960-1317/24/2/025002 | fulltext_unavailable_from_checked_sources |  |
| W0667 | GOBLIT: A GIANT OPTO-MECHANICAL BULK-MACHINED LIGHT TRANSDUCER | 10.31438/trf.hh2014.66 | fulltext_unavailable_from_checked_sources |  |
| W0668 | Enhancing the closed-loop stability of a high-Q polysilicon micro-hemispherical resonating gyroscope | 10.1063/1.5045360 | fulltext_unavailable_from_checked_sources |  |
| W0669 | Micromachined silicon hemispherical resonators with self-aligned spherical capacitive electrodes | 10.1109/icsens.2015.7370238 | fulltext_unavailable_from_checked_sources |  |
| W0670 | Bandwidth Expansion for Force-to-Rebalance Measurement of MEMS Gyroscopes Based on Equivalent Unit Negative Feedback Loop | 10.1109/tmech.2024.3519588 | fulltext_unavailable_from_checked_sources |  |
| W0671 | A digital force-to-rebalance scheme for high-frequency bulk-acoustic-wave micro-gyroscopes | 10.1016/j.sna.2020.112181 | fulltext_unavailable_from_checked_sources |  |
| W0672 | Three-Axis Attitude Estimation Using Rate-Integrating Gyroscopes | 10.2514/1.g000336 | fulltext_unavailable_from_checked_sources |  |
| W0673 | Research of Frequency Splitting Caused by Uneven Mass of Micro-Hemispherical Resonator Gyro | 10.3390/mi13112015 | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R0879_Micromachines 13_11__ _2022_.pdf |
| W0674 | A Novel Self-Modulation Method for Whole-Angle Resonator Gyroscope Based on High Harmonic Compensation | 10.1109/jsen.2024.3442207 | fulltext_unavailable_from_checked_sources |  |
| W0675 | Analysis and Optimization Method of the Vibration Rectification Error of a Pendulous Accelerometer | 10.1109/jsen.2021.3097585 | fulltext_unavailable_from_checked_sources |  |
| W0676 | Reduced order modelling and experimental validation of a MEMS gyroscope test-structure exhibiting 1:2 internal resonance | 10.1038/s41598-021-95793-y | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R0882_Gobat_ G._ Zega_ V._ Fedeli_ P._ Guerinoni_ L._ Touzé_ C._ Frangi_ A._ Reduced order modelling and experimental val.pdf |
| W0677 | Design and Modelling of MEMS Vibrating Internal Ring Gyroscopes for Harsh Environments | 10.3390/s24175854 | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R0883_Sensors 24_17__ 5854 _2024_.pdf |
| W0678 | MEMS gyroscope bias drift cancellation using continuous-time mode reversal | 10.1109/transducers.2013.6627152 | fulltext_unavailable_from_checked_sources |  |
| W0679 | In-Run Mode-Matching of MEMS Gyroscopes Based on Power Symmetry of Readout Signal in Sense Mode | 10.1109/jsen.2021.3112915 | fulltext_unavailable_from_checked_sources |  |
| W0680 | Modeling and Analysis of a MEMS Vibrating Ring Gyroscope Subject to Imperfections | 10.1109/jmems.2022.3170121 | fulltext_unavailable_from_checked_sources |  |
| W0681 | Online Calibration of the Virtual Rotation Rate for Whole-Angle Hemispherical Resonator Gyroscopes Based on a Dual-Gyro Configuration | 10.1109/jsen.2025.3595162 | fulltext_unavailable_from_checked_sources |  |
| W0682 | Lynch, D. D.: Vibration-induced drift in the hemispherical resonator gyro. In: Proceedings of the 43rd Annual Meeting of The Institute of Navigation (1987), pp. 34–37, (1987) |  | needs_search_no_verified_identifier |  |
| W0683 | Courier Corporation, (1956) |  | needs_search_no_verified_identifier |  |
| W0684 | Murray, H.: Protter and Charles B, 2nd edn. Morrey. A first course in real analysis. Springer, New York (1970) |  | needs_search_no_verified_identifier |  |
| W0685 | MEMS gyroscopes in different operation modes: A review | 10.1016/j.measurement.2025.116996 | fulltext_unavailable_from_checked_sources |  |
| W0686 | mHRG: miniature CVG with beyond navigation grade performance and real time self-calibration |  | needs_search_no_verified_identifier |  |
| W0687 | HRG by sagem from laboratory to mass production |  | needs_search_no_verified_identifier |  |
| W0688 | PRIMUS: SWAP-oriented IMUs for multiple applications |  | needs_search_no_verified_identifier |  |
| W0689 | Self-excitation enabled decoupling, calibration, and compensation of errors for whole-angle hemispherical resonator gyroscope |  | needs_search_no_verified_identifier |  |
| W0690 | Single propeller airplane minimal flight speed based upon the lateral maneuver condition | 10.1016/j.ast.2015.12.012 | fulltext_unavailable_from_checked_sources |  |
| W0691 | Power optimization of a single propeller airplane take-off run on the basis of lateral maneuver limitations | 10.1016/j.ast.2017.10.015 | fulltext_unavailable_from_checked_sources |  |
| W0692 | Minimal safe speed of the asymmetrically loaded combat airplane | 10.1108/aeat-03-2014-0033 | fulltext_unavailable_from_checked_sources |  |
| W0693 | New General Approach to Airplane Rotation Analysis | 10.2322/tjsass.53.130 | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R0901_New general approach to airplane rotation analysis.pdf |
| W0694 | Modeling, characterization, and compensation of detection and actuation coupling errors for whole-angle micro hemispherical resonant gyroscope |  | needs_search_no_verified_identifier |  |
| W0695 | Identification and calibration of the detection signal distortion in whole angle mode hemispherical resonator gyro |  | needs_search_no_verified_identifier |  |
| W0696 | A Real-Time Automatic Mode-Matching Method Based on Phase-Shifted Virtual Coriolis Force for MEMS Disk Resonator Gyroscope | 10.1109/jsen.2023.3326078 | fulltext_unavailable_from_checked_sources |  |
| W0697 | Milli-Hertz Frequency Tuning Architecture Toward High Repeatable Micromachined Axi-Symmetry Gyroscopes | 10.1109/tie.2022.3192672 | fulltext_unavailable_from_checked_sources |  |
| W0698 | Review on piezoelectric actuators: materials, classifications, applications, and recent trends | 10.1007/s11465-023-0772-0 | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R0910_Review on piezoelectric actuators_ materials_ classifications_ applications_ and recent trends.pdf |
| W0699 | Virtual Rate-Table Method for Characterization of Microgyroscopes | 10.1109/jsen.2012.2185489 | fulltext_unavailable_from_checked_sources |  |
| W0700 | A novel scale factor calibration method for a MEMS gyroscope based on virtual coriolis force | 10.1109/nems.2015.7147373 | fulltext_unavailable_from_checked_sources |  |
| W0701 | Virtually rotated MEMS gyroscope with angle output | 10.1109/memsys.2017.7863406 | fulltext_unavailable_from_checked_sources |  |
| W0702 | ON-LINE PHYSICAL PARAMETER ESTIMATION WITH ADAPTIVE FORGETTING FACTORS | 10.1006/mssp.2000.1322 | fulltext_unavailable_from_checked_sources |  |
| W0703 | Adaptive Kalman filters for nonlinear finite element model updating | 10.1016/j.ymssp.2020.106837 | fulltext_unavailable_from_checked_sources |  |
| W0704 | A new approach to introducing a forgetting factor into the normalized least mean squares algorithm | 10.1016/j.sigpro.2015.02.012 | fulltext_unavailable_from_checked_sources |  |
| W0705 | A time-varying forgetting factor stochastic gradient combined with Kalman filter algorithm for parameter identification of dynamic systems | 10.1007/s11071-014-1540-9 | fulltext_unavailable_from_checked_sources |  |
| W0706 | Fully Differential Single Resonator FM Gyroscope Using CW/CCW Mode Separator | 10.1109/jmems.2018.2874060 | fulltext_unavailable_from_checked_sources |  |
| W0707 | An accurate thermoelastic model and thermal output error analysis of a hemispherical resonator gyroscope under varying temperatures | 10.1016/j.ymssp.2021.108760 | fulltext_unavailable_from_checked_sources |  |
| W0708 | Research on testing method of rate-integrating hemispherical resonantor gyroscope |  | needs_search_no_verified_identifier |  |
| W0709 | A Novel Model for Fully Closed-Loop System of Hemispherical Resonator Gyroscope Under Force-to-Rebalance Mode | 10.1109/tim.2020.3005282 | fulltext_unavailable_from_checked_sources |  |
| W0710 | Asynchronous Tracking Control of Amplitude Signals in Vibratory Gyroscopes With Partially Unknown Mode Information | 10.1109/tie.2022.3201293 | fulltext_unavailable_from_checked_sources |  |
| W0711 | High Precision Mass Balancing Method for the Fourth Harmonic Mass Defect of Fused Quartz Hemispherical Resonator Based on Ion Beam Etching Process |  | needs_search_no_verified_identifier |  |
| W0712 | Dynamic modeling and output error analysis of an imperfect hemispherical shell resonator | 10.1016/j.jsv.2021.115964 | fulltext_unavailable_from_checked_sources |  |
| W0713 | Dissipation in nanoelectromechanical systems | 10.1016/j.physrep.2013.09.003 | fulltext_unavailable_from_checked_sources |  |
| W0714 | Silica Glass for High-Q Mechanical Resonators | 10.1134/s0020168520030103 | fulltext_unavailable_from_checked_sources |  |
| W0715 | Anchor Loss Reduction for Square-Extensional Mode MEMS Resonator Using Tethers With Auxiliary Structures | 10.1109/jsen.2023.3282409 | fulltext_unavailable_from_checked_sources |  |
| W0716 | Anchor loss improvement in hemispherical resonators with ion beams | 10.1016/j.ijmecsci.2024.109413 | fulltext_unavailable_from_checked_sources |  |
| W0717 | Identification and trimming of the eccentric mass in shell resonators | 10.1016/j.ijmecsci.2024.109504 | fulltext_unavailable_from_checked_sources |  |
| W0718 | Bulk and Surface Thermoelastic Dissipation in Micro-Hemispherical Shell Resonators | 10.1109/jmems.2014.2333528 | fulltext_unavailable_from_checked_sources |  |
| W0719 | Thermoelastic Damping Based Design, Sensitivity Study and Demonstration of a Functional Hybrid Gyroscope Resonator for High Quality Factor | 10.1134/s2075108721010107 | fulltext_unavailable_from_checked_sources |  |
| W0720 | Mitigating Thermoelastic Dissipation of Flexural Micromechanical Resonators by Decoupling Resonant Frequency from Thermal Relaxation Rate | 10.1103/physrevapplied.8.064033 | fulltext_unavailable_from_checked_sources |  |
| W0721 | Characterization of the thermal quality factor of two-temperature micro-viscothermoelastic resonator due to static-pre-stress based on dual-phase-lagging heat conduction | 10.1016/j.aej.2020.06.047 | fulltext_unavailable_from_checked_sources |  |
| W0722 | Effect of surface energy on nano-resonator dynamic behavior | 10.1016/j.ijmecsci.2016.09.031 | fulltext_unavailable_from_checked_sources |  |
| W0723 | Fundamental investigation of subsurface damage on the quality factor of hemispherical fused silica shell resonator | 10.1016/j.sna.2022.113365 | fulltext_unavailable_from_checked_sources |  |
| W0724 | Surface evolution of fused silica hemispherical resonators and its influence on the quality factor | 10.1016/j.sna.2023.114456 | fulltext_unavailable_from_checked_sources |  |
| W0725 | Subsurface damage detection and prediction of thin-walled complex curved-surface component | 10.1016/j.ijmecsci.2024.109165 | fulltext_unavailable_from_checked_sources |  |
| W0726 | Hemispherical resonator with low subsurface damage machined by small ball-end fine diamond grinding wheel: A novel grinding technique | 10.1016/j.cja.2023.08.022 | fulltext_unavailable_from_checked_sources |  |
| W0727 | A novel method of water bath heating assisted small ball-end magnetorheological polishing for hemispherical shell resonators | 10.1016/j.cja.2023.05.003 | fulltext_unavailable_from_checked_sources |  |
| W0728 | Interference and grinding characteristics in ultra-precision grinding of thin-walled complex structural component using a ball-end grinding wheel | 10.1016/j.cja.2020.08.010 | fulltext_unavailable_from_checked_sources |  |
| W0729 | Design and fabrication of a novel magnetorheological finishing process for small concave surfaces using small ball-end permanent-magnet polishing head | 10.1007/s00170-015-7573-5 | fulltext_unavailable_from_checked_sources |  |
| W0730 | Cracking behavior during scratching brittle materials with different-shaped indenters | 10.1016/j.ijmecsci.2024.109041 | fulltext_unavailable_from_checked_sources |  |
| W0731 | Subsurface damage model in single and double scratching of fused silica with a blunt indenter | 10.1016/j.ijmecsci.2023.108309 | fulltext_unavailable_from_checked_sources |  |
| W0732 | A micromechanical model of a hard interface with micro-cracking damage | 10.1016/j.ijmecsci.2021.106974 | fulltext_unavailable_from_checked_sources |  |
| W0733 | Theoretical and experimental investigation on surface generation and subsurface damage in fixed abrasive lapping of optical glass | 10.1016/j.ijmecsci.2021.106941 | fulltext_unavailable_from_checked_sources |  |
| W0734 | Controlled material removal mode and depth of micro cracks in precision grinding of fused silica – A theoretical model and experimental verification | 10.1016/j.ceramint.2017.05.327 | fulltext_unavailable_from_checked_sources |  |
| W0735 | Study on removal mechanism and removal characters for SiC and fused silica by fixed abrasive diamond pellets | 10.1016/j.ijmachtools.2014.04.008 | fulltext_unavailable_from_checked_sources |  |
| W0736 | Morphology and distribution of subsurface damage in optical fused silica parts: Bound-abrasive grinding | 10.1016/j.apsusc.2010.09.051 | fulltext_unavailable_from_checked_sources |  |
| W0737 | Evolution and removal of surface scratches on fused silica under magnetorheological finishing | 10.1117/1.oe.58.5.055102 | fulltext_unavailable_from_checked_sources |  |
| W0738 | Hardness, Toughness, and Brittleness: An Indentation Analysis | 10.1111/j.1151-2916.1979.tb19075.x | fulltext_unavailable_from_checked_sources |  |
| W0739 | A model for crack initiation in elastic/plastic indentation fields | 10.1007/bf00552240 | fulltext_unavailable_from_checked_sources |  |
| W0740 | Brittleness as an indentation size effect | 10.1007/bf00540940 | fulltext_unavailable_from_checked_sources |  |
| W0741 | Towards understanding the brittle–ductile transition in the extreme manufacturing | 10.1088/2631-7990/abdfd7 | fulltext_unavailable_from_checked_sources |  |
| W0742 | Monitoring of ductile–brittle transition mechanisms in sapphire ultra-precision grinding used small grit size grinding wheel through force and acoustic emission signals | 10.1016/j.measurement.2023.112557 | fulltext_unavailable_from_checked_sources |  |
| W0743 | Grinding and Lapping Induced Surface Integrity of Silicon Wafers and its Effect on Chemical Mechanical Polishing | 10.2139/ssrn.4088086 | fulltext_unavailable_from_checked_sources |  |
| W0744 | Towards understanding the crack suppression mechanism in brittle materials with high grinding speed at different temperatures | 10.1016/j.ijmachtools.2023.104088 | fulltext_unavailable_from_checked_sources |  |
| W0745 | Crack propagation and induced vibration characteristics of cracked cantilever plates under resonance state: Experiment and simulation | 10.1016/j.ymssp.2023.110674 | fulltext_unavailable_from_checked_sources |  |
| W0746 | Influences of inclined crack defects on vibration characteristics of cylindrical roller bearings | 10.1016/j.ymssp.2023.110945 | fulltext_unavailable_from_checked_sources |  |
| W0747 | The mechanisms of energy dissipation in the non-propagating fatigue cracks in metallic materials | 10.1016/j.engfracmech.2004.02.003 | fulltext_unavailable_from_checked_sources |  |
| W0748 | Effect of micro-cracks on mechanical and damping properties of double-layered Al/Al plate | 10.1080/02670836.2022.2043061 | fulltext_unavailable_from_checked_sources |  |
| W0749 | Damping associated with porosity and crack in solids | 10.1016/s0167-8442(00)00038-0 | fulltext_unavailable_from_checked_sources |  |
| W0750 | Energy dissipation caused by fatigue crack in beam-like cracked structures | 10.1016/j.jsv.2015.10.036 | fulltext_unavailable_from_checked_sources |  |
| W0751 | Considerations regarding superharmonic vibrations of a cracked beam and the variation in damping caused by the presence of the crack | 10.1016/j.jsv.2005.01.038 | fulltext_unavailable_from_checked_sources |  |
| W0752 | Effect of a breathing crack on the damping changes in nonlinear vibrations of a cracked beam: Experimental and theoretical investigations | 10.1177/1077546320960312 | fulltext_unavailable_from_checked_sources |  |
| W0753 | Effects of laser-assisted grinding on surface integrity of zirconia ceramic | 10.1016/j.ceramint.2019.09.051 | fulltext_unavailable_from_checked_sources |  |
| W0754 | Grinding and lapping induced surface integrity of silicon wafers and its effect on chemical mechanical polishing | 10.1016/j.apsusc.2022.153982 | fulltext_unavailable_from_checked_sources |  |
| W0755 | Study on subsurface damage behavior in ductile ultra-precision grinding of sapphire based on acoustic emission signal processing | 10.1016/j.jmapro.2023.11.046 | fulltext_unavailable_from_checked_sources |  |
| W0756 | Experimental study on the mechanism of strain rate on grinding damage of zirconia ceramics | 10.1016/j.ceramint.2022.04.142 | fulltext_unavailable_from_checked_sources |  |
| W0757 | Ductile deformation and subsurface damage evolution mechanism of silicon wafer induced by ultra-precision grinding process | 10.1016/j.triboint.2023.108879 | fulltext_unavailable_from_checked_sources |  |
| W0758 | Unveiling sub-bandgap energy-level structures on machined optical surfaces based on weak photo-luminescence | 10.1039/d3nr03488g | fulltext_unavailable_from_checked_sources |  |
| W0759 | The formation of microcrystalline defects on the surface of silica glass arising from mechanochemical processing | 10.1111/ijag.16558 | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R0971_The formation of microcrystalline defects on the surface of silica glass arising from mechanochemical processing.pdf |
| W0760 | Etching behavior of ground fused silica and light enhancement modulated by surface/subsurface cracks | 10.1111/ijag.16563 | fulltext_unavailable_from_checked_sources |  |
| W0761 | Subsurface damage distribution and processing method of ground fused silica | 10.1117/12.2284768 | fulltext_unavailable_from_checked_sources |  |
| W0762 | Indentation fracture: principles and applications | 10.1007/bf00823224 | fulltext_unavailable_from_checked_sources |  |
| W0763 | Elastic/Plastic Indentation Damage in Ceramics: The Lateral Crack System | 10.1111/j.1151-2916.1982.tb10782.x | fulltext_unavailable_from_checked_sources |  |
| W0764 | Investigation of subsurface damage considering the abrasive particle rotation in brittle material grinding | 10.1007/s00170-016-9567-3 | fulltext_unavailable_from_checked_sources |  |
| W0765 | Evaluation of subsurface crack depth during scratch test for optical glass BK7 | 10.1177/0954406211412458 | fulltext_unavailable_from_checked_sources |  |
| W0766 | Investigation of grinding modes in horizontal surface grinding of optical glass BK7 | 10.1016/j.jmatprotec.2011.05.006 | fulltext_unavailable_from_checked_sources |  |
| W0767 | Evaluation of surface and subsurface cracks on nano-scale machined brittle materials by scanning force microscope and scanning laser microscope | 10.1016/s0257-8972(03)00133-6 | fulltext_unavailable_from_checked_sources |  |
| W0768 | Ductile-Regime Grinding: A New Technology for Machining Brittle Materials | 10.1115/1.2899676 | fulltext_unavailable_from_checked_sources |  |
| W0769 | 2013 |  | needs_search_no_verified_identifier |  |
| W0770 | PRINCIPLES OF ABRASIVE PROCESSING | 10.1080/10940349808945664 | fulltext_unavailable_from_checked_sources |  |
| W0771 | A micromechanical model on specific damping capacity caused by micro cracks | 10.21595/jve.2015.15501 | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R0983_A micromechanical model on specific damping capacity caused by micro cracks.pdf |
| W0772 | Defects identification and mass trimming in hemispherical resonators | 10.1016/j.ijmecsci.2025.110242 | fulltext_unavailable_from_checked_sources |  |
| W0773 | Q-factor enhancement in micro hemispherical resonators by laser welding | 10.1016/j.ijmecsci.2025.110853 | fulltext_unavailable_from_checked_sources |  |
| W0774 | HRG Crystal™ dual core: rebooting the INS revolution |  | needs_search_no_verified_identifier |  |
| W0775 | Recent Advances in MEMS-Based 3D Hemispherical Resonator Gyroscope (HRG)—A Sensor of Choice | 10.3390/mi13101676 | existing_local | D:/学习资料/资料/全角陀螺/引用文献_20261023/seed_replacements/L062_2022_Recent_Advances_MEMS_3D_HRG_verified.pdf |
| W0776 | Identifying vibration characteristics of hemispherical resonators with mass defects | 10.1016/j.ijmecsci.2025.110856 | fulltext_unavailable_from_checked_sources |  |
| W0777 | Review on the current advances, key technology and future trends of hemispherical resonator gyroscope |  | needs_search_no_verified_identifier |  |
| W0778 | Linear calibration models for mass defects of hemispherical resonator | 10.1016/j.ijmecsci.2025.110644 | fulltext_unavailable_from_checked_sources |  |
| W0779 | An Efficient System-Level Calibration Method for a High-Precision RLG RINS Considering the G-Sensitive Misalignment | 10.1109/tie.2024.3395797 | fulltext_unavailable_from_checked_sources |  |
| W0780 | A bias compensation method for ring laser gyroscopes based on gaussian process regression and distributed temperature measurement configuration |  | needs_search_no_verified_identifier |  |
| W0781 | Sensitivity enhancement based on suppressing RIN induced by harmonic components in fiber-optic gyroscopes | 10.1016/j.sna.2025.116839 | fulltext_unavailable_from_checked_sources |  |
| W0782 | The Influence and Suppression of Spectral Width on Scale Factor Nonlinearity in Fiber Optic Gyroscopes With Broadband Sources | 10.1109/jlt.2024.3511668 | fulltext_unavailable_from_checked_sources |  |
| W0783 | The Influence of Nonlinear High-Intensity Dynamic Processes on the Standing Wave Precession of a Non-Ideal Hemispherical Resonator | 10.3390/s24092709 | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R0997_The influence of nonlinear high-intensity dynamic processes on the standing wave precession of a non-ideal hemisphe.pdf |
| W0784 | The Effect of Stem on the Bryan's Factor of a Hemispherical Resonator | 10.1016/j.jsv.2022.117249 | fulltext_unavailable_from_checked_sources |  |
| W0785 | Trimming of the unbalanced mass in resonators with ion beams | 10.1016/j.ijmecsci.2025.110581 | fulltext_unavailable_from_checked_sources |  |
| W0786 | RETRACTED: Fillet effects on hemispherical shell resonators: Analytical insights for enhanced structural integrity | 10.1016/j.tws.2025.112965 | fulltext_unavailable_from_checked_sources |  |
| W0787 | A Wafer-Level Vacuum Packaged MEMS Disk Resonator Gyroscope With 0.42°/h Bias Instability Within ±300°/s Full Scale | 10.1109/tie.2021.3078375 | fulltext_unavailable_from_checked_sources |  |
| W0788 | 0.003°/h bias instability of honeycomb disk resonator gyroscope achieved by mode reversal combined mode deflection control method | 10.1038/s41378-025-01011-4 | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R1002_0.003__h bias instability of honeycomb disk resonator gyroscope achieved by mode reversal combined mode deflection.pdf |
| W0789 | Multifrequency Modulation Techniques to Suppress Coupling Between Excitation and Sense Electrodes in MEMS Disk Resonant Gyroscopes | 10.1109/tim.2025.3643062 | fulltext_unavailable_from_checked_sources |  |
| W0790 | Approximation method for frequency split calculation of coriolis vibrating gyroscope resonator | 10.1016/j.jsv.2021.116733 | fulltext_unavailable_from_checked_sources |  |
| W0791 | Calibration of Coupling Errors for Scale Factor Nonlinearity Improvement in Navigation-Grade Honeycomb Disk Resonator Gyroscope | 10.1109/tie.2022.3187598 | fulltext_unavailable_from_checked_sources |  |
| W0792 | Negating self-induced parametric excitation in capacitive ring-based MEMS Coriolis vibrating gyroscopes | 10.1016/j.jsv.2025.119016 | fulltext_unavailable_from_checked_sources |  |
| W0793 | Virtual precession-enabled phase error mitigation in high-precision hemispherical resonator gyroscopes | 10.1016/j.sna.2025.116976 | fulltext_unavailable_from_checked_sources |  |
| W0794 | Identification and Calibration of the Detection Signal Distortion in Whole Angle Mode Hemispherical Resonator Gyro | 10.1109/tim.2024.3451567 | fulltext_unavailable_from_checked_sources |  |
| W0795 | Bryan's effect and isotropic nonlinear damping | 10.1016/j.jsv.2013.06.032 | fulltext_unavailable_from_checked_sources |  |
| W0796 | Bryan's effect and anisotropic nonlinear damping | 10.1016/j.jsv.2017.11.043 | fulltext_unavailable_from_checked_sources |  |
| W0797 | Bryan's Factor for Truncated Spherical and Conical Shells | 10.1115/1.4026674 | fulltext_unavailable_from_checked_sources |  |
| W0798 | Low-Damage Trimming of Micro Hemispherical Resonators by Chemical Etching | 10.3390/mi15091094 | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R1012_Low-damage trimming of micro hemispherical resonators by chemical etching.pdf |
| W0799 | Dynamic Modeling and Coupling Error Analysis of Imperfect Hemispherical Resonators | 10.1109/jsen.2025.3572899 | fulltext_unavailable_from_checked_sources |  |
| W0800 | A novel method to characterize the residual stress on the fused silica surface based on the evolution of the atomic point defects | 10.1016/j.apsusc.2023.158323 | fulltext_unavailable_from_checked_sources |  |
| W0801 | Effect of residual stress on modes of coupled MEMS resonator array | 10.1109/3m-nano49087.2021.9599771 | fulltext_unavailable_from_checked_sources |  |
| W0802 | Mechanical modeling and frequency splitting mechanism analysis of variable density hemispherical resonators | 10.1016/j.sna.2025.116390 | fulltext_unavailable_from_checked_sources |  |
| W0803 | Stiffness Tuning of Hemispherical Shell Resonator Based on Electrostatic Force Applied to Discrete Electrodes | 10.1109/tim.2024.3428603 | fulltext_unavailable_from_checked_sources |  |
| W0804 | The influence of photothermal effect on the resonance frequency of fused silica micro hemispherical resonator | 10.1088/1361-6501/acfd4a | fulltext_unavailable_from_checked_sources |  |
| W0805 | Frequency trimming of a vibrating ring-based multi-axis rate sensor | 10.1016/j.jsv.2003.12.032 | fulltext_unavailable_from_checked_sources |  |
| W0806 | Trimming of imperfect hemispherical shell including point mass distributions | 10.1016/j.ijmecsci.2017.08.021 | fulltext_unavailable_from_checked_sources |  |
| W0807 | A simple theory for the analysis and correction of frequency splitting in slightly imperfect rings | 10.1016/0022-460x(90)90554-d | fulltext_unavailable_from_checked_sources |  |
| W0808 | Mode trimming in nominally axisymmetric structures |  | needs_search_no_verified_identifier |  |
| W0809 | Localized Eutectic Trimming of Polysilicon Microhemispherical Resonating Gyroscopes | 10.1109/jsen.2014.2344851 | fulltext_unavailable_from_checked_sources |  |
| W0810 | Influence of nonuniform thickness of hemispherical resonator gyro shell on its unbalance parameters | 10.1134/s207510871702002x | fulltext_unavailable_from_checked_sources |  |
| W0811 | Investigation on Influence of Geometric Error and Structure on Vibrational Characteristics of Hemispherical Resonator | 10.23919/icins51816.2023.10168403 | fulltext_unavailable_from_checked_sources |  |
| W0812 | High rise of ring resonator frequency split due to combination of two harmonics of density defect | 10.1016/j.apm.2021.10.038 | fulltext_unavailable_from_checked_sources |  |
| W0813 | Application of conductive graphene films for high-performance hemispherical resonator gyroscopes |  | needs_search_no_verified_identifier |  |
| W0814 | Metal-Film-Free Electrostatic Excitation and Detection Scheme for Maximizing the <i>Q</i> Factor of Quartz Resonators | 10.1109/tim.2025.3585205 | fulltext_unavailable_from_checked_sources |  |
| W0815 | A fusion algorithm for HRG output errors based on improved support function and MDTW | 10.1016/j.measurement.2024.114300 | fulltext_unavailable_from_checked_sources |  |
| W0816 | Compensation of frequency split by directional lapping in fused quartz micro wineglass resonators | 10.1088/1361-6439/aac221 | fulltext_unavailable_from_checked_sources |  |
| W0817 | Frequency split reduction by directional lapping of fused quartz micro wineglass resonators | 10.1109/isiss.2017.7935685 | fulltext_unavailable_from_checked_sources |  |
| W0818 | Solid-state wave gyroscope ensuring the required accuracy parameters | 10.23919/icins.2018.8405893 | fulltext_unavailable_from_checked_sources |  |
| W0819 | Frequency tuning of fused silica cylindrical resonators by chemical etching | 10.1109/iss46986.2019.8943661 | fulltext_unavailable_from_checked_sources |  |
| W0820 | Point-trimming method of hemispherical resonator gyroscope based on ultrafast laser technology |  | needs_search_no_verified_identifier |  |
| W0821 | Frequency Tuning Method on Teeth-Like Tines of the Fused Silica Micro-Hemispherical Resonator Using Femtosecond Laser | 10.1109/jmems.2023.3332669 | fulltext_unavailable_from_checked_sources |  |
| W0822 | Precise Dynamic Mass-Stiffness Balancing of Cylindrical Shell Vibrating Gyroscope Along Working Modal Axis | 10.1109/jsen.2019.2932761 | fulltext_unavailable_from_checked_sources |  |
| W0823 | Study on the relationship between motion accuracy and optical surface accuracy of ion beam figuring equipment | 10.1117/12.2604878 | fulltext_unavailable_from_checked_sources |  |
| W0824 | The High-Precision Balance Method for Hemispherical Resonator Based on Synchronous Trimming System | 10.1109/jsen.2023.3297211 | fulltext_unavailable_from_checked_sources |  |
| W0825 | Ultra-precision surface finishing by ion beam and plasma jet techniques—status and outlook | 10.1016/j.nima.2009.11.013 | fulltext_unavailable_from_checked_sources |  |
| W0826 | A Simple Acoustic Method for Modal Parameter Measurement of the Resonator for Vibratory Shell Gyroscope | 10.1109/jsen.2014.2332879 | fulltext_unavailable_from_checked_sources |  |
| W0827 | A high-Q all-fused silica solid-stem wineglass hemispherical resonator formed using micro blow torching and welding |  | needs_search_no_verified_identifier |  |
| W0828 | Residual stress and distortion in fusion welding and fusion-based additive manufacturing: measurements, mechanisms and control strategies | 10.1016/j.pmatsci.2025.101651 | fulltext_unavailable_from_checked_sources |  |
| W0829 | Evaluation of the residual stresses in 95wt%Al2O3-5wt% SiC wear protection coating using X-Ray diffraction technique | 10.1088/1757-899x/311/1/012016 | fulltext_unavailable_from_checked_sources |  |
| W0830 | Research progress of residual stress measurement methods | 10.1016/j.heliyon.2024.e28348 | fulltext_unavailable_from_checked_sources |  |
| W0831 | Synchrotron X-ray and neutron diffraction study on the deformation and phase transformation mechanisms in TiAl alloys: a review | 10.20517/microstructures.2025.54 | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R1045_Synchrotron X-ray and neutron diffraction study on the deformation and phase transformation mechanisms in TiAl allo.pdf |
| W0832 | Overview and applicability of residual stress estimation of film–substrate structure | 10.1016/j.tsf.2011.04.220 | fulltext_unavailable_from_checked_sources |  |
| W0833 | Modeling of creep deformation and its effect on stress distribution in multilayer systems under residual stress and external bending | 10.1016/j.tsf.2008.12.022 | fulltext_unavailable_from_checked_sources |  |
| W0834 | Extension of the Stoney formula for film–substrate systems with gradient stress for MEMS applications | 10.1088/0960-1317/16/2/024 | fulltext_unavailable_from_checked_sources |  |
| W0835 | Residual stresses in thin film systems: Effects of lattice mismatch, thermal mismatch and interface dislocations | 10.1016/j.ijsolstr.2013.06.022 | fulltext_unavailable_from_checked_sources |  |
| W0836 | A Theoretical Analysis for Arbitrary Residual Stress of Thin Film/Substrate System With Nonnegligible Film Thickness | 10.1115/1.4064207 | fulltext_unavailable_from_checked_sources |  |
| W0837 | Analytical solutions of film/substrate structure with film bending under elastic boundary and bifurcation deformation analysis | 10.1016/j.euromechsol.2024.105538 | fulltext_unavailable_from_checked_sources |  |
| W0838 | Dynamic modulation of modal coupling in microelectromechanical gyroscopic ring resonators | 10.1038/s41467-019-12796-0 | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R1052_Dynamic modulation of modal coupling in microelectromechanical gyroscopic ring resonators.pdf |
| W0839 | HRG Crystal<sup>™</sup> DUAL CORE: Rebooting the INS revolution | 10.1109/iss46986.2019.8943660 | fulltext_unavailable_from_checked_sources |  |
| W0840 | Lynch. 1998 |  | needs_search_no_verified_identifier |  |
| W0841 | Calibration of coupling errors for scale factor nonlinearity improvement in navigation-grade honeycomb disk resonator gyroscope |  | needs_search_no_verified_identifier |  |
| W0842 | Nonlinear damping in mechanical resonators made from carbon nanotubes and graphene | 10.1038/nnano.2011.71 | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R1059_Nonlinear damping in mechanical resonators made from carbon nanotubes and graphene.pdf |
| W0843 | Nonlinear Limits for Single-Crystal Silicon Microresonators | 10.1109/jmems.2004.835771 | fulltext_unavailable_from_checked_sources |  |
| W0844 | Nonlinear damping in a micromechanical oscillator | 10.1007/s11071-011-0031-5 | fulltext_unavailable_from_checked_sources |  |
| W0845 | P.P. Udalov, A.V. Lukin, I.A. Popov, N.V. Mozhgova, Nonlinear dynamics of a hemispherical resonator of a rate-integrating gyroscope under parametric excitation of the free precession mode, 2022, 11 |  | needs_search_no_verified_identifier |  |
| W0846 | Stable Operation of MEMS Oscillators Far Above the Critical Vibration Amplitude in the Nonlinear Regime | 10.1109/jmems.2011.2170821 | fulltext_unavailable_from_checked_sources |  |
| W0847 | Operation of a high quality-factor gyroscope in electromechanical nonlinearities regime | 10.1088/1361-6439/aa73af | fulltext_unavailable_from_checked_sources |  |
| W0848 | Nonlinearity tuning and its effects on the performance of a MEMS gyroscope | 10.1109/transducers.2015.7181127 | fulltext_unavailable_from_checked_sources |  |
| W0849 | System-level circuit simulation of nonlinearity in micromechanical resonators | 10.1016/j.sna.2011.12.008 | fulltext_unavailable_from_checked_sources |  |
| W0850 | Modeling nonlinearities in MEMS oscillators | 10.1109/tuffc.2013.2747 | fulltext_unavailable_from_checked_sources |  |
| W0851 | Optimal drive condition for nonlinearity reduction in electrostatic microresonators | 10.1063/1.2388886 | fulltext_unavailable_from_checked_sources |  |
| W0852 | Nonlinear Characterization of Electrostatic MEMS Resonators | 10.1109/freq.2006.275380 | fulltext_unavailable_from_checked_sources |  |
| W0853 | Identification of limiting damping mechanisms in a high quality factor hybrid resonator of space application gyroscope |  | needs_search_no_verified_identifier |  |
| W0854 | Dzhashitov, V. Pankratov, Datchiki, pribory i sistemy aviakosmicheskogo i morskogo priborostroeniya v usloviyakh teplovykh vozdeystviy [Sensors, devices and systems for aerospace and marine engineering in the conditions of thermal influence]. S, St. Petersburg, CNII Elektropribor Publ (2005) |  | needs_search_no_verified_identifier |  |
| W0855 | Observation and analysis of the quality factor variation behavior in a monolithic fused silica cylindrical resonator | 10.1016/j.sna.2017.03.041 | fulltext_unavailable_from_checked_sources |  |
| W0856 | The world smallest, most accurate and reliable pure inertial navigator: ONYX™ | 10.1109/inertialsensors.2018.8577108 | fulltext_unavailable_from_checked_sources |  |
| W0857 | Pose error identification algorithm based on hemispherical resonant gyroscope assembly capacitance uniformity | 10.1016/j.measurement.2022.111426 | fulltext_unavailable_from_checked_sources |  |
| W0858 | Development of an Algorithm to Suppress Frequency Splitting of an Axisymmetric Resonator of a Wave Solid-State Gyroscope with Optical Detection | 10.1007/s11018-020-01708-0 | fulltext_unavailable_from_checked_sources |  |
| W0859 | Whole-angle hemispherical resonator gyroscope drift model caused by nonlinear detection |  | needs_search_no_verified_identifier |  |
| W0860 | Full Symmetric MEMS Rate Gyroscope Automatic Mode-Matching Method Based on Pendulum Variable Demodulation and Phase-Shifted Virtual Coriolis Force Modulation | 10.1109/jsen.2025.3545282 | fulltext_unavailable_from_checked_sources |  |
| W0861 | A Novel Method for Observing Blowtorch Reflow of Micro Hemispherical Gyroscope Resonators | 10.1109/icsece65727.2025.11256864 | fulltext_unavailable_from_checked_sources |  |
| W0862 | Online Mode-Matching Method Countering for Stiffness Nonlinearity in Whole-Angle MEMS Gyroscope | 10.1109/jsen.2025.3548851 | fulltext_unavailable_from_checked_sources |  |
| W0863 | Identification and compensation of anisodamping for high Q factor resonator under whole-angle mode | 10.1109/sensors47087.2021.9639786 | fulltext_unavailable_from_checked_sources |  |
| W0864 | Analysis, Identification, and Compensation of Damping Asymmetry for Whole-Angle Mode Hemispherical Resonator Gyro | 10.1109/tim.2025.3547107 | fulltext_unavailable_from_checked_sources |  |
| W0865 | Suppression and Compensation of Damping Asymmetry Errors in Whole-Angle Hemispherical Resonator Gyroscope | 10.1109/jsen.2025.3572313 | fulltext_unavailable_from_checked_sources |  |
| W0866 | A Novel Phase Error Quantitative Characterization Method for Whole-Angle Micro Hemispherical Resonant Gyroscope | 10.1109/sensors60989.2024.10784886 | fulltext_unavailable_from_checked_sources |  |
| W0867 | Characterization and Compensation of Phase Delay and Modulation Pattern Angle Error for Rate-Integrating Micro-Hemispherical Resonator Gyroscope | 10.1109/jsen.2025.3543642 | fulltext_unavailable_from_checked_sources |  |
| W0868 | An Investigation on Influences of the Phase Delay and the Electrode Errors on a Mode-Reversal Hemispherical Resonator Gyroscope | 10.1109/tim.2025.3566834 | fulltext_unavailable_from_checked_sources |  |
| W0869 | Investigation of cylindrical resonators’ damping asymmetry via analyzing Q factor circumferential distribution | 10.1016/j.sna.2017.12.024 | fulltext_unavailable_from_checked_sources |  |
| W0870 | Electrostatic correction of structural imperfections present in a microring gyroscope | 10.1109/jmems.2004.839325 | fulltext_unavailable_from_checked_sources |  |
| W0871 | A systematic method for tuning the dynamics of electrostatically actuated vibratory gyros | 10.1109/tcst.2005.860525 | fulltext_unavailable_from_checked_sources |  |
| W0872 | Laser Patterned Self-Aligned Electrodes for Dual-Shell Hemispherical Resonator Gyroscope | 10.1109/transducers61432.2025.11109164 | fulltext_unavailable_from_checked_sources |  |
| W0873 | López. 2025 |  | needs_search_no_verified_identifier |  |
| W0874 | Real-time detection and dynamic compensation of mismatch in rate-integrating MEMS gyroscopes using virtual rotation |  | needs_search_no_verified_identifier |  |
| W0875 | A method for measuring the inertia properties of a rigid body using 3-URU parallel mechanism | 10.1016/j.ymssp.2019.01.013 | fulltext_unavailable_from_checked_sources |  |
| W0876 | An analytical formulation for phase noise in MEMS oscillators | 10.1109/tuffc.2014.006511 | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R1100_An analytical formulation for phase noise in MEMS oscillators.pdf |
| W0877 | Noise analysis of closed-Loop vibratory rate gyros | 10.1109/acc.2012.6314985 | fulltext_unavailable_from_checked_sources |  |
| W0878 | Mechanical Thermal Noise in Micro-Machined Levitated Two-Axis Rate Gyroscopes | 10.1109/jsen.2017.2785859 | fulltext_unavailable_from_checked_sources |  |
| W0879 | Autonomous execution of the Precision Immobilization Technique | 10.1016/j.ymssp.2016.06.043 | fulltext_unavailable_from_checked_sources |  |
| W0880 | A mechanical–thermal noise analysis of a nonlinear microgyroscope | 10.1016/j.ymssp.2016.06.005 | fulltext_unavailable_from_checked_sources |  |
| W0881 | 1/f noise under drift and thermal agitation in semiconductor materials | 10.1016/j.physa.2022.126917 | fulltext_unavailable_from_checked_sources |  |
| W0882 | Maximizing modulation efficiency to minimize 1/f noise in magnetoresistance | 10.1016/j.measurement.2022.112396 | fulltext_unavailable_from_checked_sources |  |
| W0883 | An improved interface and noise analysis of a turning fork microgyroscope structure | 10.1016/j.ymssp.2015.08.002 | fulltext_unavailable_from_checked_sources |  |
| W0884 | The impact of thermal-noise on bifurcation MEMS sensors | 10.1016/j.ymssp.2021.107941 | fulltext_unavailable_from_checked_sources |  |
| W0885 | Sources of Bias Instabilities (1/f Noise) in Optical Gyros | 10.1109/jsen.2019.2933183 | fulltext_unavailable_from_checked_sources |  |
| W0886 | Origins and Mechanisms of Bias Instability Noise in a Three-Axis Mode-Matched MEMS Gyroscope | 10.1109/jmems.2019.2921607 | fulltext_unavailable_from_checked_sources |  |
| W0887 | A Silicon MEMS Quatrefoil Suspension Gyroscope | 10.1109/jmems.2023.3296751 | fulltext_unavailable_from_checked_sources |  |
| W0888 | Influence of Parametric Nonlinearities on Closed-Loop Operated MEMS Gyroscopes | 10.1109/jmems.2022.3156817 | fulltext_unavailable_from_checked_sources |  |
| W0889 | Design of Force-to-Rebalanced System With Adaptive Fuzzy-PID Controller for N = 3 MEMS Disk Gyroscope | 10.1109/jsen.2021.3068152 | fulltext_unavailable_from_checked_sources |  |
| W0890 | Not Fully Overlapping Allan Variance and Total Variance for Inertial Sensor Stochastic Error Analysis | 10.1109/tim.2013.2258769 | fulltext_unavailable_from_checked_sources |  |
| W0891 | IEEE Standard Specification Format Guide and Test Procedure for Single-Axis Laser Gyros | 10.1109/ieeestd.1981.7434541 | fulltext_unavailable_from_checked_sources |  |
| W0892 | Automatic Mode Matching in MEMS Vibrating Gyroscopes Using Extremum-Seeking Control | 10.1109/tie.2009.2020707 | fulltext_unavailable_from_checked_sources |  |
| W0893 | Vector Brillouin Optical Time-Domain Analysis with Heterodyne Detection and IQ Demodulation Algorithm |  | needs_search_no_verified_identifier |  |
| W0894 | Phase Demodulation Methods for Optical Fiber Vibration Sensing System: A Review | 10.1109/jsen.2021.3135909 | fulltext_unavailable_from_checked_sources |  |
| W0895 | Polarization-Modulation, I/Q-Demodulation Photonic Bandpass Sampling for Wideband, Multicarrier RF Application | 10.1109/jphot.2017.2732918 | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R1119_Polarization-Modulation_ I_Q-Demodulation Photonic Bandpass Sampling for Wideband_ Multicarrier RF Application.pdf |
| W0896 | Effect of nonlinear electrostatic forces on the dynamic behaviour of a capacitive ring-based Coriolis Vibrating Gyroscope under severe shock | 10.1016/j.ymssp.2017.12.043 | fulltext_unavailable_from_checked_sources |  |
| W0897 | Frequency-Modulated MEMS Gyroscopes: A Review | 10.1109/jsen.2021.3117939 | fulltext_unavailable_from_checked_sources |  |
| W0898 | MEMS and MOEMS Gyroscopes: A Review | 10.1007/s13320-023-0693-x | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R1122_MEMS and MOEMS Gyroscopes_ A Review.pdf |
| W0899 | 0.08 ppm Scale Factor Nonlinearity in Whole-Angle Hemispherical Resonator Gyroscopes Enabled by Rapid Detection Signal Nonlinearity Suppression | 10.1109/led.2025.3604433 | fulltext_unavailable_from_checked_sources |  |
| W0900 | A Rate-Integrating Honeycomb Disk Resonator Gyroscope With 0.038°/h Bias Instability and °7000°/s Measurement Range | 10.1109/led.2021.3062897 | fulltext_unavailable_from_checked_sources |  |
| W0901 | Frequency Split Modulation in Micro Hemispherical Resonator Based on Rim Width | 10.1109/jmems.2025.3589105 | fulltext_unavailable_from_checked_sources |  |
| W0902 | Impact of Phase Noise on Bias Instability in Mode-Split Open-Loop MEMS Gyroscopes | 10.1109/jsen.2024.3386797 | fulltext_unavailable_from_checked_sources |  |
| W0903 | Analysis of parasitics in angle random walk improvement for MEMS gyroscopes | 10.1016/j.sna.2025.116536 | fulltext_unavailable_from_checked_sources |  |
| W0904 | Spectral Analysis of Vibratory Gyro Noise | 10.1109/jsen.2013.2269797 | fulltext_unavailable_from_checked_sources |  |
| W0905 | Noise analysis of mode matched vibratory gyroscopes | 10.1007/s00542-022-05365-x | fulltext_unavailable_from_checked_sources |  |
| W0906 | A 0.82 μVrms ultralow 1/f noise bandgap reference for a MEMS gyroscope | 10.1038/s41378-023-00505-3 | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R1130_A 0.82 μVrms ultralow 1_f noise bandgap reference for a MEMS gyroscope.pdf |
| W0907 | Numerical Verification of an Analytical Model for Phase Noise in MEMS Oscillators | 10.1109/tuffc.2016.2575364 | fulltext_unavailable_from_checked_sources |  |
| W0908 | Gyroscope Technology and Applications: A Review in the Industrial Perspective | 10.3390/s17102284 | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R1132_Gyroscope Technology and Applications_ A Review in the Industrial Perspective.pdf |
| W0909 | A Review of MEMS Vibrating Gyroscopes and Their Reliability Issues in Harsh Environments | 10.3390/s22197405 | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R1133_A Review of MEMS Vibrating Gyroscopes and Their Reliability Issues in Harsh Environments.pdf |
| W0910 | Impact of gyroscope operation above the critical bifurcation threshold on scale factor and bias instability | 10.1109/memsys.2014.6765749 | fulltext_unavailable_from_checked_sources |  |
| W0911 | Nonlinear Dynamics of a Microscale Rate Integrating Gyroscope with a Disk Resonator under Parametric Excitation | 10.20537/nd230102 | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R1135_Nonlinear Dynamics of a Microscale Rate Integrating Gyroscope with a Disk Resonator under Parametric Excitation.pdf |
| W0912 | Nonlinear effects in dynamics of cylindrical resonator of wave solid-state gyro with electrostatic control system | 10.1134/s2075108715030104 | fulltext_unavailable_from_checked_sources |  |
| W0913 | Nonlinear Performance of MEMS Vibratory Ring Gyroscope | 10.1007/s10338-020-00195-8 | fulltext_unavailable_from_checked_sources |  |
| W0914 | Vibration-Induced Errors in MEMS Tuning Fork Gyroscopes with Imbalance | 10.3390/s18061755 | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R1139_Vibration-Induced Errors in MEMS Tuning Fork Gyroscopes with Imbalance.pdf |
| W0915 | IMPACT OF NONLINEAR PROPERTIES OF ELECTROSTATIC CONTROL SENSORS ON THE DYNAMICS OF A CYLINDRICAL RESONATOR OF A WAVE SOLID-STATE GYROSCOPE | 10.3103/s002565442106011x | fulltext_unavailable_from_checked_sources |  |
| W0916 | Effect of Electrostatic Nonlinearity on Force-to-Rebalance Mode of Operation in CVG | 10.1109/iss50053.2020.9244877 | fulltext_unavailable_from_checked_sources |  |
| W0917 | Rate-Integrating Gyroscope Operation in The Non-Linear Regime | 10.1109/iss55898.2022.9926373 | existing_local | C:/Users/11725/Desktop/HRG_WA/全角陀螺/新增资料_20261021_WoS/pdf/算法与补偿/2022_Nonlinear_RIG.pdf |
| W0918 | Nonlinear Effects in the Dynamics of HRG with Flat Electrodes | 10.1134/s2075108724700044 | fulltext_unavailable_from_checked_sources |  |
| W0919 | Methods to eliminate nonlinearity of electrostatic control sensors of the wave solid-state gyroscope | 10.23919/icins.2018.8405895 | fulltext_unavailable_from_checked_sources |  |
| W0920 | Parametric drive of a toroidal MEMS rate integrating gyroscope demonstrating &amp;lt; 20 PPM scale factor stability | 10.1109/memsys.2015.7050878 | fulltext_unavailable_from_checked_sources |  |
| W0921 | Study of Electrode Ablation for Femtosecond Laser Trimming of Micro Hemispherical Resonator Gyroscope | 10.1109/jsen.2022.3224000 | fulltext_unavailable_from_checked_sources |  |
| W0922 | A high-precision mode matching method for rate-integrating honeycomb disk resonator gyroscope | 10.1109/nems51815.2021.9451462 | fulltext_unavailable_from_checked_sources |  |
| W0923 | A 0.1 DEG/H Module-Level Silicon Mems Rate Integrating Gyroscope Using Virtually Rotated Donut-Mass Structure and Demonstration of the Earth's Rotation Detection | 10.1109/transducers50396.2021.9495598 | fulltext_unavailable_from_checked_sources |  |
| W0924 | A Two-Stage Fault Diagnosis Method With Rough and Fine Classifiers for Phased Array Radar Transceivers | 10.1109/tim.2024.3485396 | fulltext_unavailable_from_checked_sources |  |
| W0925 | Model Predictive Sliding Control for Finite-Time Three-Axis Spacecraft Attitude Tracking | 10.1109/tie.2018.2881936 | fulltext_unavailable_from_checked_sources |  |
| W0926 | MEMS multi-vibrating ring gyroscope for space applications | 10.1007/s00542-020-04793-x | fulltext_unavailable_from_checked_sources |  |
| W0927 | BotanicGarden: A High-Quality Dataset for Robot Navigation in Unstructured Natural Environments | 10.1109/lra.2024.3359548 | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R1154_BotanicGarden_ A High-Quality Dataset for Robot Navigation in Unstructured Natural Environments.pdf |
| W0928 | Quadrotor with wheels: design and experimental evaluation | 10.1038/s41598-024-66396-0 | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R1155_Quadrotor with wheels_ design and experimental evaluation.pdf |
| W0929 | GNSS/MEMS-INS Integration for Drone Navigation Using EKF on Lie Groups | 10.1109/taes.2023.3290575 | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R1156_GNSS_MEMS-INS Integration for Drone Navigation Using EKF on Lie Groups.pdf |
| W0930 | Analytical quaternion-based bias estimation algorithm for fast and accurate stationary gyro-compassing | 10.1038/s41598-024-66282-9 | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R1157_Analytical quaternion-based bias estimation algorithm for fast and accurate stationary gyro-compassing.pdf |
| W0931 | Removal of the rate table: MEMS gyrocompass with virtual maytagging | 10.1038/s41378-023-00610-3 | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R1158_Removal of the rate table_ MEMS gyrocompass with virtual maytagging.pdf |
| W0932 | Design of Ethernet based data acquisition system for yaw rate and longitudinal velocity measurement in automobiles | 10.1007/s11633-016-0968-4 | needs_bibliographic_version_review |  |
| W0933 | Simulated analysis of forming imperfection for micro shell resonators | 10.1007/s00542-020-04995-3 | fulltext_unavailable_from_checked_sources |  |
| W0934 | Frequency split suppression of fused silica micro shell resonator based on rotating forming process | 10.1007/s00542-020-05034-x | fulltext_unavailable_from_checked_sources |  |
| W0935 | Electrostatic tuning of temperature coefficient of frequency of anisotropic disk-shaped resonators | 10.1109/isiss.2017.7935664 | fulltext_unavailable_from_checked_sources |  |
| W0936 | Controlled capacitive gaps for electrostatic actuation and tuning of 3D fused quartz micro wineglass resonator gyroscope | 10.1109/isiss.2017.7935688 | fulltext_unavailable_from_checked_sources |  |
| W0937 | 1.5-Million Q-Factor Vacuum-Packaged Birdbath Resonator Gyroscope (BRG) | 10.1109/memsys.2019.8870889 | fulltext_unavailable_from_checked_sources |  |
| W0938 | Achieving Sub-5-mHz Frequency Split Trimming of Micro Hemispherical Resonator Gyroscope With Method of Mass–Stiffness Decoupling | 10.1109/jsen.2024.3415408 | fulltext_unavailable_from_checked_sources |  |
| W0939 | High resolution micro ultrasonic machining (HR-&amp;#x03BC;USM) for post-fabrication trimming of fused silica 3-D microstructures | 10.1109/memsys.2014.6765685 | fulltext_unavailable_from_checked_sources |  |
| W0940 | Trimming of Imperfect Cylindrical Fused Silica Resonators by Chemical Etching | 10.3390/s19163596 | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R1167_Trimming of Imperfect Cylindrical Fused Silica Resonators by Chemical Etching.pdf |
| W0941 | Wang, Y., Asadian, M. H. & Shkel, A. M. In 2017 IEEE International Symposium on Inertial Sensors and Systems (INERTIAL). 78–81 (2017) |  | needs_search_no_verified_identifier |  |
| W0942 | Development of 3D Fused Quartz Hemi-Toroidal Shells for High-Q Resonators and Gyroscopes | 10.1109/jmems.2019.2945713 | fulltext_unavailable_from_checked_sources |  |
| W0943 | Geometric Imperfection Characterization and Precise Assembly of Micro Shell Resonators | 10.1109/jmems.2020.2974513 | fulltext_unavailable_from_checked_sources |  |
| W0944 | A quadrature compensation method to improve the performance of the butterfly vibratory gyroscope | 10.1016/j.sna.2020.112527 | fulltext_unavailable_from_checked_sources |  |
| W0945 | Novel resonant pressure sensor based on piezoresistive detection and symmetrical in-plane mode vibration | 10.1038/s41378-020-00207-0 | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R1172_Novel resonant pressure sensor based on piezoresistive detection and symmetrical in-plane mode vibration.pdf |
| W0946 | A Bent-TBTF Resonant MEMS Accelerometer Using Auxiliary Supporting Beams | 10.1109/led.2024.3453324 | fulltext_unavailable_from_checked_sources |  |
| W0947 | Highly Sensitive Temperature Sensor Based on Coupled-Beam AlN-on-Si MEMS Resonators Operating in Out-of-Plane Flexural Vibration Modes | 10.34133/2022/9865926 | fulltext_unavailable_from_checked_sources |  |
| W0948 | Mode-Matching of Wineglass Mode Disk Resonator Gyroscope in (100) Single Crystal Silicon | 10.1109/jmems.2014.2330590 | fulltext_unavailable_from_checked_sources |  |
| W0949 | 0.04 degree-per-hour MEMS disk resonator gyroscope with high-quality factor (510 k) and long decaying time constant (74.9 s) | 10.1038/s41378-018-0035-0 | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R1176_0.04 degree-per-hour MEMS disk resonator gyroscope with high-quality factor _510_k_ and long decaying time constant.pdf |
| W0950 | Initial Demonstration of an Inductive Vibrating Ring Gyroscope Fabricated From Fused Silica | 10.1109/led.2024.3403866 | fulltext_unavailable_from_checked_sources |  |
| W0951 | Ultra-Low Relative Frequency Split Piezoelectric Ring Resonator Designed for High-Performance Mode-Matching Gyroscope | 10.1109/jmems.2021.3132371 | fulltext_unavailable_from_checked_sources |  |
| W0952 | Encapsulated high frequency (235 kHz), high-Q (100 k) disk resonator gyroscope with electrostatic parametric pump | 10.1063/1.4904468 | fulltext_unavailable_from_checked_sources |  |
| W0953 | Gun hard inertial measurement unit based on MEMS capacitive accelerometer and rate sensor | 10.1109/plans.2008.4569974 | fulltext_unavailable_from_checked_sources |  |
| W0954 | Research on the Mass Adding and Removing Combined Mechanical Trimming Method of the Ring MEMS Gyroscope | 10.3390/mi14101957 | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R1181_Research on the Mass Adding and Removing Combined Mechanical Trimming Method of the Ring MEMS Gyroscope.pdf |
| W0955 | Tailored Etch Profiles for Wafer-Level Frequency Tuning of Axisymmetric Resonators | 10.1109/jmems.2017.2667582 | fulltext_unavailable_from_checked_sources |  |
| W0956 | Quad Mass Gyroscope with 16 ppm Frequency Mismatch Trimmed by Focus Ion Beam | 10.1109/isiss.2019.8739610 | fulltext_unavailable_from_checked_sources |  |
| W0957 | Mechanical trimming with focused ion beam for permanent tuning of MEMS dual-mass gyroscope | 10.1016/j.sna.2020.112189 | fulltext_unavailable_from_checked_sources |  |
| W0958 | Quad Mass Resonator With Frequency Mismatch of 3 ppm Trimmed by Focused Ion Beam | 10.1109/jmems.2021.3065720 | fulltext_unavailable_from_checked_sources |  |
| W0959 | Frequency Tuning of a Disk Resonator Gyro Via Mass Matrix Perturbation | 10.1115/1.3155016 | fulltext_unavailable_from_checked_sources |  |
| W0960 | Frequency Tuning of a Disk Resonator Gyroscope via Stiffness Perturbation | 10.1109/jsen.2017.2712599 | fulltext_unavailable_from_checked_sources |  |
| W0961 | Electrothermal frequency tuning of folded and coupled vibrating micromechanical resonators | 10.1109/84.679341 | fulltext_unavailable_from_checked_sources |  |
| W0962 | Electrothermal tuning of Al–SiC nanomechanical resonators | 10.1088/0957-4484/17/5/057 | fulltext_unavailable_from_checked_sources |  |
| W0963 | Extreme mechanical tunability in suspended MoS2 resonator controlled by Joule heating | 10.1038/s41699-023-00383-3 | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R1190_Extreme mechanical tunability in suspended MoS2 resonator controlled by Joule heating.pdf |
| W0964 | Programmable Mechanical Resonances in MEMS by Localized Joule Heating of Phase Change Materials | 10.1002/adma.201302087 | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R1191_Programmable Mechanical Resonances in MEMS by Localized Joule Heating of Phase Change Materials.pdf |
| W0965 | Highly-doped SiC resonator with ultra-large tuning frequency range by Joule heating effect | 10.1016/j.matdes.2020.108922 | fulltext_unavailable_from_checked_sources |  |
| W0966 | Actuation Dependency of Frequency Tuning in MEMS Resonators | 10.1109/jmems.2020.2975077 | fulltext_unavailable_from_checked_sources |  |
| W0967 | Simple frequency expression for the in-plane vibration of thick circular rings | 10.1121/1.380829 | fulltext_unavailable_from_checked_sources |  |
| W0968 | Cylindrical Fused Silica Resonators Driven by PZT Thin Film Electrodes with Q Factor Achieving 2.89 Million after Coating | 10.1038/s41598-019-45180-5 | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R1195_Cylindrical Fused Silica Resonators Driven by PZT Thin Film Electrodes with Q Factor Achieving 2.89 Million after C.pdf |
| W0969 | Self-induced parametric amplification arising from nonlinear elastic coupling in a micromechanical resonating disk gyroscope | 10.1038/srep09036 | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R1196_Self-induced parametric amplification arising from nonlinear elastic coupling in a micromechanical resonating disk.pdf |
| W0970 | A Phase Self-Correction Method for Bias Temperature Drift Suppression of MEMS Gyroscopes | 10.1142/s0218126620501984 | fulltext_unavailable_from_checked_sources |  |
| W0971 | A Real-Time Circuit Phase Delay Correction System for MEMS Vibratory Gyroscopes | 10.3390/mi12050506 | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R1199_A Real-Time Circuit Phase Delay Correction System for MEMS Vibratory Gyroscopes.pdf |
| W0972 | Effects of both the drive- and sense-mode circuit phase delay on MEMS gyroscope performance and real-time suppression of the residual fluctuation phase error | 10.1088/1361-6439/abec1b | fulltext_unavailable_from_checked_sources |  |
| W0973 | Development of a complete model to evaluate the Zero Rate Level drift over temperature in MEMS Coriolis Vibrating Gyroscopes | 10.1109/isiss.2017.7935673 | fulltext_unavailable_from_checked_sources |  |
| W0974 | Zero-Rate Output and Quadrature Compensation in Vibratory MEMS Gyroscopes | 10.1109/jsen.2007.908921 | fulltext_unavailable_from_checked_sources |  |
| W0975 | Front cover | 10.1109/jmems.2021.3123768 | fulltext_unavailable_from_checked_sources |  |
| W0976 | Combined phase-readout and self-calibration of MEMS gyroscopes | 10.1109/transducers.2013.6626928 | fulltext_unavailable_from_checked_sources |  |
| W0977 | A Backgournd Calibration Technique For I/Q Phase Mismatch In MEMS Vibratory Gyroscope | 10.1109/transducers.2019.8808674 | fulltext_unavailable_from_checked_sources |  |
| W0978 | Editor-in-Chief’s Year-End Message | 10.1109/tim.2024.3518732 | fulltext_unavailable_from_checked_sources |  |
| W0979 | One-time frequency sweep to eliminate IQ coupling in MEMS vibratory gyroscopes | 10.1109/3m-nano.2016.7824917 | fulltext_unavailable_from_checked_sources |  |
| W0980 | Online Compensation of Phase Delay Error Based on P-F Characteristic for MEMS Vibratory Gyroscopes | 10.3390/mi13050647 | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R1208_Online Compensation of Phase Delay Error Based on P-F Characteristic for MEMS Vibratory Gyroscopes.pdf |
| W0981 | Solid-state wave gyro navigation system (2013) |  | needs_search_no_verified_identifier |  |
| W0982 | Hu, Q. et al. A method for balancing the fourth harmonic mass of hemispherical resonator gyro. J. Chin. Inert. Technol. 31, 601–610 (2023) |  | needs_search_no_verified_identifier |  |
| W0983 | 2019. 17 |  | needs_search_no_verified_identifier |  |
| W0984 | New Gyroscopes of the “Generalized Foucault Pendulum” Family: Some Fundamental Issues of Theory and Applied Aspects of Its Implementation in the Engineering Practice of Modern Gyroscopy | 10.23919/icins43215.2020.9133890 | fulltext_unavailable_from_checked_sources |  |
| W0985 | A MEMS rate integrating gyroscope based on catch-and-release mechanism for low-noise continuous angle measurement | 10.1109/memsys.2018.8346713 | fulltext_unavailable_from_checked_sources |  |
| W0986 | Structural Parameter Identification of the Center Support Quadruple Mass Gyro | 10.1109/jsen.2017.2695501 | fulltext_unavailable_from_checked_sources |  |
| W0987 | Toroidal resonators with small frequency mismatch for rate integrating gyroscopes |  | needs_search_no_verified_identifier |  |
| W0988 | Self-Excitation Enabled Decoupling, Calibration, and Compensation of Errors for Whole-Angle Hemispherical Resonator Gyroscope | 10.1109/tim.2023.3346525 | fulltext_unavailable_from_checked_sources |  |
| W0989 | 1995. 26 |  | needs_search_no_verified_identifier |  |
| W0990 | Silicon MEMS Disk Resonator Gyroscope With an Integrated CMOS Analog Front-End | 10.1109/jsen.2014.2335735 | fulltext_unavailable_from_checked_sources |  |
| W0991 | Epitaxially-encapsulated polysilicon disk resonator gyroscope | 10.1109/memsys.2013.6474319 | fulltext_unavailable_from_checked_sources |  |
| W0992 | MEMS Gyroscope Automatic Real-Time Mode-Matching Method Based on Phase-Shifted 45° Additional Force Demodulation | 10.3390/s18093001 | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R1222_MEMS Gyroscope Automatic Real-Time Mode-Matching Method Based on Phase-Shifted 45_ Additional Force Demodulation.pdf |
| W0993 | An Automatic MEMS Gyroscope Mode Matching Circuit Based on Noise Observation | 10.1109/tcsii.2019.2908527 | fulltext_unavailable_from_checked_sources |  |
| W0994 | A Lumped Mass Model for Circular Micro-Resonators in Coriolis Vibratory Gyroscopes | 10.3390/mi10060378 | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R1224_A Lumped Mass Model for Circular Micro-Resonators in Coriolis Vibratory Gyroscopes.pdf |
| W0995 | Automated Frequency and Quality Factor Mismatch Compensation Method for MEMS Rate Integrating Gyroscope | 10.1109/transducers.2019.8808513 | fulltext_unavailable_from_checked_sources |  |
| W0996 | MEMS Rate Integrating Gyroscope with Temperature Corrected Virtual Rotation | 10.1109/isiss.2019.8739625 | fulltext_unavailable_from_checked_sources |  |
| W0997 | Effect of structural anisotropy on anchor loss mismatch and predicted case drift in future micro-Hemispherical Resonator Gyros | 10.1109/plans.2014.6851408 | fulltext_unavailable_from_checked_sources |  |
| W0998 | The dynamics of a vibrating-ring multi-axis rate gyroscope | 10.1243/0954406001523443 | fulltext_unavailable_from_checked_sources |  |
| W0999 | Autonomous calibration of MEMS disk resonating gyroscope for improved sensor performance | 10.1109/acc.2016.7526579 | fulltext_unavailable_from_checked_sources |  |
| W1000 | A Study of the Temperature Characteristics of Vibration Mode Axes for Vibratory Cylinder Gyroscopes | 10.3390/s110807665 | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R1231_A Study of the Temperature Characteristics of Vibration Mode Axes for Vibratory Cylinder Gyroscopes.pdf |
| W1001 | High Performance MEMS Disk Gyroscope with Force-to-Rebalance Operation Mode | 10.1109/icsens.2018.8589905 | fulltext_unavailable_from_checked_sources |  |
| W1002 | High-Q fused silica Micro-Shell resonators for navigation-grade MEMS gyroscopes |  | needs_search_no_verified_identifier |  |
| W1003 | High-performance micromachined vibratory rate-and rate-integrating gyroscopes |  | needs_search_no_verified_identifier |  |
| W1004 | Micromachined Rate-Integrating Gyroscopes: Concept, Asymmetry Error Sources and Phenomena | 10.3390/sym12050801 | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R1235_Micromachined Rate-Integrating Gyroscopes_ Concept_ Asymmetry Error Sources and Phenomena.pdf |
| W1005 | Calibration of Channel Error in Dual-Channel Synchronous Control Circuit for Rate Integrating Hemispherical Resonator Gyro | 10.1109/ccdc65474.2025.11090788 | fulltext_unavailable_from_checked_sources |  |
| W1006 | Identification and Compensation Method for Detection Signal Unbalanced-Phase-Delay-Error of Hemispherical Resonator Gyro | 10.1109/cac59555.2023.10450549 | fulltext_unavailable_from_checked_sources |  |
| W1007 | Self-Calibration Method for Phase Errors in Hemispherical Resonator Gyro Based on Virtual Precession | 10.1109/tim.2025.3586357 | fulltext_unavailable_from_checked_sources |  |
| W1008 | Dual-Channel Phase Delay Compensation for Hemispherical Resonator Gyroscopes With Angle-Dependent Bias Reduction to 3.190×10<sup>-5</sup>°/s | 10.1109/jsen.2025.3602801 | fulltext_unavailable_from_checked_sources |  |
| W1009 | Calibration and Compensation of Asymmetric Phase Error for Whole-Angle Hemispherical Resonant Gyroscope | 10.1109/jsen.2025.3583295 | fulltext_unavailable_from_checked_sources |  |
| W1010 | Fast Identification and Compensation for Actuation Electrode Errors of Rate Integrating Gyroscopes | 10.1109/jsen.2024.3408638 | fulltext_unavailable_from_checked_sources |  |
| W1011 | Low-Cost Inertial Measurement Unit Calibration With Nonlinear Scale Factors | 10.1109/tii.2021.3077296 | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R1243_Low-Cost Inertial Measurement Unit Calibration With Nonlinear Scale Factors.pdf |
| W1012 | A Self-Calibration Method for Accelerometer Nonlinearity Errors in Triaxis Rotational Inertial Navigation System | 10.1109/tim.2016.2625958 | fulltext_unavailable_from_checked_sources |  |
| W1013 | A System-Level Calibration Method for INS: Simultaneous Compensation of Accelerometer Asymmetric Errors and Second-Order Temperature-Related Errors | 10.1109/tim.2025.3551480 | fulltext_unavailable_from_checked_sources |  |
| W1014 | An Encoder-Based Relative Attitude Observation Method for Self-Calibration in Dual-Axis RINS | 10.1109/tie.2022.3229325 | fulltext_unavailable_from_checked_sources |  |
| W1015 | Collaborative Calibration Method for Redundant Dual-Axis RINSs Based on Geometric Constraint in GNSS-Denied Environments | 10.1109/tii.2024.3507210 | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R1247_Collaborative Calibration Method for Redundant Dual-Axis RINSs Based on Geometric Constraint in GNSS-Denied Environ.pdf |
| W1016 | A vehicle angular motion isolation method for dual-axis rotational laser gyro inertial navigation system | 10.1117/12.2617343 | fulltext_unavailable_from_checked_sources |  |
| W1017 | Calibration technique for laser gyro strapdown inertial navigation systems |  | needs_search_no_verified_identifier |  |
| W1018 | Correlation-Averaging Methods and Kalman Filter Based Parameter Identification for a Rotational Inertial Navigation System | 10.1109/tii.2018.2850756 | fulltext_unavailable_from_checked_sources |  |
| W1019 | Error compensation of an optical gyro INS by multi-axis rotation | 10.1088/0957-0233/23/2/025102 | fulltext_unavailable_from_checked_sources |  |
| W1020 | Intermittently Dynamic Fuzzy Learning-Based Tracking Control of Amplitude Signals for Vibratory Gyroscopes With Composite Identification | 10.1109/tim.2025.3565052 | fulltext_unavailable_from_checked_sources |  |
| W1021 | Amplitude control contour in a hemispherical resonator gyro with automatic compensation for difference in Q-factors | 10.3103/s0025654408030035 | fulltext_unavailable_from_checked_sources |  |
| W1022 | Standing Wave Vector Control Error Analysis and Suppression Method for Rate Integrating Hemispherical Resonator Gyro | 10.23919/icins51816.2023.10168485 | fulltext_unavailable_from_checked_sources |  |
| W1023 | Matveev. 2009 |  | needs_search_no_verified_identifier |  |
| W1024 | Direct Angle Measurement Using Dynamically-Amplified Gyroscopes | 10.1109/jsen.2021.3139919 | fulltext_unavailable_from_checked_sources |  |
| W1025 | A new operational mode for axisymmetric Coriolis vibrating gyroscopes: Force Angle Tracking (FAT) | 10.1109/iss58390.2023.10361911 | fulltext_unavailable_from_checked_sources |  |
| W1026 | A 0.017 <sup>∘</sup>/h Rate-Integrating Micro-Shell Resonator Gyroscope Using Virtual Rotation Modulation | 10.1109/jmems.2024.3474054 | fulltext_unavailable_from_checked_sources |  |
| W1027 | Phase correction in digital self-oscillation drive circuit for improve silicon MEMS gyroscope bias stability | 10.1109/icsict.2010.5667594 | fulltext_unavailable_from_checked_sources |  |
| W1028 | Asymmetric analysis and suppression method of gain of hemispherical resonant gyro circuit |  | needs_search_no_verified_identifier |  |
| W1029 | Identification and correction of phase delay errors for hemispherical resonator gyroscopes | 10.1038/s41598-025-86288-1 | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R1262_Identification and correction of phase delay errors for hemispherical resonator gyroscopes.pdf |
| W1030 | Hemispherical Resonator Gyro Error Self-Calibration Method Based on Standing Wave Precession | 10.1109/scset58950.2023.00150 | fulltext_unavailable_from_checked_sources |  |
| W1031 | Structural and thermal modeling of a<i>z</i>-axis rate integrating gyroscope | 10.1088/0960-1317/13/2/310 | fulltext_unavailable_from_checked_sources |  |
| W1032 | A High-Accuracy GPS-Aided Coarse Alignment Method for MEMS-Based SINS | 10.1109/tim.2020.2983578 | fulltext_unavailable_from_checked_sources |  |
| W1033 | Estimation on IMU yaw misalignment by fusing information of automotive onboard sensors | 10.1016/j.ymssp.2021.107993 | fulltext_unavailable_from_checked_sources |  |
| W1034 | Closed loop control design for the sense mode of micromachined vibratory gyroscopes | 10.1007/s11431-013-5201-x | fulltext_unavailable_from_checked_sources |  |
| W1035 | Design of a Shock-Protected Structure for MEMS Gyroscopes over a Full Temperature Range | 10.3390/mi15020206 | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R1268_Design of a Shock-Protected Structure for MEMS Gyroscopes over a Full Temperature Range.pdf |
| W1036 | Frequency mismatch analysis of hemispherical shell resonators with both radius and thickness imperfections | 10.1063/5.0202421 | fulltext_unavailable_from_checked_sources |  |
| W1037 | Identification and compensation of phase imbalance errors in hemispherical resonator gyroscopes | 10.1016/j.measurement.2025.119992 | fulltext_unavailable_from_checked_sources |  |
| W1038 | Research on the Influence of Temperature on Errors of Resonator Gyroscopes Related to Damping Imperfections | 10.1109/iss58390.2023.10361913 | fulltext_unavailable_from_checked_sources |  |
| W1039 | Precision Enhancement by Compensation of Hemispherical Resonator Gyroscope Dynamic Output Errors | 10.1109/tim.2023.3277998 | fulltext_unavailable_from_checked_sources |  |
| W1040 | Separation of mass and gap errors of hemispherical resonator gyroscopes by varying bias voltage | 10.1016/j.measurement.2024.114308 | fulltext_unavailable_from_checked_sources |  |
| W1041 | Quadrature FM gyroscope | 10.1109/memsys.2013.6474314 | fulltext_unavailable_from_checked_sources |  |
| W1042 | Radially Pleated Disk Resonator for Gyroscopic Application | 10.1109/jmems.2021.3105128 | fulltext_unavailable_from_checked_sources |  |
| W1043 | A Digital Control Structure for Lissajous Frequency-Modulated Mode MEMS Gyroscope | 10.1109/jsen.2022.3204431 | fulltext_unavailable_from_checked_sources |  |
| W1044 | Interactive Errors Analysis and Scale Factor Nonlinearity Reduction Methods for Lissajous Frequency Modulated MEMS Gyroscope | 10.3390/s23249701 | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R1279_Interactive Errors Analysis and Scale Factor Nonlinearity Reduction Methods for Lissajous Frequency Modulated MEMS.pdf |
| W1045 | FM/rate integrating MEMS gyroscope using independently controlled CW/CCW mode oscillations on a single resonator | 10.1109/isiss.2017.7935661 | fulltext_unavailable_from_checked_sources |  |
| W1046 | Real Time Q-Factor Mismatch Detection For Rate Integrating Gyroscope Using Amplitude Modulated Driving Signal | 10.1109/inertial53425.2022.9787723 | fulltext_unavailable_from_checked_sources |  |
| W1047 | Rate Integrating Gyroscope Tuned by Focus Ion Beam Trimming and Independent CW/CCW Modes Control | 10.1109/mems49605.2023.10052147 | fulltext_unavailable_from_checked_sources |  |
| W1048 | Real Time Mismatch Monitoring Using Software Defined Frequency Modulation and Rate Integrating Gyroscope | 10.1109/inertial60399.2024.10502049 | fulltext_unavailable_from_checked_sources |  |
| W1049 | Real-Time Detection and Dynamic Compensation of Mismatch in Rate-Integrating MEMS Gyroscopes Using Virtual Rotation | 10.1109/lsens.2024.3520910 | fulltext_unavailable_from_checked_sources |  |
| W1050 | Equivalent Bryan’s factor in hemispherical resonator gyroscopes with nonuniformities coupling | 10.1016/j.ijmecsci.2026.111465 | fulltext_unavailable_from_checked_sources |  |
| W1051 | Effect of surface integrity on quality factor of hemispherical resonator | 10.1016/j.ijmecsci.2024.109797 | fulltext_unavailable_from_checked_sources |  |
| W1052 | High-Precision Identification and Balance Method for the First-to-Third Harmonics of Mass Defects of Fused Quartz Hemispherical Resonator | 10.1109/tim.2025.3542100 | fulltext_unavailable_from_checked_sources |  |
| W1053 | Mattveev. 2009 |  | needs_search_no_verified_identifier |  |
| W1054 | Matrix animation and polar decomposition |  | needs_search_no_verified_identifier |  |
| W1055 | Dynamical analysis and experimental verification of deviation angles caused by rubber dampers deformation in high precision mechanically dithered RLG dual-axis RINS | 10.1016/j.ymssp.2019.02.045 | fulltext_unavailable_from_checked_sources |  |
| W1056 | Optimal design of SINS's Stewart platform bumper for restoration accuracy based on genetic algorithm | 10.1016/j.mechmachtheory.2018.01.016 | fulltext_unavailable_from_checked_sources |  |
| W1057 | Energy Loss Mechanisms in a Bulk-Micromachined Tuning Fork Gyroscope | 10.1109/icsens.2007.355876 | fulltext_unavailable_from_checked_sources |  |
| W1058 | Theory of Thermoelastic Damping in Micromechanical Resonators With Two-Dimensional Heat Conduction | 10.1109/jmems.2008.916316 | fulltext_unavailable_from_checked_sources |  |
| W1059 | Parameter estimation and interval type-2 fuzzy sliding mode control of a z-axis MEMS gyroscope | 10.1016/j.isatra.2013.05.004 | fulltext_unavailable_from_checked_sources |  |
| W1060 | Parameter Estimation of MEMS Gyroscope Using Local State Estimation Methods | 10.1016/j.ifacol.2015.12.139 | fulltext_unavailable_from_checked_sources |  |
| W1061 | Development status and trend of hemisherical resonator gyroscope assembly technology |  | needs_search_no_verified_identifier |  |
| W1062 | Identification Method for Assembly Pose Errors of Flat Electrode Hemispherical Resonator Gyro | 10.1109/jsen.2023.3344598 | fulltext_unavailable_from_checked_sources |  |
| W1063 | Optimizing HRG assembly through mathematical modeling of pose adjustment | 10.1016/j.procir.2024.07.029 | fulltext_unavailable_from_checked_sources |  |
| W1064 | The effect of structural parameters of hemispherical resonator gyroscope on operation mode and angular gain |  | needs_search_no_verified_identifier |  |
| W1065 | The optimal design of cavity optomechanical micro-hemispherical gyroscope | 10.1109/iceict61637.2024.10670774 | fulltext_unavailable_from_checked_sources |  |
| W1066 | Experimental study of thermoelastic damping in MEMS gyros | 10.1016/s0924-4247(02)00318-7 | fulltext_unavailable_from_checked_sources |  |
| W1067 | Internal Friction in Solids. I. Theory of Internal Friction in Reeds | 10.1103/physrev.52.230 | fulltext_unavailable_from_checked_sources |  |
| W1068 | Internal Friction in Solids II. General Theory of Thermoelastic Internal Friction | 10.1103/physrev.53.90 | fulltext_unavailable_from_checked_sources |  |
| W1069 | Engineering MEMS Resonators With Low Thermoelastic Damping | 10.1109/jmems.2006.883573 | fulltext_unavailable_from_checked_sources |  |
| W1070 | Thermal-Electromechanical FEM–BEM Model for MEMS Resonator Simulation | 10.1109/jmems.2010.2100021 | fulltext_unavailable_from_checked_sources |  |
| W1071 | Design of Inertial Class Gyroscope Resonator with Ultrahigh Quality Factor for Interplanetary Space Missions | 10.1007/978-981-15-0124-1_95 | fulltext_unavailable_from_checked_sources |  |
| W1072 | Design to Operational Parameters Dependency on Quality Factor of Sensor Mechanical Resonators | 10.1134/s207510872102005x | fulltext_unavailable_from_checked_sources |  |
| W1073 | Thermo-elastic damping and anchor loss in the operational modes of a hemispherical shell resonator |  | needs_search_no_verified_identifier |  |
| W1074 | Optimization of Hemispherical Shell Resonator Structure Based on Thermoelastic Dissipation | 10.1109/jmems.2024.3360460 | fulltext_unavailable_from_checked_sources |  |
| W1075 | Research on the Effect of Geometric Parameters of Hemispherical Resonator on Thermoelastic Dissipation | 10.3901/jme.2024.01.075 | fulltext_unavailable_from_checked_sources |  |
| W1076 | Effect of initial camber on natural nonlinear vibrations of cylindrical shells | 10.1007/bf00886245 | fulltext_unavailable_from_checked_sources |  |
| W1077 | The Outlook for Gyroscopy | 10.1134/s2075108720030062 | fulltext_unavailable_from_checked_sources |  |
| W1078 | Scale factor of the wave solid-state gyroscope operating in the angular velocity sensor mode |  | needs_search_no_verified_identifier |  |
| W1079 | Design and implementation of inertial measurement unit for satellites based on hemispherical resonant gyroscopes |  | needs_search_no_verified_identifier |  |
| W1080 | Current Status and Development Trend of Gyroscopes in Inertial Navigation in China |  | needs_search_no_verified_identifier |  |
| W1081 | Research on temperature dependent characteristics and compensation methods for digital gyroscope |  | needs_search_no_verified_identifier |  |
| W1082 | A Review of Theoretical Methods for Resonator Modeling of Hemispherical Resonator Gyro |  | needs_search_no_verified_identifier |  |
| W1083 | Periodic Error Compensation for Quartz MEMS Gyroscope Drift of INS | 10.1016/s1000-9361(07)60079-x | fulltext_unavailable_from_checked_sources |  |
| W1084 | Dynamic Friction-Slip Model Based on Contact Theory | 10.3390/machines10100951 | fulltext_unavailable_from_checked_sources |  |
| W1085 | Study on the Mechanism of Energy Dissipation in Hemispherical Resonator Gyroscope | 10.3390/s25010074 | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R1325_Study on the Mechanism of Energy Dissipation in Hemispherical Resonator Gyroscope.pdf |
| W1086 | Research on the Configuration Optimization of All-Metal Micro Resonant Hemisphere | 10.3390/s24227132 | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R1326_Research on the Configuration Optimization of All-Metal Micro Resonant Hemisphere.pdf |
| W1087 | Self-compensation of bias temperature drift in hemispherical resonator gyro |  | needs_search_no_verified_identifier |  |
| W1088 | Modelling Temperature Drift of HRG Based on AR Multi-Variable Model |  | needs_search_no_verified_identifier |  |
| W1089 | Temperature compensation method of laser gyroscope based on PSO-BP neural network |  | needs_search_no_verified_identifier |  |
| W1090 | Optimization of Amplitude Control Method of Hemispherical Resonator Gyroscopes Under Force-to-rebalance Mode |  | needs_search_no_verified_identifier |  |
| W1091 | Temperature compensation of MEMS gyroscope based ongrey model and RBF neural network |  | needs_search_no_verified_identifier |  |
| W1092 | Kan: Kolmogorov-arnold networks. arXiv |  | needs_search_no_verified_identifier |  |
| W1093 | Temperature modeling compensation and sensitivity analysis of HRG based on real time sliding window |  | needs_search_no_verified_identifier |  |
| W1094 | Novel nondelay-based reservoir computing with a single micromechanical nonlinear resonator for high-efficiency information processing | 10.1038/s41378-021-00313-7 | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R1334_Novel nondelay-based reservoir computing with a single micromechanical nonlinear resonator for high-efficiency info.pdf |
| W1095 | Comparative Noise Analysis of Readout Circuit in Hemispherical Resonator Gyroscope | 10.3390/mi16070802 | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R1335_Comparative Noise Analysis of Readout Circuit in Hemispherical Resonator Gyroscope.pdf |
| W1096 | Key Technologies of Hemispherical Resonant Gyro Inertial Navigation System | 10.1109/icos60708.2023.10425165 | fulltext_unavailable_from_checked_sources |  |
| W1097 | Noise identification of hemispherical resonant gyroscope circuit based on Allan varian |  | needs_search_no_verified_identifier |  |
| W1098 | Research on Noise Characteristics of Hemispherical Resonator Gyro |  | needs_search_no_verified_identifier |  |
| W1099 | Quantization Noise Suppression Technology of MEMS Gyroscopes with Dither Signal Injection |  | needs_search_no_verified_identifier |  |
| W1100 | Projected Performance of Smaller Hemispherical Resonator Gyros |  | needs_search_no_verified_identifier |  |
| W1101 | Analysis and Compensation of Imperfection Effects in Piezoelectric Vibratory Gyroscopes, Ph.D |  | needs_search_no_verified_identifier |  |
| W1102 | Vibratory Rotation Sensor with Scaning-Tunneling-Transducer Readout |  | needs_search_no_verified_identifier |  |
| W1103 | Hemispherical Resonator Gyro Noise Reduction for Precision Spacecraft Pointing |  | needs_search_no_verified_identifier |  |
| W1104 | Effect of movability of the resonator center on the operation of a hemispherical resonator gyro | 10.3103/s0025654407060039 | fulltext_unavailable_from_checked_sources |  |
| W1105 | THE INFLUENCE OF CONTROL SYSTEM DESIGN ON THE PERFORMANCE OF VIBRATORY GYROSCOPES | 10.1006/jsvi.2001.4163 | fulltext_unavailable_from_checked_sources |  |
| W1106 | Modification of piezoelectric vibratory gyroscope resonator parameters by feedback control | 10.1109/58.726445 | fulltext_unavailable_from_checked_sources |  |
| W1107 | Lynch, D.D., and Coriolis, Vibratory (1998, January 15–16). Gyros. Stuttgart Germany |  | needs_search_no_verified_identifier |  |
| W1108 | Adaptive Control of a Vibratory Angle Measuring Gyroscope | 10.3390/s100908478 | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R1349_Adaptive Control of a Vibratory Angle Measuring Gyroscope.pdf |
| W1109 | Oscillation Control Algorithms for Resonant Sensors with Applications to Vibratory Gyroscopes | 10.3390/s90805952 | fulltext_unavailable_from_checked_sources |  |
| W1110 | Mathematical models of the thermoelastic stress-strain state, temperature, and technological errors of a wave solid-state sensor of inertial informations of Inertial Information | 10.3103/s1052618810030076 | fulltext_unavailable_from_checked_sources |  |
| W1111 | Estimation of Vibratory Gyroscope Parameters with Data Derived from the Vibrating Element |  | needs_search_no_verified_identifier |  |
| W1112 | Vibrating Cylinder Rate Gyro: Theory of Operation and Error Analysis |  | needs_search_no_verified_identifier |  |
| W1113 | Method to reduce angular increment error of hemispherical resonators unit by time management |  | needs_search_no_verified_identifier |  |
| W1114 | Establishment of steady state model of amplitude-control for hemispherical resonator gyro under force-rebalance mod |  | needs_search_no_verified_identifier |  |
| W1115 | Sonic Vibrating Bell Gyro. (4157041), U.S |  | needs_search_no_verified_identifier |  |
| W1116 | Vibratory Rotation Sensor. (4951508), U.S |  | needs_search_no_verified_identifier |  |
| W1117 | Solid-State Wave Gyro, National Defense Industry Press |  | needs_search_no_verified_identifier |  |
| W1118 | Drift of An Imperfect Hemispherical resonator gyro |  | needs_search_no_verified_identifier |  |
| W1119 | Nonlinear Oscillations, John Wiley & Sons |  | needs_search_no_verified_identifier |  |
| W1120 | Signal Processing and Control Method of Whole Angle Mode Hemispherical Resonator Gyros |  | existing_local | D:/学习资料/资料/全角陀螺/半球谐振陀螺全角模式信号处理控制方法.pdf |
| W1121 | Measurement Method of Hemispherical Resonator Frequency Splitting and Normal-mode Axis Azimuth Based on Amplitude Frequency Response Characteristics |  | needs_search_no_verified_identifier |  |
| W1122 | Self-tuning control loop for suppression of quadrature in a hemispherical resonator gyro |  | needs_search_no_verified_identifier |  |
| W1123 | High-Q, 3kHz Single-Crystal-Silicon Cylindrical Rate-Integrating Gyro (CING) | 10.1109/memsys.2012.6170121 | fulltext_unavailable_from_checked_sources |  |
| W1124 | A new Silicon axisymmetric Gyroscope for Aerospace Applications | 10.1109/iss50053.2020.9244886 | fulltext_unavailable_from_checked_sources |  |
| W1125 | Boeing Disc Resonator Gyroscope | 10.1109/plans.2014.6851410 | fulltext_unavailable_from_checked_sources |  |
| W1126 | A Novel Sixteen-Sided Cobweb-Like Disk Resonator Gyroscope with Low As-Fabricated Frequency Split between Drive and Sense Modes | 10.1109/icsens.2018.8589581 | fulltext_unavailable_from_checked_sources |  |
| W1127 | World Pendulum Alliance: an apparatus performance analysis | 10.1109/iestec54539.2022.00054 | fulltext_unavailable_from_checked_sources |  |
| W1128 | New Methods for Finite Element Model Updating Problems | 10.2514/1.15654 | fulltext_unavailable_from_checked_sources |  |
| W1129 | Influence of Resonator Eccentricity on Accuracy of Hemispherical Resonator Gyro |  | needs_search_no_verified_identifier |  |
| W1130 | Quality factors of MEMS gyros and the role of thermoelastic damping | 10.1109/memsys.2002.984242 | fulltext_unavailable_from_checked_sources |  |
| W1131 | Temperature Dependence of Quality Factors at High Frequencies in MEMS Gyroscopes | 10.1109/mems49605.2023.10052368 | fulltext_unavailable_from_checked_sources |  |
| W1132 | Effect of geometric imperfections on anchor loss and characterisation of a gyroscope resonator with high quality factor | 10.1134/s2075108720030074 | fulltext_unavailable_from_checked_sources |  |
| W1133 | Finite element analysis of harmonic defect vibration characteristics of hemispherical resonator gyroscope |  | needs_search_no_verified_identifier |  |
| W1134 | Solid State Wave Gyro, National Defense Industry Press. [1st ed.]. (In Chinese) |  | needs_search_no_verified_identifier |  |
| W1135 | Influence of the resonator angular displacements in a hemispherical resonator gyro on the coupling between the working and beam-type vibrations | 10.3103/s0025654409050057 | fulltext_unavailable_from_checked_sources |  |
| W1136 | Rate Vibratory Gyroscopes Bias Minimization by the Standing Wave Angle Installation | 10.1109/elnano50318.2020.9088820 | fulltext_unavailable_from_checked_sources |  |
| W1137 | The development features and design of a vibratory gyroscope with a metallic cylindrical resonator |  | needs_search_no_verified_identifier |  |
| W1138 | Application and implementation of Cordic algorithm in hemispherical gyro |  | needs_search_no_verified_identifier |  |
| W1139 | Process Optimization and Structural Testing of Micro Hemispherical Resonator Gyroscope. [Master’s Thesis, Southeast University] |  | needs_search_no_verified_identifier |  |
| W1140 | Error Analysis and Testing Technology of Hemispherical Resonator Gyro. [Master’s Thesis, Harbin Institute of Technology] |  | needs_search_no_verified_identifier |  |
| W1141 | Design of digital control loop for hemispherical resonator gyro in force balance mode |  | needs_search_no_verified_identifier |  |
| W1142 | Analysis of vacuum requirement for hemispherical resonator gyro |  | needs_search_no_verified_identifier |  |
| W1143 | Quartz Hemispherical Resonator (Wave Solid-State Gyroscope), Kim L.A |  | needs_search_no_verified_identifier |  |
| W1144 | Design and parameter optimization of hemispherical resonator with variable wall thickness |  | needs_search_no_verified_identifier |  |
| W1145 | Calculation method of modal principal axis azimuth for micro hemispherical resonator gyro |  | needs_search_no_verified_identifier |  |
| W1146 | Research on System-Level Calibration and Alignment Methods for Laser Gyro Inertial Measurement Units. [Master’s Thesis, Harbin Institute of Technology] |  | needs_search_no_verified_identifier |  |
| W1147 | System-level calibration method for laser gyro SINS based on 36-dimensional Kalman filter |  | needs_search_no_verified_identifier |  |
| W1148 | A novel temperature error compensation method for accelerometers |  | needs_search_no_verified_identifier |  |
| W1149 | Research on Dithered Ring Laser Gyro Strapdown Inertial Navigation System and Its Real-Time Temperature Compensation Method. [Master’s Thesis, National University of Defense Technology] |  | needs_search_no_verified_identifier |  |
| W1150 | Modeling method for gyro temperature drift based on cross-validation |  | needs_search_no_verified_identifier |  |
| W1151 | Research on Key Technologies of Dual-Axis Rotating Inertial Navigation System with Dithered Ring Laser Gyro. [Ph.D. Thesis, National University of Defense Technology] |  | needs_search_no_verified_identifier |  |
| W1152 | Temperature drift modelling and compensation for a dynamically tuned gyroscope by combining WT and SVM method | 10.1088/0957-0233/18/5/030 | fulltext_unavailable_from_checked_sources |  |
| W1153 | Calibration method for temperature model parameters of accelerometer assembly under cold start |  | needs_search_no_verified_identifier |  |
| W1154 | Multi-position continuous rotate-stop fast temperature parameters estimation method of flexible pendulum accelerometer triads | 10.1016/j.measurement.2020.108372 | fulltext_unavailable_from_checked_sources |  |
| W1155 | A system-level calibration method for INS: Simultaneous compensation of accelerometer asymmetric errors and second-order temperature-related errors |  | needs_search_no_verified_identifier |  |
| W1156 | Research on temperature compensation technology for hemispherical resonator gyro inertial navigation system |  | needs_search_no_verified_identifier |  |
| W1157 | Temperature compensation method for hemispherical resonator gyro in INS based on PSO algorithm |  | needs_search_no_verified_identifier |  |
| W1158 | MEMS IMU Error Mitigation Using Rotation Modulation Technique | 10.3390/s16122017 | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R1400_MEMS IMU Error Mitigation Using Rotation Modulation Technique.pdf |
| W1159 | Research on Initial Alignment and Self-Calibration of Rotary Strapdown Inertial Navigation Systems | 10.3390/s150203154 | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R1401_Research on Initial Alignment and Self-Calibration of Rotary Strapdown Inertial Navigation Systems.pdf |
| W1160 | A Combination Scheme of Pure Strapdown and Dual-Axis Rotation Inertial Navigation Systems | 10.3390/s23063091 | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R1402_A Combination Scheme of Pure Strapdown and Dual-Axis Rotation Inertial Navigation Systems.pdf |
| W1161 | Noise contributions in a closed-loop MEMS gyroscope for automotive applications | 10.1109/isiss.2017.7935674 | fulltext_unavailable_from_checked_sources |  |
| W1162 | MEMS for automotive and consumer electronics | 10.1109/isscc.2010.5434066 | fulltext_unavailable_from_checked_sources |  |
| W1163 | &lt;title&gt;Single-layer silicon-on-insulator MEMS gyroscope for wide dynamic range and harsh environment applications&lt;/title&gt; | 10.1117/12.443029 | fulltext_unavailable_from_checked_sources |  |
| W1164 | Error Analysis and Compensation of MEMS Rotation Modulation Inertial Navigation System | 10.1109/jsen.2018.2789884 | fulltext_unavailable_from_checked_sources |  |
| W1165 | A Nonlinear Observer for Attitude Estimation of Vehicle-Mounted Satcom-on-the-Move | 10.1109/jsen.2019.2918381 | fulltext_unavailable_from_checked_sources |  |
| W1166 | MEMS Gyroscope Bias Drift Self-Calibration Based on Noise-Suppressed Mode Reversal | 10.3390/mi10120823 | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R1408_MEMS Gyroscope Bias Drift Self-Calibration Based on Noise-Suppressed Mode Reversal.pdf |
| W1167 | Design of a 1-bit MEMS Gyroscope using the Model Predictive Control Approach | 10.3390/s19030730 | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R1409_Design of a 1-bit MEMS Gyroscope using the Model Predictive Control Approach.pdf |
| W1168 | A Mixed Deep Recurrent Neural Network for MEMS Gyroscope Noise Suppressing | 10.3390/electronics8020181 | fulltext_unavailable_from_checked_sources |  |
| W1169 | Performance Analysis of a Deep Simple Recurrent Unit Recurrent Neural Network (SRU-RNN) in MEMS Gyroscope De-Noising | 10.3390/s18124471 | downloaded_verified | D:/学习资料/资料/全角陀螺/引用文献_20261023/pdf/R1411_Performance Analysis of a Deep Simple Recurrent Unit Recurrent Neural Network _SRU-RNN_ in MEMS Gyroscope De-Noisin.pdf |
| W1170 | Fully integrated, 406 uA, 5 degree/hr, full digital output Lissajous frequency-modulated gyroscope |  | needs_search_no_verified_identifier |  |
