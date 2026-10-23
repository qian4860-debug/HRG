function g=w7_switches(t,c)
% Clocked D -> unload -> read -> unload; [drive, read, unload, valid].
if strcmp(c.v7.tdmMode,'continuous'),g=[1;1;0;1];return;end
N=round(c.fsPlant/c.head.f0);edges=cumsum(c.v7.slotCycles(:))*N;
k=mod(round(t*c.fsPlant),edges(end));
d=k<edges(1);r=k>=edges(2)&&k<edges(3);
valid=r&&k>=edges(2)+round(c.v7.readBlankCycles*N);
g=double([d;r;~d&&~r;valid]);
end
