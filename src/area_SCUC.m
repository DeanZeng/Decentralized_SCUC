%function out=area_SCUC(in,x0)
% single area SCUC model 
%% input data
% T           = in.T;                 %% time horizons
% TD          = in.TD;
% Ng          = in.Ng;                %% number of units
% Ntie        = in.Ntie;              %% number of tie lines
% Narea       = in.Narea;             %% number of neighbor areas
% Nw          = in.Nw;                %% number of wind farms
% Nd          = in.Nd;                %% number of demand buses
% Nb          = in.Nb;                %% number of buses
% Nl          = in.Nl;                %% number of lines  
% %%------------------------ initialization ---------------------------------
% Pmax        = in.Pmax;              %% 1xNg    unit maximum output   
% Pmin        = in.Pmin;              %% 1xNg    unit minimum output
% Rampup      = in.Rampup;            %% 1xNg    unit ramping up rates
% Rampdown    = in.Rampdown;          %% 1xNg    unit ramping down rates
% Minup       = in.Minup;             %% 1xNg    unit minimun up time
% Mindown     = in.Mindown;           %% 1xNg    unit minimum dowm time
% Onoff_t0    = in.Onoff_t0;          %% 1xNg    initial status at t=0
% Pg_t0 = in.Pg_t0;       %% 1xNg    initial output at t=0
% On_t0       = in.On_t0;             %% 1xNg    length of time unit g has to be on at the beginning
% Off_t0      = in.Off_t0;            %% 1xNg    length of time unit g has to be off at the beginning
% CostA       = in.CostA;             %% 1xNg    cost coefficient
% CostB       = in.CostB;             %% 1xNg    cost coefficient
% CostC       = in.CostC;             %% 1xNg    cost coefficient
% G_map       = in.G_map;             %% NgxNb   map(i,j)= 1 if generator i at bus j; 0 else  
% %%----------------------------- 负荷 --------------------------------------
% Demand      = in.Demand;            %% TxNd    demand  
% D_map       = in.D_map;             %% NdxNb   map(i,j)= 1 if demand i at bus j; 0 else   
% %%----------------------------- 风电 --------------------------------------
% Windmax     = in.Windmax;           %% TxNw    theory output of wind power
% W_map       = in.W_map;             %% NdxNb   map(i,j)= 1 if wind farm i at bus j; 0 else  
% %%------------------------------ 线路 -------------------------------------
% H           = in.H                  %% NlxNb    power transmission distribution factor
% flmax       = in.flamx;             %% 1xNl     transmission limit;
% %%----------------------------- 联络线 ------------------------------------
% Tie_map     = in.Tie_map;           %% NtiexNb   map(i,j)= 1 if tieline i connnected at bus j; 0 else
% TieArea     = in.TieArea;           %% 1xNtie    connnected area
% TieBus      = in.TieBus;            %% 1xNtie    connected bus
% TieMax      = in.TieMax;            %% 1xNtie    transmission capacity
% %%--------------------------- 联络线计划 -----------------------------------
% FtieArea    = in.FtieArea;          %% 1xNarea    connected area
% FtieMax     = in.FtieMax;            %% 1xNarea    max
% FtieMin     = in.FtieMin;           %% 1xNarea    min
% FtieRU      = in.FtieRU;            %% 1xNarea    ramp up
% FtieRD      = in.FtieRD;            %% 1xNarea    ramp down
% FtieEgy     = in.FtieEgy;             %% TDxNarea    energy constraint
% 
% %%----------------------------- 备用 --------------------------------------
% ReserveUp   = in.ReserveUp;         %% up reserve
% ReserveDn   = in.ReserveDn;         %% dowen reserve
% %%--------------------------- ADMM系数 ------------------------------------
% lamda       = in.lamda;             %% multiplers
% Rho         = in.Rho;               %% coefficient of quadratic term
% ftieAvg     = in.Rho;               %% ftie average 
%% variables
%%--------------------------- wind power & PV -----------------------------
Pwind=sdpvar(T,Nw,'full');      %% output of wind power 

%%--------------------------- thermal unit --------------------------------
Pg = sdpvar(T,Ng,'full');   %% output of thermal unit
onoff    = binvar(T,Ng,'full');   %% on_off status;
startup  = binvar(T,Ng,'full');   %% start up indicator
shutdown = binvar(T,Ng,'full');   %% shut down indicator
%%---------------------------- tie lines ----------------------------------
ftie = sdpvar(T,Ntie,'full');        %% tie-line power flow
Ftie = sdpvar(T,Narea,'full');       %% area exchange power
%% initial assign
% assign(Pwind,x0.Pwind);
% assign(Ppv,x0.Ppv);
% assign(Pg, x0.Pg);
% assign(onoff, x0.onoff);
% assign(startup, x0.startup);
% assign(shutdown, x0.shutdown);
% assign(Ftie, x0.Ftie);
%% constraints
Constraints=[];

%--------------------- thermal unit constraints ------------------------
% binary variable logic
Constraints=[Constraints,(startup-shutdown==onoff-[Onoff_t0;onoff(1:T-1,:)]):'logical_1'];
Constraints=[Constraints,(startup+shutdown<=ones(T,Ng)):'logical_2'];
% output limit
for t = 1:T
   Constraints = [Constraints, (onoff(t,:).*Pmin <=...
       Pg(t,:) <= onoff(t,:).*Pmax):'output limit'];
end
%     for t = 1:T
%        Constraints{a} = [Constraints{a}, (Pmin{a} <=...
%            Pg{a}(t,:) <= Pmax{a}):'output limit'];
%     end
% minimum up/down time
Lini=On_t0+Off_t0;
for t=1:Lini
    Constraints = [Constraints,(onoff(t,:) == Onoff_t0 ):'initial status'];
