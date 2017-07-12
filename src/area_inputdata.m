%area_inputData
clear all;
xlsxFile ='data\testcase\areadata1.xlsx';
matFile = 'data\testcase\areadata1.mat';
noarea      = xlsread(xlsxFile,1,'B1:B1')';                %% area #
T           = xlsread(xlsxFile,1,'B2:B2')';               %% time horizons
TD          = xlsread(xlsxFile,1,'B3:B3')';
Td0         = xlsread(xlsxFile,1,'B4:C4')';           %% 
Ng          = xlsread(xlsxFile,1,'B5:B5')';                %% number of units
Ntie        = xlsread(xlsxFile,1,'B6:B6')';                %% number of tie lines
Narea       = xlsread(xlsxFile,1,'B7:B7')';                %% number of neighbor areas
Nw          = xlsread(xlsxFile,1,'B8:B8')';                %% number of wind farms
Nd          = xlsread(xlsxFile,1,'B9:B9')';                %% number of demand buses
Nb          = xlsread(xlsxFile,1,'B10:B10')';                %% number of buses
Nl          = xlsread(xlsxFile,1,'B11:B11')';                %% number of lines  
slack       = xlsread(xlsxFile,1,'B12:B12')';                %% slack bus
%%----------------------------- 惩罚因子 ----------------------------------
gamma = 1;
%%------------------------ 机组  ---------------------------------
Pmax        = xlsread(xlsxFile,3,['C2:C' num2str(Ng+1)])';            %% 1xNg    unit maximum output   
Pmin        = xlsread(xlsxFile,3,['D2:D' num2str(Ng+1)])';            %% 1xNg    unit minimum output
Rampup      = xlsread(xlsxFile,3,['E2:E' num2str(Ng+1)])';            %% 1xNg    unit ramping up rates
Rampdown    = xlsread(xlsxFile,3,['F2:F' num2str(Ng+1)])';            %% 1xNg    unit ramping down rates
Minup       = xlsread(xlsxFile,3,['G2:G' num2str(Ng+1)])';            %% 1xNg    unit minimun up time
Mindown     = xlsread(xlsxFile,3,['H2:H' num2str(Ng+1)])';            %% 1xNg    unit minimum dowm time
Onoff_t0    = xlsread(xlsxFile,3,['I2:I' num2str(Ng+1)])';            %% 1xNg    initial status at t=0
Pg_t0       = xlsread(xlsxFile,3,['J2:J' num2str(Ng+1)])';            %% 1xNg    initial output at t=0
On_t0       = xlsread(xlsxFile,3,['K2:K' num2str(Ng+1)])';            %% 1xNg    length of time unit g has to be on at the beginning
Off_t0      = xlsread(xlsxFile,3,['L2:L' num2str(Ng+1)])';            %% 1xNg    length of time unit g has to be off at the beginning
CostA       = xlsread(xlsxFile,3,['M2:M' num2str(Ng+1)])';            %% 1xNg    cost coefficient
CostB       = xlsread(xlsxFile,3,['N2:N' num2str(Ng+1)])';            %% 1xNg    cost coefficient
CostC       = xlsread(xlsxFile,3,['O2:O' num2str(Ng+1)])';            %% 1xNg    cost coefficient
CostUp      = xlsread(xlsxFile,3,['P2:P' num2str(Ng+1)])';            %% 1xNg    startup cost
CostDn      = xlsread(xlsxFile,3,['Q2:Q' num2str(Ng+1)])';            %% 1xNg    shut-down cost
Gen_Bus     = xlsread(xlsxFile,3,['B2:B' num2str(Ng+1)])';      
%
G_map=zeros(Ng,Nb);
for g=1:Ng
    G_map(g,Gen_Bus(g)) = 1;            %% NgxNb   map(i,j)= 1 if generator i at bus j; 0 else  
end
%
%%----------------------------- 负荷 --------------------------------------
Demand_Bus  = xlsread(xlsxFile,4,['B2:B' num2str(Nd+1)])';
Demand      = xlsread(xlsxFile,4,['C2:Z' num2str(Nd+1)])';            %% TxNd    demand  
D_map       = zeros(Nd,Nb);             %% NdxNb   map(i,j)= 1 if demand i at bus j; 0 else   
for g=1:Nd
    D_map(g,Demand_Bus(g)) = 1;
end
%%----------------------------- 风电 --------------------------------------
Wind_Bus    = xlsread(xlsxFile,5,['B2:B' num2str(Nw+1)])';
Windmax     = xlsread(xlsxFile,5,['C2:Z' num2str(Nw+1)])';           %% TxNw    theory output of wind power
W_map       = zeros(Nw,Nb);             %% NdxNb   map(i,j)= 1 if wind farm i at bus j; 0 else  
for g=1:Nw
    W_map(g,Wind_Bus(g)) = 1;
end
%%------------------------------ 线路 -------------------------------------
flmax       = xlsread(xlsxFile,2,['E2:E' num2str(Nl+1)])';             %% 1xNl     transmission limit;
lineX       = xlsread(xlsxFile,2,['D2:D' num2str(Nl+1)])';             %% 1xNl
line_Bus    = xlsread(xlsxFile,2,['B2:C' num2str(Nl+1)])';             %% 2xNl
H           = getPTDF(Nb, line_Bus, lineX, slack);                 %% NlxNb    power transmission distribution factor

%%----------------------------- 联络线 ------------------------------------
Tie_Bus     = xlsread(xlsxFile,6,['B2:B' num2str(Ntie+1)])';           %% 1xNtie    
TieArea     = xlsread(xlsxFile,6,['C2:C' num2str(Ntie+1)])';           %% 1xNtie    connnected area
TieBus      = xlsread(xlsxFile,6,['D2:D' num2str(Ntie+1)])';             %% 1xNtie    connected bus
TieMax      = xlsread(xlsxFile,6,['E2:E' num2str(Ntie+1)])';             %% 1xNtie    transmission capacity
Tie_map     = zeros(Ntie,Nb);             %% NtiexNb   map(i,j)= 1 if tieline i connnected at bus j; 0 else

%%--------------------------- 联络线计划 -----------------------------------
FtieArea    = xlsread(xlsxFile,7,['B2:B' num2str(Narea+1)])';           %% 1xNarea    connected area
FtieMax     = xlsread(xlsxFile,7,['C2:C' num2str(Narea+1)])';             %% 1xNarea    max
FtieMin     = xlsread(xlsxFile,7,['D2:D' num2str(Narea+1)])';            %% 1xNarea    min
FtieRU      = xlsread(xlsxFile,7,['E2:E' num2str(Narea+1)])';             %% 1xNarea    ramp up
FtieRD      = xlsread(xlsxFile,7,['F2:F' num2str(Narea+1)])';             %% 1xNarea    ramp down
FtieEgy     = xlsread(xlsxFile,7,['G2:G' num2str(Narea+1)])';              %% TDxNarea    energy constraint
ftie_Ftie   = zeros(Ntie,Narea);          %% NtiexNarea  (i,j)=  1 if tie i connnected area j; 0 else
for g=1:Ntie
    Tie_map(g,Tie_Bus(g)) = 1;
    ftie_Ftie(g, find(FtieArea==TieArea(g))) = 1;
end

%%----------------------------- 备用 --------------------------------------
ReserveUp   = xlsread(xlsxFile,8,'B1:Y1')';          %% up reserve
ReserveDn   = xlsread(xlsxFile,8,'B2:Y2')';         %% dowen reserve
%% save data
save(matFile);