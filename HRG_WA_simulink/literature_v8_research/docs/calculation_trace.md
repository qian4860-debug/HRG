# 可复算数值代入表

这些是假设算例。完整条件、推导和单位见主文；不得直接作为实测或流片指标。

|量|公式|代入|计算值|单位|
|---|---|---|---|---|
|omega|2*pi*f0|2*pi*5000|31415.92654|rad/s|
|gamma|omega/(2*Q)|31415.9265/(2*2000000)|0.007853981634|1/s|
|modal_stiffness|m*omega^2|1e-6*(31415.9265)^2|986.9604401|N/m|
|mechanical_energy|m*omega^2*A^2/2|1e-6*31415.9265^2*(1e-7)^2/2|4.934802201e-12|J|
|hold_force|m*omega^2*A/Q|986.96044*1e-7/2000000|4.934802201e-11|N|
|hold_voltage|Fhold/kF|4.9348022005446795e-11/1e-7|0.0004934802201|V|
|ideal_resonant_start_force|2*m*omega*gamma*A/(1-exp(-gamma*tb))|2*1e-6*31415.926535897932*0.007853981633974483*1e-7/(1-exp(-0.007853981633974483*0.1))|6.285653031e-08|N|
|ideal_start_voltage|Fstart/kF|6.285653031261904e-08/1e-7|0.6285653031|V|
|capacitance_half_difference|C0*A/g|1e-12*1e-7/5e-6|2e-14|F|
|sense_current|Vb*omega*Cpk|10*31415.926535897932*1.9999999999999997e-14|6.283185307e-09|A|
|ADC_peak_voltage|Ipk*abs(Zf)*G*abs(Hafe)|6.283185307179586e-09*31814875.094938613*1*0.9374768850453477|0.1874004629|V peak|
|total_input_noise_allowance|2*B*Vpk*sigma_psi/sqrt(2*Be)|2*0.277*0.18740046286145592*1e-6/sqrt(200)|7.34117245e-09|V/sqrt(Hz)|
|AFE_noise_at_ADC|sqrt((NG*en)^2+\|Z\|^2*(in^2+4*kT/Rf))*G*\|Hafe\||3.439252806349058e-07*0.9374768850453477|3.224220008e-07|V/sqrt(Hz)|
|ADC_quantizer_ASD|(2*VFS/2^N)/sqrt(6*fs)|(4/2^18)/sqrt(6*40000)|3.114687275e-08|V/sqrt(Hz)|
|ADC_white_angle_RMS|Delta/(2*B*Vpk)*sqrt(Be/(3*fs))|(4/2^18)/(2*0.277*0.18740046286145592)*sqrt(100/120000)|4.242765438e-06|rad|
|ideal_ADC_bits_for_full_noise_allowance|ceil(log2(2*VFS/(2*B*Vpk*sigma)*sqrt(Be/(3*fs))))|ceil(log2(4/(2*0.277*0.18740046286145592*1e-6)*sqrt(100/120000)))|21|ideal bits|
|peak_differential_gain_residual|4*B*psi_peak|4*.277*1e-6|1.108e-06|relative|
|damping_lock_threshold|abs(dgamma)/(4*B)|0.00025/(4*.277)*180/pi*3600|46.53989311|deg/h|
|digital_chain_ENBW|fsADC/2 * sum(h_equivalent^2)|40000/2 * 0.005416907817322533|108.3381563|Hz; full-window white demodulated input|
|chain_group_delay|CIC+FIR+registers+converters|0.0014625+0.002+0.004+0.0000625|0.007525|s|
|delay_30deg_crossover_bound|1/(12*tau)|1/(12*0.0075250000000000004)|11.07419712|Hz|
|energy_Kp|zeta*wn/E0|.8*(2*pi*.8)/1|4.021238597|1/s|
|energy_Ki|wn^2/(2*E0)|(2*pi*.8)^2/2|12.63309363|1/s^2|
|energy_crossover|sqrt((a^2+sqrt(a^4+4*b^2))/2)|a=8.042477193189871,b=25.266187266788755|1.363364131|Hz|
|energy_PI_delay_phase_margin|90deg-atan(Ki/(Kp*wc))-wc*tau|90-atan(12.633093633394378/(4.0212385965949355*8.566269476511517))*180/pi-8.566269476511517*0.0075250000000000004*180/pi|66.16664547|deg; low-frequency approximation|
|third_harmonic_at_ADC|rho^2/4 * \|3Z(3w)H(3w)/(Z(w)H(w))\||.02^2/4*0.6558601008269281|6.558601008e-05|relative peak, cubic approximation|
|third_harmonic_voltage|V1*ratio3|0.18740046286145592*6.558601008269281e-05|1.229084865e-05|V peak|
|DAC_hold_peak_codes|Vhold/(2*VFS/2^N)|0.0004934802200544679/(4/2^16)|8.085179925|codes|
|AFE_equivalent_angle_RMS|eAFE*sqrt(2*Be)/(2*B*Vpk)|3.224220007779585e-07*sqrt(200)/(2*0.277*0.18740046286145592)|4.391968762e-05|rad; approximate white narrowband|
|input_current_full_allowance|e_allow/(\|Z\|*G*\|Hafe\|)|7.341172450010561e-09/(31814875.094938613*0.9374768850453477)|2.461357148e-16|A/sqrt(Hz); all noise assigned to current alone|
|Rf_thermal_lower_bound|4*kT/i_allow^2|4*4.1164049935e-21/(2.4613571477397353e-16)^2|2.717870859e+11|ohm; noise bound only, not practical R selection|
|RK4_numerical_damping_fraction|-fs*ln(abs(P4(j*w/fs)))/gamma|-800000*ln(abs(P4(j*31415.926535897932/800000)))/0.007853981633974483|0.00259367025|relative; ideal undamped carrier|
