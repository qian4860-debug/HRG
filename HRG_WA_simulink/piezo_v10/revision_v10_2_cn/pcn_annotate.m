function pcn_annotate(mdl)
% 在SLX中写入可见中文注释和模块Description；不改信号连线/数值参数。
% 英文路径用于保持脚本稳定，中文阅读说明放在画布及属性中。
physical={'Mechanical_Head','Drive_Electronics','Piezo_Sensor_Port','Charge_Amplifier','Analog_Front_End'};
text={sprintf('机械表头｜二维二阶模态\n状态1:2为运动电荷r[C]，3:4为电荷速度[C/s]。\n刚度、阻尼可有不同主轴；角速度经科里奥利项耦合。\n输入是当前联合12维状态和DAC电压，不是独立机械力接口。'),...
 sprintf('驱动电子学｜双通道一阶带宽\n状态5:6为驱动器电压[V]。DAC输入为两路采样电压[V]。\n通道时间常数driver_tau及drive_matrix描述不一致与串扰。'),...
 sprintf('压电传感端口｜互易机电加载\n状态7:8为节点电压[V]。Cs、G0、Rs及运动电荷电流共同作用。\n端口电压回作用机械运动；不可把加载衰减率再次加到本征阻尼。'),...
 sprintf('电荷放大器｜积分及泄放\n状态9:10为输出电压[V]。Cf决定电荷/电压增益，Rf提供直流泄放。\n输出还需经过AFE，不能直接当作理想运动电荷。'),...
 sprintf('模拟前端AFE｜带宽及通道耦合\n状态11:12为ADC前电压[V]。afe_bw为Hz，内部乘2π换成角频率。\n检测矩阵包含两通道幅值不一致与串扰。')};
blocks=find_system(mdl,'SearchDepth',1,'BlockType','SubSystem');
for k=1:numel(physical)
 path=[mdl '/' physical{k}];
 if getSimulinkBlockHandle(path)>0
  set_param(path,'Description',text{k});note(path,[text{k} newline '离散更新：x_R[k+1]=Ad(R,:)*x[k]+Bd(R,:)*u[k]。' newline 'Unit Delay保存该组物理状态，不是额外接口延迟。'],[10 175]);
  set_param([path '/Joint_ZOH_A_rows'],'Description','联合归一化ZOH的对应状态行；保留采样间隔内所有跨模块耦合。');
  set_param([path '/Physical_State'],'Description','该组唯一状态存储；初值x0(R)，采样周期p.Ts[s]。');
 end
end
if contains(mdl,'modules')
 note(mdl,sprintf('中文教学模块库｜五组物理状态\n所有模块共同使用同一组Ad/Bd及当前状态。\n改变负载/带宽需重算联合矩阵，不能只换局部Ad。'),[350 80]);return
end
note(mdl,sprintf('压电全角陀螺｜中文注释版\n阅读顺序：机电状态 → AFE电压 → ADC采样 → 解调/标定/控制/DAC → 反馈。\nTs=25μs（40kHz），Tc=1ms（40点窗口）；当前数值均为合成参数。\n双击子系统逐层查看；本修订只增加说明，不改变原算法。'),[60 -110]);
path=[mdl '/Piezo_Head_and_Circuits'];
if getSimulinkBlockHandle(path)>0
 set_param(path,'Description','压电表头及电路的联合离散模型；五个库模块共12个状态，端口输出顺序见画布。');
 note(path,sprintf('联合状态顺序：[rX,rY,rdotX,rdotY,驱动X/Y,传感电压X/Y,CV输出X/Y,AFE输出X/Y]\n单位依次为C、C/s和V。DAC输入为两路电压[V]。\n反馈线传递当前12维状态；各模块同拍更新，没有新增接口延迟。\n注意：本征机械阻尼与电路加载分开建模，加载不能重复计入。'),[20 -115]);
end
path=[mdl '/ADC_Interface'];
if getSimulinkBlockHandle(path)>0
 note(path,sprintf('采样与量化接口\n输入：[AFE_X,AFE_Y]，单位V。输出：[量化X,量化Y,截幅X,截幅Y]。\n噪声先叠加再量化；正满量程最多为2^(N-1)-1码。\n噪声固定种子；重复Outputs求值不会重复推进随机流。'),[20 160]);
 set_param(path,'Description','输入噪声、ADC整数码量化与两路截幅标志；详见pcn_adc_sfun.m及pcn_quantize.m。');
end
path=[mdl '/Digital_Control_and_DAC'];
if getSimulinkBlockHandle(path)>0
 note(path,sprintf('数字控制状态机｜详见pcn_tick.m\n先输出上一状态对应DAC和诊断，再消费本拍ADC。\n40点累加 → 检测标定解嵌 → 能量/线性度/截幅判定 → 建幅PI/正交/PLL → 驱动标定与DAC。\ncenter为样本时刻均值；available=end+Ts。无效帧冻结积分并撤去控制力。\n输出1：两路DAC电压[V]；输出2：18维诊断。freq字段为rad/s，不是Hz。'),[20 175]);
 set_param(path,'Description','中文源码pcn_tick.m：完整窗口后统一更新控制，状态35维；数字算法没有额外拆分或改动。');
end
path=[mdl '/Instrumentation'];
if getSimulinkBlockHandle(path)>0
 note(path,sprintf('观察与记录｜不进入反馈计算\n先看Charge_C和各电压级，再看ADC、IQ、能量/线性度/有效性及时间戳。\nScope_PLL_Hz沿用旧名，实际数据为角频率rad/s；Hz=freq/(2π)。\nSpectrum观察X通道，单位dBV，采样率40kHz；可通过Selector切换Y。\nIQ为运动电荷[C]；诊断第6列E为电荷平方和[C²]，不是直接以J计的机械能。\n第10:13列：窗口起点、末点、中心、发布时间[s]；评分按源中心，每帧一次。'),[15 -155]);
 set_param(path,'Description','14个Scope、2个频谱仪和4组To Workspace；角度评分见pcn_metrics.m。');
end
end
function note(path,txt,pos)
a=Simulink.Annotation(path,txt);a.Position=pos;a.FontSize=11;
end
