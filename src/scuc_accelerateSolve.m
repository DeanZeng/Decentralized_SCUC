function [out,ftie_out,iu] = scuc_accelerateSolve(model,ftie_avg,lamda,Rho,iu,MIPGap)
if nargin <= 5
    MIPGap = 0.005;
end
%% insensitive unit struct
% % iu.onoff_old   TxNg    % �����ϴε���״̬ 
% % iu.invar_times 1xNg;   % ����״̬�������
% % iu.fix_units   1xNg;   % ״̬�̶����� 0-û�й̶��� 1-�̶���δ����Լ���� 2-�̶����Ѽ���Լ�� 
% % iu.insens_times;       % ����״̬�仯�������жϴ��� >=2
Constraints = model.Constraints;
[T,Ng] = size(iu.onoff_old);
%% fix unit status
for g =1:Ng
    if iu.fix_units(g)==1
        Constraints = [Constraints, (model.Variable.onoff(:,g) == iu.onoff_old(:,g)):'fix unit status'];
%         iu.fix_units(g)=2;
    end
end
%% objective
Lagrangian = model.Objective +...
    sum(sum(lamda.*(model.Variable.ftie-ftie_avg)))+...
    sum(sum(Rho*0.5*(model.Variable.ftie-ftie_avg).*(model.Variable.ftie-ftie_avg)));
%% solve
Ops = sdpsettings('solver','gurobi','usex0',1,'verbose',0,'showprogress',0);
Ops.gurobi.MIPGap=MIPGap;
%         Ops.gurobi.MIPGapAbs=1.0;
Ops.gurobi.OptimalityTol = 0.0002;
%         Ops.gurobi.FeasRelaxBigM   = 1.0e10;
Ops.gurobi.DisplayInterval = 20;
diagnose = optimize(Constraints,Lagrangian,Ops); 
% check(Constraints);
if diagnose.problem ~= 0
    error(yalmiperror(diagnose.problem));
end
%% read values of variables
%%--------------------------- wind power & PV -----------------------------
out.Pwind= value(model.Variable.Pwind);    %% output of wind power 
%%--------------------------- thermal unit --------------------------------
out.Pg=  value(model.Variable.Pg);
out.onoff = value(model.Variable.onoff);
out.startup  = value(model.Variable.startup);
out.shutdown = value(model.Variable.shutdown);
%%---------------------------- tie lines ----------------------------------
out.ftie = value(model.Variable.ftie);
out.Ftie = value(model.Variable.Ftie);
out.Objective =value(model.Objective);
out.ThermalCost = value(model.Variable.ThermalCost);
out.WindCur = value(model.Variable.WindCur);
ftie_out = value(model.Variable.ftie);
%% update onoff_old, invar_times
for g =1:Ng
    if iu.fix_units(g)== 0
        if all(round(out.onoff(:,g)) == round(iu.onoff_old(:,g)))
            iu.invar_times(g) = iu.invar_times(g)+1;
            if iu.invar_times(g) >= iu.insens_times
                iu.fix_units(g) = 1;
            end
        else
            iu.onoff_old(:,g) = round(out.onoff(:,g));
            iu.invar_times(g) = 1;
        end
    end
end 

