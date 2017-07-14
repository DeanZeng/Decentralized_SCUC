function model = scuc_modelDefine(in)
%% input data
T           = in.T;                 %% time horizons
TD          = in.TD;
Td0         = in.Td0;
Ng          = in.Ng;                %% number of units
Ntie        = in.Ntie;              %% number of tie lines
Narea       = in.Narea;             %% number of neighbor areas
Nw          = in.Nw;                %% number of wind farms
Nd          = in.Nd;                %% number of demand buses
Nb          = in.Nb;                %% number of buses
Nl          = in.Nl;                %% number of lines
slack       = in.slack;
%%------------------------ initialization ---------------------------------
Pmax        = in.Pmax;              %% 1xNg    unit maximum output   
Pmin        = in.Pmin;              %% 1xNg    unit minimum output
Rampup      = in.Rampup;            %% 1xNg    unit ramping up rates
Rampdown    = in.Rampdown;          %% 1xNg    unit ramping down rates
Minup       = in.Minup;             %% 1xNg    unit minimun up time
Mindown     = in.Mindown;           %% 1xNg    unit minimum dowm time
Onoff_t0    = in.Onoff_t0;          %% 1xNg    initial status at t=0
Pg_t0       = in.Pg_t0;       %% 1xNg    initial output at t=0
On_t0       = in.On_t0;             %% 1xNg    length of time unit g has to be on at the beginning
Off_t0      = in.Off_t0;            %% 1xNg    length of time unit g has to be off at the beginning
CostA       = in.CostA;             %% 1xNg    cost coefficient
CostB       = in.CostB;             %% 1xNg    cost coefficient
CostC       = in.CostC;             %% 1xNg    cost coefficient
G_map       = in.G_map;             %% NgxNb   map(i,j)= 1 if generator i at bus j; 0 else  
%%----------------------------- 负荷 --------------------------------------
Demand      = in.Demand;            %% TxNd    demand  
D_map       = in.D_map;             %% NdxNb   map(i,j)= 1 if demand i at bus j; 0 else   
%%----------------------------- 风电 --------------------------------------
Windmax     = in.Windmax;           %% TxNw    theory output of wind power
W_map       = in.W_map;             %% NdxNb   map(i,j)= 1 if wind farm i at bus j; 0 else  
%%------------------------------ 线路 -------------------------------------
H           = in.H;                 %% NlxNb    power transmission distribution factor
flmax       = in.flmax;             %% 1xNl     transmission limit;
%%----------------------------- 联络线 ------------------------------------
Tie_map     = in.Tie_map;           %% NtiexNb   map(i,j)= 1 if tieline i connnected at bus j; 0 else
TieArea     = in.TieArea;           %% 1xNtie    connnected area
TieBus      = in.TieBus;            %% 1xNtie    connected bus
TieMax      = in.TieMax;            %% 1xNtie    transmission capacity
%%--------------------------- 联络线计划 -----------------------------------
FtieArea    = in.FtieArea;          %% 1xNarea    connected area
FtieMax     = in.FtieMax;            %% 1xNarea    max
FtieMin     = in.FtieMin;           %% 1xNarea    min
FtieRU      = in.FtieRU;            %% 1xNarea    ramp up
FtieRD      = in.FtieRD;            %% 1xNarea    ramp down
FtieEgy     = in.FtieEgy;             %% TDxNarea    energy constraint
ftie_Ftie   = in.ftie_Ftie;
% %%----------------------------- 备用 --------------------------------------
ReserveUp   = in.ReserveUp;         %% up reserve
ReserveDn   = in.ReserveDn;         %% dowen reserve
%%----------------------------- 惩罚因子 ----------------------------------
gamma = in.gamma;
% %%--------------------------- ADMM系数 ------------------------------------
% lamda       = in.lamda;             %% multiplers
% Rho         = in.Rho;               %% coefficient of quadratic term
% ftieAvg     = in.Rho;               %% ftie average 
%% variables
%%--------------------------- wind power & PV -----------------------------
model.Variable.Pwind=sdpvar(T,Nw,'full');      %% output of wind power 

%%--------------------------- thermal unit --------------------------------
model.Variable.Pg = sdpvar(T,Ng,'full');   %% output of thermal unit
model.Variable.onoff    = binvar(T,Ng,'full');   %% on_off status;
model.Variable.startup  = binvar(T,Ng,'full');   %% start up indicator
model.Variable.shutdown = binvar(T,Ng,'full');   %% shut down indicator
%%---------------------------- tie lines ----------------------------------
model.Variable.ftie = sdpvar(T,Ntie,'full');        %% tie-line power flow
model.Variable.Ftie = sdpvar(T,Narea,'full');       %% area exchange power
%% initial assign
% assign(Pwind,x0.Pwind);
% assign(Ppv,x0.Ppv);
% assign(Pg, x0.Pg);
% assign(model.Variable.onoff, x0.model.Variable.onoff);
% assign(model.Variable.startup, x0.model.Variable.startup);
% assign(model.Variable.shutdown, x0.model.Variable.shutdown);
% assign(model.Variable.Ftie, x0.model.Variable.Ftie);
%% constraints
model.Constraints=[];

