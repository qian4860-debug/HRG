function comp_describe(mdl)
% 只更新研究模型的中文说明，防止继承旧模型“仅注释改动”的误导文字。
handles=find_system(mdl,'FindAll','on','Type','annotation');
for k=1:numel(handles)
 obj=get_param(handles(k),'Object');s=obj.Text;
 if contains(s,'本修订只增加说明，不改变原算法')
  obj.Text=strrep(s,'本修订只增加说明，不改变原算法','本模型为补偿研究分支：独立再标定、因果方向预测及辨识张量前馈。');
 end
end
set_param([mdl '/Digital_Control_and_DAC'],'Description','补偿研究内核comp_tick：从有效测量开始因果方向预测，首帧前零力；独立辨识ΔK/ΔD前馈。控制不读取真实Omega或机械各向异性真值。');
set_param([mdl '/Digital_Control_and_DAC/Validated_Kernel'],'Description','comp_sfun调用comp_tick，35维状态不变；前馈为(identified_dK+jω identified_dD)*(I-jQ)，主轴固定在表头坐标。');
set_param(mdl,'Description','条件性补偿研究：合成独立校准参考，原门限不变；20/21研究点通过不等于硬件或全工作范围认证。');
end
