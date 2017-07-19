function [Kb,Pbmax,C0]  = pwCostFunc(Pmin,Pmax,CostA,CostB,CostC,B)
%% get parameters [Kb,Pbmax] for piecewise cost function
% Kb      BxNg    slope of piecewise linear cost function
% Pbmax   BxNg    (b,g): maximum output of the bth block for unit g
% C0      1xNg    cost at Pmin
% Pmax    1xNg    unit maximum output   
% Pmin    1xNg    unit minimum output
% CostA   1xNg    cost coefficient
% CostB   1xNg    cost coefficient
% CostC   1xNg    cost coefficient
% B       1x1     number of blocks
Ng = length(Pmin);
Pbmax = (Pmax-Pmin)./B;
Pbmax = ones(B,Ng)*diag(Pbmax);
P     = [Pmin; Pmin+diag(1:B)*ones(B,Ng).*Pbmax];
Cost  = ones(B+1,Ng)*diag(CostA).*P.*P + ones(B+1,Ng)*diag(CostB).*P + ones(B+1,Ng)*diag(CostC);
C0    = Cost(1,:);
dCost = Cost(2:end,:) - Cost(1:end-1,:);
Kb    = dCost./Pbmax;