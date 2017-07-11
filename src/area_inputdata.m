%area_inputData
clear all;
areaFile ='data\testcase\areadata';
T           = 24;               %% time horizons
TD          = 1;
Td0         = [1,25];           %% 
Ng          = 4;                %% number of units
Ntie        = 1;                %% number of tie lines
Narea       = 1;                %% number of neighbor areas
Nw          = 1;                %% number of wind farms
Nd          = 1;                %% number of demand buses
Nb          = 6;                %% number of buses
Nl          = 7;                %% number of lines  
slack       = 1;                %% slack bus
%%------------------------ 机组  ---------------------------------
Pmax        = xlsread(areaFile,2,['C2:C' num2str(Ng+1)])';            %% 1xNg    unit maximum output   
Pmin        = xlsread(areaFile,2,['D2:D' num2str(Ng+1)])';            %% 1xNg    unit minimum output
Rampup      = xlsread(areaFile,2,['E2:E' num2str(Ng+1)])';            %% 1xNg    unit ramping up rates
Rampdown    = xlsread(areaFile,2,['F2:F' num2str(Ng+1)])';            %% 1xNg    unit ramping down rates
Minup       = xlsread(areaFile,2,['G2:G' num2str(Ng+1)])';            %% 1xNg    unit minimun up time
Mindown     = xlsread(areaFile,2,['H2:H' num2str(Ng+1)])';            %% 1xNg    unit minimum dowm time
Onoff_t0    = xlsread(areaFile,2,['I2:I' num2str(Ng+1)])';            %% 1xNg    initial status at t=0
Pg_t0       = xlsread(areaFile,2,['J2:J' num2str(Ng+1)])';            %% 1xNg    initial output at t=0
On_t0       = xlsread(areaFile,2,['K2:K' num2str(Ng+1)])';            %% 1xNg    length of time unit g has to be on at the beginning
Off_t0      = xlsread(areaFile,2,['L2:L' num2str(Ng+1)])';            %% 1xNg    length of time unit g has to be off at the beginning
CostA       = xlsread(areaFile,2,['M2:M' num2str(Ng+1)])';            %% 1xNg    cost coefficient
CostB       = xlsread(areaFile,2,['N2:N' num2str(Ng+1)])';            %% 1xNg    cost coefficient
CostC       = xlsread(areaFile,2,['O2:O' num2str(Ng+1)])';            %% 1xNg    cost coefficient
CostUp      = xlsread(areaFile,2,['P2:P' num2str(Ng+1)])';            %% 1xNg    startup cost
CostDn      = xlsread(areaFile,2,['Q2:Q' num2str(Ng+1)])';            %% 1xNg    shut-down cost
Gen_Bus     = xlsread(areaFile,2,['B2:B' num2str(Ng+1)])';      
%
G_map=zeros(Ng,Nb);
for g=1:Ng
    G_map(g,Gen_Bus(g)) = 1;            %% NgxNb   map(i,j)= 1 if generator i at bus j; 0 else  
end
%
%%----------------------------- 负荷 --------------------------------------
Demand_Bus  = xlsread(areaFile,3,['B2:B' num2str(Nd+1)])';
Demand      = xlsread(areaFile,3,'C2:Z2')';            %% TxNd    demand  
D_map       = zeros(Nd,Nb);             %% NdxNb   map(i,j)= 1 if demand i at bus j; 0 else   
for g=1:Nd
    D_map(g,Demand_Bus(g)) = 1;
end
%%----------------------------- 风电 --------------------------------------
Wind_Bus    = xlsread(areaFile,4,['B2:B' num2str(Nw+1)])';
Windmax     = xlsread(areaFile,4,'C2:Z2')';           %% TxNw    theory output of wind power
W_map       = zeros(Nw,Nb);             %% NdxNb   map(i,j)= 1 if wind farm i at bus j; 0 else  
for g=1:Nw
    W_map(g,Wind_Bus(g)) = 1;
end
%%------------------------------ 线路 -------------------------------------
flmax       = xlsread(areaFile,1,['E2:E' num2str(Nl+1)])';             %% 1xNl     transmission limit;
lineX       = xlsread(areaFile,1,['D2:D' num2str(Nl+1)])';             %% 1xNl
line_Bus    = xlsread(areaFile,1,['B2:C' num2str(Nl+1)])';             %% 2xNl
H           = getPTDF(Nb, line_Bus, lineX, slack);                 %% NlxNb    power transmission distribution factor

%%----------------------------- 联络线 ------------------------------------
Tie_Bus     = xlsread(areaFile,5,['B2:B' num2str(Ntie+1)])';           %% 1xNtie    
TieArea     = xlsread(areaFile,5,['C2:C' num2str(Ntie+1)])';           %% 1xNtie    connnected area
TieBus      = xlsread(areaFile,5,['D2:D' num2str(Ntie+1)])';             %% 1xNtie    connected bus
TieMax      = xlsread(areaFile,5,['E2:E' num2str(Ntie+1)])';             %% 1xNtie    transmission capacity
Tie_map     = zeros(Ntie,Nb);             %% NtiexNb   map(i,j)= 1 if tieline i connnected at bus j; 0 else
Tie_Area    = zeros(Ntie,Narea);          %% NtiexNarea  (i,j)=  1 if tie i connnected area j; 0 else
for g=1:Ntie
    Tie_map(g,Tie_Bus(g)) = 1;
    Tie_Area(g, TieArea(g)) = 1;
end
%%--------------------------- 联络线计划 -----------------------------------
FtieArea    = xlsread(areaFile,6,['B2:B' num2str(Narea+1)])';           %% 1xNarea    connected area
FtieMax     = xlsread(areaFile,6,['C2:C' num2str(Narea+1)])';             %% 1xNarea    max
FtieMin     = xlsread(areaFile,6,['D2:D' num2str(Narea+1)])';            %% 1xNarea    min
FtieRU      = xlsread(areaFile,6,['E2:E' num2str(Narea+1)])';             %% 1xNarea    ramp up
FtieRD      = xlsread(areaFile,6,['F2:F' num2str(Narea+1)])';             %% 1xNarea    ramp down
FtieEgy     = xlsread(areaFile,6,['G2:G' num2str(Narea+1)])';              %% TDxNarea    energy constraint

%%----------------------------- 备用 --------------------------------------
ReserveUp   = xlsread(areaFile,7,'B1:Y1')';          %% up reserve
ReserveDn   = xlsread(areaFile,7,'B2:Y2')';         %% dowen reserve
%% save data
save case_data.mat