%--------------------- thermal unit constraints ------------------------
% binary variable logic
model.Constraints=[model.Constraints,(model.Variable.startup-model.Variable.shutdown==model.Variable.onoff-[Onoff_t0;model.Variable.onoff(1:T-1,:)]):'logical_1'];
model.Constraints=[model.Constraints,(model.Variable.startup+model.Variable.shutdown<=ones(T,Ng)):'logical_2'];
% output limit
for t = 1:T
   model.Constraints = [model.Constraints, (model.Variable.onoff(t,:).*Pmin <=...
       model.Variable.Pg(t,:) <= model.Variable.onoff(t,:).*Pmax):'output limit'];
end
%     for t = 1:T
%        model.Constraints{a} = [model.Constraints{a}, (Pmin{a} <=...
%            Pg{a}(t,:) <= Pmax{a}):'output limit'];
%     end
% minimum up/down time
Lini=On_t0+Off_t0;
for t=1:Lini
    model.Constraints = [model.Constraints,(model.Variable.onoff(t,:) == Onoff_t0 ):'initial status'];
end
for t = Lini+1:T
    for unit = 1:Ng
        tt=max(1,t-Minup(unit)+1);
        model.Constraints = [model.Constraints, (sum(model.Variable.startup(tt:t,unit))...
            <= model.Variable.onoff(t,unit)):'min_up'];
        tt=max(1,t-Mindown(unit)+1);
        model.Constraints = [model.Constraints, (sum(model.Variable.shutdown(tt:t,unit))...
            <= 1-model.Variable.onoff(t,unit)):'min_down'];
    end
end
% ramping up/down limit
% model.Constraints=[model.Constraints,(-Rampdown <= Pg(1,:)-Pg_t0...
%         <= Rampup):'ramp0'];
for t=2:T
    model.Constraints=[model.Constraints,(-Rampdown <= model.Variable.Pg(t,:)-model.Variable.Pg(t-1,:)...
        <= Rampup):'ramp'];
end

%------------------------------- wind power ----------------------
model.Constraints=[model.Constraints,(zeros(T,Nw) <= model.Variable.Pwind <= Windmax):'wind power output limit'];
%-------------------------------- tie line --------------------------------
for t=1:T
    model.Constraints=[model.Constraints,(-TieMax <= model.Variable.ftie(t,:) <= TieMax):'tieline_max'];
    model.Constraints=[model.Constraints,(model.Variable.Ftie(t,:) == model.Variable.ftie(t,:)*ftie_Ftie):'tieline_sum'];
end
%------------------------------- exchange power -----------------------------
for t=1:T
    model.Constraints=[model.Constraints, ( FtieMin <= model.Variable.Ftie(t,:) <= FtieMax ):'model.Variable.Ftie max and min'];
end
for t=2:T
    model.Constraints =[model.Constraints, ( -FtieRD  <= model.Variable.Ftie(t,:) - model.Variable.Ftie(t-1,:) <= FtieRU):'model.Variable.Ftie ramp'];
end
for td=1:TD
    model.Constraints=[model.Constraints, (sum(model.Variable.Ftie(Td0(td):Td0(td+1)-1,:)) == FtieEgy(td,:)):'exchange energy'];
end
%------------------------------- power balance ----------------------------
for t=1:T
    model.Constraints=[model.Constraints,(sum(model.Variable.Pg(t,:))+sum(model.Variable.Pwind(t,:))...
        == sum(Demand(t,:))+sum(model.Variable.Ftie(t,:))):'power balance'];
end
%------------------------------- spinning reserve -------------------------
% for t=1:T
%     model.Constraints=[model.Constraints,(sum(model.Variable.onoff(t,:).*Pmax)+Windmax(t)+PVmax(t)...
%         +sum(Tieline(:,3))>=Demand(t)+ReserveUp(t)):'up reserve'];
%     model.Constraints=[model.Constraints,(sum(model.Variable.onoff(t,:).*Pmin)-sum(Tieline(:,3))...
%         <=Demand(t)-ReserveDn(t)):'down reserve'];
% end
for t=1:T
    model.Constraints=[model.Constraints,(sum(model.Variable.onoff(t,:).*Pmax - model.Variable.Pg(t,:)) >= ReserveUp(t)):'up reserve'];
    model.Constraints=[model.Constraints,(sum(model.Variable.onoff(t,:).*Pmin - model.Variable.Pg(t,:)) <= -ReserveDn(t)):'down reserve'];
end
%-------------------------- transmission limits ---------------------------
%    -flmax<= H*(Pg*gmap+Pw*wmap-Pd*dmap-model.Variable.Ftie*tiemap)’<= flmax
for t=1:T
    model.Constraints=[model.Constraints,(-flmax' <= H*G_map'*model.Variable.Pg(t,:)' + H*W_map'*model.Variable.Pwind(t,:)'...
        - H*D_map'*Demand(t,:)' - H*Tie_map'*model.Variable.ftie(t,:)' <= flmax'):'transmission limits'];
end

%% Objective
% minLang=[];
model.Variable.ThermalCost=0;
model.Variable.WindCur = sum(sum(Windmax - model.Variable.Pwind));
for t=1:T
    model.Variable.ThermalCost= model.Variable.ThermalCost + model.Variable.Pg(t,:)*diag(CostA)*model.Variable.Pg(t,:)'+CostB*model.Variable.Pg(t,:)';
end
model.Objective = model.Variable.ThermalCost+gamma*model.Variable.WindCur;
