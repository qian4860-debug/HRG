function z=a4_prepare_plant(p,omega)
% Ω按声明的三段常值更新，真实进入科氏矩阵；源角只进入评分。
z.omega=omega(:)';[~,~,z.x0]=pcn_plant(p);N=round(p.duration/p.Ts)+1;
z.segment=min(numel(omega),floor((0:N-1)'/(p.duration/p.Ts)*numel(omega))+1);
for j=1:numel(omega)
 q=p;q.Omega=omega(j);[z.Ad(:,:,j),z.Bd(:,:,j),~,z.A(:,:,j),z.B(:,:,j)]=pcn_plant(q);
end
rng=RandStream('mt19937ar','Seed',p.noise_seed);z.noise=p.noise_rms_V*randn(rng,N,2);
end