end
for t = Lini+1:T
    for unit = 1:Ng
        tt=max(1,t-Minup(unit)+1);
        Constraints = [Constraints, (sum(startup(tt:t,unit))...
            <= onoff(t,unit)):'min_up'];
        tt=max(1,t-Mindown(unit)+1);
        Constraints = [Constraints, (sum(shutdown(tt:t,unit))...
            <= 1-onoff(t,unit)):'min_down'];
    end
end
% ramping up/down limit
% Constraints=[Constraints,(-Rampdown <= Pg(1,:)-Pg_t0...
%         <= Rampup):'ramp0'];
for t=2:T
    Constraints=[Constraints,(-Rampdown <= Pg(t,:)-Pg(t-1,:)...
        <= Rampup):'ramp'];
end

%------------------------------- wind power & PV ----------------------
Constraints=[Constraints,(zeros(T,Nw) <= Pwind <= Windmax):'wind power output limit'];
%-------------------------------- tie line --------------------------------
for t=1:T
    Constraints=[Constraints,(-TieMax <= ftie(t,:) <= TieMax):'tieline_max'];
    Constraints=[Constraints,(Ftie(t,:) == ftie(t,:)*ftie_Ftie):'tieline_sum'];
end
%------------------------------- exchange power -----------------------------
for t=1:T
    Constraints=[Constraints, ( FtieMin <= Ftie(t,:) <= FtieMax ):'Ftie max and min'];
end
for t=2:T
    Cosntraints=[Constraints, ( -FtieRD  <= Ftie(t,:) - Ftie(t-1,:) <= FtieRU):'Ftie ramp'];
end
for td=1:TD
    Constraints=[Constraints, (sum(Ftie(Td0(td):Td0(td+1)-1,:)) == FtieEgy(td,:)):'exchange energy'];
end
%------------------------------- power balance ----------------------------
for t=1:T
    Constraints=[Constraints,(sum(Pg(t,:))+sum(Pwind(t,:))...
        == sum(Demand(t,:))+sum(Ftie(t,:))):'power balance'];
end
%------------------------------- spinning reserve -------------------------
% for t=1:T
%     Constraints=[Constraints,(sum(onoff(t,:).*Pmax)+Windmax(t)+PVmax(t)...
%         +sum(Tieline(:,3))>=Demand(t)+ReserveUp(t)):'up reserve'];
%     Constraints=[Constraints,(sum(onoff(t,:).*Pmin)-sum(Tieline(:,3))...
%         <=Demand(t)-ReserveDn(t)):'down reserve'];
% end
for t=1:T
    Constraints=[Constraints,(sum(onoff(t,:).*Pmax - Pg(t,:)) >= ReserveUp(t)):'up reserve'];
    Constraints=[Constraints,(sum(onoff(t,:).*Pmin - Pg(t,:)) <= -ReserveDn(t)):'down reserve'];
end
%-------------------------- transmission limits ---------------------------
%    -flmax<= H*(Pg*gmap+Pw*wmap-Pd*dmap-Ftie*tiemap)’<= flmax
for t=1:T
    Constraints=[Constraints,(-flmax' <= H*G_map'*Pg(t,:)' + H*W_map'*Pwind(t,:)'...
        - H*D_map'*Demand(t,:)' - H*Tie_map'*ftie(t,:)' <= flmax'):'transmission limits'];
end

%% Objective
% minLang=[];
ThermalCost=0;
WindCur = sum(sum(Windmax - Pwind));
for t=1:T
    ThermalCost= ThermalCost + Pg(t,:)*diag(CostA)*Pg(t,:)'+CostB*Pg(t,:)';
end
minLang = ThermalCost+gamma*WindCur;

%     for la=1:Ntie
%         minLang = minLang +...
%             lamda(:,la)'*(ftie(:,la)-ftieAvg(:,la))+...
%             Rho/2*(ftie(:,la)-ftieAvg(:,la))'*(ftie(:,la)-ftieAvg(:,la));                
%     end
%% solver
Ops = sdpsettings('solver','gurobi','usex0',1,'verbose',1,'showprogress',0);
Ops.gurobi.MIPGap=0.0002;
%         Ops.gurobi.MIPGapAbs=1.0;
Ops.gurobi.OptimalityTol = 0.0002;
%         Ops.gurobi.FeasRelaxBigM   = 1.0e10;
Ops.gurobi.DisplayInterval = 20;
diagnose = optimize(Constraints,minLang,Ops); 
% check(Constraints);
if diagnose.problem ~= 0
    error(yalmiperror(diagnose.problem));
end
%% read values of variables
%%--------------------------- wind power & PV -----------------------------
Pwind_V=value(Pwind);    %% output of wind power 
%%--------------------------- thermal unit --------------------------------
Pg_V= value(Pg);
onoff_V=value(onoff);
startup_V  = value(startup);
shutdown_V = value( shutdown);
%%---------------------------- tie lines ----------------------------------
ftie_V = value(ftie);
Ftie_V = value( Ftie);
minLang_V=value(minLang);
ThermalCost_V = value(ThermalCost);
WindCur_V = value(WindCur);
% %% return out
% out.Pwind    = Pwind_V;
% out.Ppv      = Ppv_V;
% out.Pg = Pg_V;
% out.onoff    = onoff_V;
% out.startup  = startup_V;             
% out.shutdown = shutdown_V;            
% out.Ftie     = Ftie_V;
% out.minLang = minLang_V;