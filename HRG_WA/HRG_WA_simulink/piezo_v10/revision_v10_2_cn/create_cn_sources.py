"""Create isolated Chinese teaching sources; never edits accepted releases."""
from pathlib import Path
import hashlib,json
HERE=Path(__file__).resolve().parent;OLD=HERE.parent/'revision_v10_1';MOD=HERE.parent/'revision_v10_2'
NOTES={
'config':'参数入口：全部为合成表头参数，不是实测或厂家额定值。\nf0为Hz；gamma_intrinsic为1/s；Cs/Cf为F；G0为S；Rs/Rf为Ω。\nB为Bryan系数，Omega为输入机体角速度rad/s；theta0为初始模态方向rad。\nTs为载波采样周期，Tc为解调周期；Tc/Ts必须是整数。\ncharge_target为目标运动电荷C；vmax为合成限幅V。\n驱动/检测矩阵为2×2，含两通道不一致与交叉耦合。\nvirtual_rate为附加模态进动率；实际启用取决于建幅门控。',
'plant':'机电联合状态方程与精确零阶保持离散化。\n输入p：物理/电路配置。输出Ad、Bd：一拍状态转移；x0：初始状态。\nx(1:2)=运动电荷r[C]；x(3:4)=电荷速度[C/s]；x(5:6)=驱动器电压[V]。\nx(7:8)=传感端口电压[V]；x(9:10)=电荷放大器电压[V]；x(11:12)=AFE电压[V]。\n连续模型xdot=A*x+B*u；离散模型x[k+1]=Ad*x[k]+Bd*u[k]。\n机械本征阻尼不含传感电路加载；加载通过显式端口状态回作用。\n先按特征电荷/电压归一化再expm，防止量纲悬殊引入虚假低速漂移。',
'tick':'数字闭环每拍状态机：先输出旧状态对应的u/d，再消费本拍ADC。\nadc=[X电压;Y电压;X截幅;Y截幅]，电压为V。\n相位为rad，freq字段实际为角频率rad/s，IQ为解嵌后的运动电荷C。\nFc/Fs为电荷加速度的余弦/正弦系数；复数约定F=Fc-j*Fs。\n40点窗口完整后才更新IQ与控制；center为输入采样时刻均值。\navailable=end+Ts；本拍完成的新结果到下一拍Outputs才发布。\n算法不读取真值；heading预测只使用相邻有效测量。\n诊断18列依次为Ix,Iy,Qx,Qy,角频率,E,线性度,有效,id,start,end,center,available,DAC截幅累计,ADC截幅,Cp,帧龄,帧DAC截幅。',
'state':'控制状态的35维数值打包/解包，供Simulink DWork保存。\n1相位；2角频率；3:4/5:6混频累加；7窗口点数；8:9 Fc；10:11 Fs。\n12建幅积分；13:14 I；15:16 Q；17截幅累计；18拍号；19窗口起点；20时间和。\n21:24窗口start/end/center/available；25能量；26线性度；27有效；28帧号。\n29窗口ADC截幅；30上一帧ADC截幅；31已施加Cp；32窗口有限性。\n33上一帧DAC截幅；34窗口DAC截幅；35模态方向估计率。\n初始化IQ为零且无效，时间戳NaN；启动驱动沿固定X方向，不偷用真值方向。',
'validity':'角度有效性：能量足够且驻波接近直线时才可观。\nE=Ix²+Iy²+Qx²+Qy²；N=Ix²+Qx²-Iy²-Qy²；M=2(IxIy+QxQy)。\nlinearity=sqrt(N²+M²)/E：理想直线约1，圆振动约0。\npattern_angle=atan2(M,N)/4为物理驻波角β，模态方向θ=2β。\n零信号、圆振动、截幅、非有限值或病态标定都不能输出有效零角。',
'quantize':'有符号midtread ADC/DAC量化器。\nspan为总电压跨度V；bits为位宽；limit为对称物理限幅V。\n合法整数码[-2^(bits-1),2^(bits-1)-1]，正负满量程不对称。\n先在整数域与物理上下界求交，再舍入饱和，最后乘LSB恢复电压。\nclipped同时覆盖整数溢出和物理输入越界；不能把截幅误差当白量化噪声。',
'reference':'MATLAB逐拍参考：用于核对Simulink接线和执行顺序。\nplant_p可与控制器p不同，以测试辨识或温漂失配。\n每拍：取AFE输出、加已声明噪声、ADC量化、调用控制状态机、更新机电状态。\n随机流固定种子用于复现；该参考与Simulink共用tick，不构成独立算法正确性证明。',
'metrics':'按每个完整窗口的源中心时刻评分，每帧只计一次。\n断效区间之间不跨段unwrap，不根据真值选择偏置、延迟或分支。\n扣除实际施加的Cp历史积分，而不是扣除请求值。\n稳态评分取后40%时段；body角误差由驻波角误差除B得到。\n短确定性记录不用于声称ARW或真实零偏稳定性；未知B时不输出机体角精度。',
'calibration':'读取合成独立参考标定，复数2×2矩阵描述幅相及串扰。\ndetect将运动电荷映射到ADC电压；drive含驱动器和DAC零阶保持。\n控制时用矩阵左除解嵌，不能只校正通道标量增益。\n改变Ts必须重新标定，否则保持器的幅相校正失效。',
'sfun':'Simulink二级S函数适配层，执行内核在pcn_tick中。\nDWork保存35维控制状态；Outputs不消费新ADC，Update才提交新状态。\n此安排保证输入不直接贯通到输出，窗口发布时刻为end+Ts。',
'adc_sfun':'ADC采样接口：两路AFE电压输入，输出两路量化电压和两路截幅标志。\n初始化预生成固定种子的白噪声序列，避免Outputs被重复求值时推进随机流。\n噪声在量化前进入真实反馈环，样本索引只在Update推进。',
'validate':'配置合同：检查时间、正值物理参数、整数窗口和被动阻尼。\nB未知仅允许静态测试；虚拟进动请求不得超过已验证范围。\n带标定时还检查Ts一致；不把配置错误静默修正为可运行数字。',
'json':'证据写出：UTF-8编码并统一换行，用于复现实验与文件哈希核查。',
'apply_profile':'把端口辨识的组合参数映射到配置。\n要求明确本征短路阻尼边界，防止把已加载ring-down阻尼重复计入。\n没有独立Bryan因子时保持未知并限制为静态工况；不虚构质量或额定电压。',
'temperature_apply':'离线温漂补偿：仅在辨识温区内插值，禁止外推。\n标量物理参数与复数双通道标定矩阵按已验证阶数拟合。\n参数来自合成留出数据；不代表真实温箱、温度梯度或滞回已验证。'
}
ANCHORS={
'plant':{'K=R(':'刚度张量：两特征频率在独立刚度主轴上旋转回测量坐标。','D=R(':'阻尼张量：本征平均衰减率与阻尼不均匀量独立于刚度主轴。','A(7:8,7:8)=':'传感节点KCL：静态电容、漏电、负载电导与运动电荷电流共同决定电压。','A(9:10,7:8)=':'电荷放大器积分及Rf泄放；随后为双通道AFE有限带宽。','S=diag(':'增广矩阵同时包含状态和输入；归一化后求指数再还原SI量纲。'},
'tick':{'t=s.k':'第一阶段：从旧控制状态生成本拍DAC；不使用尚未解调的新ADC。','age=t-':'判断上一测量帧是否已发布且未过期；valid不等价于算法已达到硬件精度。','s.sumI=':'同步混频：乘cos和sin并累加；系数2补偿正弦平均的1/2。','if s.count==':'第二阶段：完整窗口到达，统一更新解调、有效性与慢速控制。',' z=(s.sumI':'z=I-jQ的复相量约定；通过检测矩阵解嵌得到运动电荷。',' s.frame_start=':'三个时间不能混用：采样末点、窗口中心、下一拍可用时间。','  aa=sqrt':'建幅PI：用目标电荷减当前幅值，加入本征损耗前馈。','  if abs(rawf)':'条件积分抗饱和：饱和时仅允许能把控制量拉回范围的积分方向。','  s.cp=0;':'虚拟进动门控：建幅阶段不施加；保留实际命令供导航扣除。','  s.Fs=':'正弦力分量补能并施加切向虚拟进动；余弦分量抑制横向正交。','  detector=':'归一化相位检测器驱动角频率修正，并限制最大失谐。',' else':'无效帧时冻结积分、撤去控制力，避免把不可观角当真值继续闭环。','s.phase=mod':'最后推进本振和拍号；即使窗口未完成也逐拍推进。'},
'config':{"p=struct(":'物理端口与合成标识；所有实测替换应保留单位和边界。'," 'B',":'运动输入和两级时间尺度。'," 'Cf',":'电荷放大器及前端/驱动器时间常数。'," 'split_hz',":'任意刚度/阻尼主轴及两模态不一致。'," 'adc_span',":'量化码域、物理限幅和闭环增益。'," 'min_amplitude_fraction',":'角度可观性与标定条件数门限。'},
'metrics':{'d=r.d':'按帧号取首次发布样本，消除保持40拍造成的伪重复评分。','segments=':'每个有效片段单独解包驻波角。','cp=d(':'按实际Cp逐拍积分，并插值到源窗口中心。','hold=valid':'只对有效稳态帧计算误差，完整记录仍保留启动过程。'}
}
def main():
    (HERE/'evidence').mkdir(exist_ok=True);sources={}
    for key,note in NOTES.items():
        src=OLD/f'p101_{key}.m';sources[str(src.relative_to(HERE.parent))]=hashlib.sha256(src.read_bytes()).hexdigest()
        lines=src.read_text(encoding='utf-8').replace('p101_','pcn_').splitlines();out=[lines[0]]+['% '+s for s in note.splitlines()]
        for line in lines[1:]:
            for anchor,explain in ANCHORS.get(key,{}).items():
                if key=='config' and anchor!='p=struct(':continue # Do not interrupt MATLAB ... continuation.
                if line.startswith(anchor):out.append('% 【中文步骤】'+explain)
            out.append(line)
        (HERE/f'pcn_{key}.m').write_text('\n'.join(out)+'\n',encoding='utf-8',newline='\n')
    for n in ['calibration_profile.json','identified_multiload_profile.json','temperature_profile.json']:
        (HERE/'evidence'/n).write_bytes((OLD/'evidence'/n).read_bytes())
    for n in ['build','demo','verify']:
        src=MOD/f'p102_{n}.m';sources[str(src.relative_to(HERE.parent))]=hashlib.sha256(src.read_bytes()).hexdigest()
        s=src.read_text(encoding='utf-8').replace('p102_','p103_').replace('p101_','pcn_').replace('v10_2_','v10_2_cn_')
        s=s.replace('function mdl=p103_build(p,c,bench)','function mdl=p103_build(p,c,bench)\n% 中文注释版构建器：五组联合ZOH状态、采样接口、控制状态机与观察区。\n% bench=false构建整机；bench=true构建双频端口试验台；只写本注释目录。')
        s=s.replace('save_system(lib,','pcn_annotate(lib);save_system(lib,').replace("save_system(mdl,fullfile(folder,","pcn_annotate(mdl);save_system(mdl,fullfile(folder,")
        if n=='verify':
            s=s.replace('r=pcn_reference(q,c);',"addpath(fullfile(fileparts(root),'revision_v10_1'));r=p101_reference(q,c);")
        (HERE/f'p103_{n}.m').write_text(s,encoding='utf-8',newline='\n')
    (HERE/'evidence/source_hashes.json').write_text(json.dumps(sources,indent=2)+'\n',encoding='utf-8',newline='\n')
if __name__=='__main__':main()
