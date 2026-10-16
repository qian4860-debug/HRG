`timescale 1ns/1ps
module hrg_controller (
    input wire clk,nrst,update_i,
    input wire [4:0] ctrl_i,
    input wire signed [31:0] energy_i,quad_i,energy_ref_i,
    input wire signed [31:0] energy_kp_i,energy_ki_i,quad_kp_i,quad_ki_i,
    input wire signed [27:0] virtual_cmd_i,
    output reg signed [27:0] energy_cmd_o,quad_cmd_o,virtual_cmd_o,
    output reg command_valid_o,limit_event_o,
    input wire [1:0] mode_i,
    input wire run_entry_i,tracking_valid_i,
    input wire signed [27:0] energy_actual_i,quad_actual_i,
    input wire signed [27:0] energy_delivered_i,quad_delivered_i,
    input wire signed [27:0] energy_hold_i,quad_hold_i
);
    localparam signed [39:0] I_LIMIT=40'sd1610612736;
    localparam signed [63:0] E_LIMIT=64'sd590558003,Q_LIMIT=64'sd483183821;
    reg signed [39:0] energy_int,quad_int;
    reg signed [27:0] previous_e,previous_q;
    reg signed [27:0] e_pipe[0:2],q_pipe[0:2],v_pipe[0:2];
    reg signed [39:0] e_initial,q_initial;
    wire signed [39:0] e_next,q_next;
    wire signed [63:0] e_raw,q_raw;
    wire e_limit,q_limit;
    wire signed [63:0] e_err=$signed({energy_ref_i[31],energy_ref_i})-$signed({energy_i[31],energy_i});
    wire signed [63:0] q_err=-$signed({quad_i[31],quad_i});
    reg signed [63:0] target_e,target_q,limited_e,limited_q,initial_command_e,initial_command_q;
    reg signed [39:0] final_e,final_q;
    reg e_pi_active,q_pi_active;
    integer i;
    function signed [63:0] nearest;
        input signed [127:0] n,d;
        reg signed [127:0] a,b;
        begin a=n<0 ? -n:n;b=d<0 ? -d:d;
            if(d==0) nearest=0;
            else nearest=((n<0)!=(d<0)) ? -((a+b/2)/b):((a+b/2)/b);
        end
    endfunction
    function signed [39:0] i_clip;
        input signed [63:0] n;
        begin i_clip=n>I_LIMIT ? I_LIMIT:(n< -I_LIMIT ? -I_LIMIT:n);end
    endfunction
    function signed [63:0] clip;
        input signed [63:0] n,lim;
        begin clip=n>lim ? lim:(n< -lim ? -lim:n);end
    endfunction
    function signed [39:0] tracking;
        input signed [39:0] state;
        input signed [63:0] actual,delivered;
        input signed [31:0] ki;
        begin tracking=i_clip($signed(state)+nearest((actual-delivered)*128'sd655360, $signed(ki)*128'sd1000));end
    endfunction
    always @* begin
        e_initial=energy_int;q_initial=quad_int;
        if(tracking_valid_i) begin
            e_initial=tracking(energy_int,$signed(energy_actual_i)*64'sd256,$signed(energy_delivered_i)*64'sd256,energy_ki_i);
            q_initial=tracking(quad_int,$signed(quad_actual_i)*64'sd256,$signed(quad_delivered_i)*64'sd256,quad_ki_i);
        end
        if(run_entry_i) begin
            e_initial=i_clip(nearest($signed(energy_hold_i)*128'sd16777216,energy_ki_i));
            q_initial=i_clip(nearest($signed(quad_hold_i)*128'sd16777216,quad_ki_i));
        end
    end
    hrg_pi_aw e_pi(e_err,e_initial,energy_kp_i,energy_ki_i,I_LIMIT,E_LIMIT,16'd3,e_next,e_raw,e_limit);
    hrg_pi_aw q_pi(q_err,q_initial,quad_kp_i,quad_ki_i,I_LIMIT,Q_LIMIT,16'd8,q_next,q_raw,q_limit);
    always @* begin
        target_e=e_raw;target_q=q_raw;e_pi_active=1;q_pi_active=1;
        if(mode_i==1) begin target_e=64'sd375809638;target_q=0;e_pi_active=0;q_pi_active=0;end
        if(mode_i==2 && e_err>1342177) begin target_e=E_LIMIT;e_pi_active=0;end
        if(mode_i==2 && e_err< -1342177) begin target_e=-E_LIMIT;e_pi_active=0;end
        if(!ctrl_i[0] || !ctrl_i[1] || mode_i==0) begin target_e=0;e_pi_active=0;end
        if(!ctrl_i[0] || !ctrl_i[2] || mode_i==0) begin target_q=0;q_pi_active=0;end
        initial_command_e=nearest(target_e,256);initial_command_q=nearest(target_q,256);
        if(run_entry_i) begin
            initial_command_e=nearest(clip(nearest(e_err*$signed(energy_kp_i),1024)+nearest($signed(e_initial)*$signed(energy_ki_i),65536),E_LIMIT),256);
            initial_command_q=nearest(clip(nearest(q_err*$signed(quad_kp_i),1024)+nearest($signed(q_initial)*$signed(quad_ki_i),65536),Q_LIMIT),256);
        end
        limited_e=$signed(previous_e)+clip(initial_command_e-$signed(previous_e),8389);
        limited_q=$signed(previous_q)+clip(initial_command_q-$signed(previous_q),16777);
        if(run_entry_i) begin limited_e=initial_command_e;limited_q=initial_command_q;end
        if(!ctrl_i[0] || !ctrl_i[1] || mode_i==0) limited_e=0;
        if(!ctrl_i[0] || !ctrl_i[2] || mode_i==0) limited_q=0;
        final_e=e_pi_active ? e_next:e_initial;final_q=q_pi_active ? q_next:q_initial;
        if(e_pi_active && limited_e!=initial_command_e) final_e=tracking(final_e,limited_e*256,initial_command_e*256,energy_ki_i);
        if(q_pi_active && limited_q!=initial_command_q) final_q=tracking(final_q,limited_q*256,initial_command_q*256,quad_ki_i);
        if(!ctrl_i[0] || !ctrl_i[1] || mode_i==0) final_e=0;
        if(!ctrl_i[0] || !ctrl_i[2] || mode_i==0) final_q=0;
    end
    always @(posedge clk or negedge nrst) begin
        if(!nrst) begin
            energy_int<=0;quad_int<=0;previous_e<=0;previous_q<=0;
            energy_cmd_o<=0;quad_cmd_o<=0;virtual_cmd_o<=0;command_valid_o<=0;limit_event_o<=0;
            for(i=0;i<3;i=i+1) begin e_pipe[i]<=0;q_pipe[i]<=0;v_pipe[i]<=0;end
        end else begin
            command_valid_o<=0;limit_event_o<=0;
            if(update_i) begin
                energy_int<=final_e;quad_int<=final_q;previous_e<=limited_e;previous_q<=limited_q;
                e_pipe[0]<=limited_e;q_pipe[0]<=limited_q;
                v_pipe[0]<=(ctrl_i[0] && ctrl_i[3] && mode_i!=0) ? virtual_cmd_i:28'sd0;
                for(i=1;i<3;i=i+1) begin e_pipe[i]<=e_pipe[i-1];q_pipe[i]<=q_pipe[i-1];v_pipe[i]<=v_pipe[i-1];end
                energy_cmd_o<=e_pipe[2];quad_cmd_o<=q_pipe[2];virtual_cmd_o<=v_pipe[2];
                if(run_entry_i) begin
                    for(i=0;i<3;i=i+1) begin e_pipe[i]<=limited_e;q_pipe[i]<=limited_q;end
                    energy_cmd_o<=limited_e;quad_cmd_o<=limited_q;
                end
                // Disable flushes pending commands immediately on the next control update.
                if(!ctrl_i[0] || mode_i==0) begin
                    for(i=0;i<3;i=i+1) begin e_pipe[i]<=0;q_pipe[i]<=0;v_pipe[i]<=0;end
                    energy_cmd_o<=0;quad_cmd_o<=0;virtual_cmd_o<=0;
                end
                limit_event_o<=(e_pi_active && e_limit)||(q_pi_active && q_limit)||limited_e!=initial_command_e||limited_q!=initial_command_q;
                command_valid_o<=1;
            end
        end
    end
endmodule
