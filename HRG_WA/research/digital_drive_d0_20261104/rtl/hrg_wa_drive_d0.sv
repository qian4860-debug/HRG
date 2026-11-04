`timescale 1ns/1ps
// D0：三个慢控制量 -> 双轴载波DAC。所有输入/输出合同见 interface_v0.json。
// 独立研究模块，尚未接入旧顶层。NCO相位和sin/cos由外部共享时基提供。
module hrg_wa_drive_d0 #(parameter integer MAX_AGE_SAMPLES=80)(
 input wire clk, input wire rst,
 input wire cmd_update, input wire cmd_enable, input wire calibration_valid,
 input wire [31:0] cmd_id, input wire [31:0] cmd_source_sample,
 input wire signed [19:0] force_energy,force_quad,force_virtual,
 input wire signed [17:0] direction_x,direction_y,
 // 8个Q4.16系数，低位在前：Re(M00,M01,M10,M11), Im(M00,M01,M10,M11)
 input wire [159:0] inverse_drive_matrix,
 input wire sample_en, input wire [31:0] sample_id,
 input wire signed [17:0] carrier_cos,carrier_sin,
 output reg dac_valid, output reg drive_active,
 output reg signed [17:0] dac_x,dac_y,
 output reg clip_x,clip_y,
 output reg [31:0] applied_cmd_id,applied_sample_id,command_age
);
 reg have,enabled,cal_ok;
 reg [31:0] source_q,id_q;
 reg signed [19:0] e_q,q_q,v_q,m_q[0:7];
 reg signed [17:0] ex_q,ey_q;
 longint signed e,q,v,ex,ey,fc0,fc1,fs0,fs1,vr0,vr1,vi0,vi1;
 longint signed m[0:7],cs,sn,dx,dy;
 reg [31:0] age;
 integer j;
 // 每个指定边界采用最近舍入，恰好半LSB时远离0；64位累加不回绕。
 function automatic signed [63:0] rounded(input signed [63:0] value,input integer shift);
  reg signed [63:0] bias;
  begin
   bias=64'sd1 << (shift-1);
   if(value<0) rounded=-((-value+bias) >>> shift);
   else rounded=(value+bias) >>> shift;
  end
 endfunction
 function automatic signed [17:0] saturated(input signed [63:0] value);
  begin
   if(value>131071) saturated=18'sd131071;
   else if(value< -131072) saturated=-18'sd131072;
   else saturated=value[17:0];
  end
 endfunction
 always @(posedge clk) begin
  if(rst) begin
   have<=0;enabled<=0;cal_ok<=0;source_q<=0;id_q<=0;
   e_q<=0;q_q<=0;v_q<=0;ex_q<=0;ey_q<=0;
   for(j=0;j<8;j=j+1)m_q[j]<=0;
   dac_valid<=0;drive_active<=0;dac_x<=0;dac_y<=0;clip_x<=0;clip_y<=0;
   applied_cmd_id<=0;applied_sample_id<=0;command_age<=0;
  end else begin
   dac_valid<=sample_en;
   // 同一时钟既更新命令又输出样本时，样本使用旧命令；下次样本才使用新命令。
   if(cmd_update) begin
    have<=1;enabled<=cmd_enable;cal_ok<=calibration_valid;source_q<=cmd_source_sample;id_q<=cmd_id;
    e_q<=force_energy;q_q<=force_quad;v_q<=force_virtual;ex_q<=direction_x;ey_q<=direction_y;
    for(j=0;j<8;j=j+1)m_q[j]<=inverse_drive_matrix[j*20+:20];
   end
   if(sample_en) begin
    age=sample_id-source_q;
    applied_cmd_id<=id_q;applied_sample_id<=sample_id;command_age<=age;
    drive_active<=have && enabled && cal_ok && age<=MAX_AGE_SAMPLES;
    dac_x<=0;dac_y<=0;clip_x<=0;clip_y<=0;
    if(have && enabled && cal_ok && age<=MAX_AGE_SAMPLES) begin
     e=e_q;q=q_q;v=v_q;ex=ex_q;ey=ey_q;cs=carrier_cos;sn=carrier_sin;
     for(j=0;j<8;j=j+1)m[j]=m_q[j];
     // n=[-ey,ex]，Fc=Q*n，Fs=-E*e-V*n，F=Fc-j*Fs。
     fc0=rounded(-q*ey,16);fc1=rounded(q*ex,16);
     fs0=rounded(-e*ex+v*ey,16);fs1=rounded(-e*ey-v*ex,16);
     // V=M*F；电路标定通过完整复2x2矩阵补偿，不只做通道增益。
     vr0=rounded(m[0]*fc0+m[1]*fc1+m[4]*fs0+m[5]*fs1,16);
     vr1=rounded(m[2]*fc0+m[3]*fc1+m[6]*fs0+m[7]*fs1,16);
     vi0=rounded(m[4]*fc0+m[5]*fc1-m[0]*fs0-m[1]*fs1,16);
     vi1=rounded(m[6]*fc0+m[7]*fc1-m[2]*fs0-m[3]*fs1,16);
     // Q16电压系数 * Q16载波 -> Q17 DAC码，只舍入一次到DAC LSB。
     dx=rounded(vr0*cs-vi0*sn,15);dy=rounded(vr1*cs-vi1*sn,15);
     dac_x<=saturated(dx);dac_y<=saturated(dy);
     clip_x<=dx>131071 || dx< -131072;clip_y<=dy>131071 || dy< -131072;
    end
   end
  end
 end
endmodule
