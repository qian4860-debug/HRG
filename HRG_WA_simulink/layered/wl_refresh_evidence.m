function wl_refresh_evidence()
% Re-export short native-rate carrier windows without waveform aliasing.
for stage=2:6
 c=wl_config(stage);c.duration=.3;
 [out,c]=wl_sim(c,false);wl_save_evidence(out,c,sprintf('v%d_nominal',stage));
 close_system(c.name,0);
end
end
