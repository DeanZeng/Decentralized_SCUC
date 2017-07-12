function out = scuc_modelSolve(model)
%% solve
Ops = sdpsettings('solver','gurobi','usex0',1,'verbose',1,'showprogress',0);
Ops.gurobi.MIPGap=0.0002;
%         Ops.gurobi.MIPGapAbs=1.0;
Ops.gurobi.OptimalityTol = 0.0002;
%         Ops.gurobi.FeasRelaxBigM   = 1.0e10;
Ops.gurobi.DisplayInterval = 20;
diagnose = optimize(model.Constraints,model.Objective,Ops); 
% check(Constraints);
if diagnose.problem ~= 0
    error(yalmiperror(diagnose.problem));
end
%% read values of variables
%%--------------------------- wind power & PV -----------------------------
out.Pwind= value(model.Variable.Pwind);    %% output of wind power 
%%--------------------------- thermal unit --------------------------------
out.Pg=  value(model.Variable.Pg);
out.onoff= value(model.Variable.onoff);
out.startup  = value(model.Variable.startup);
out.shutdown = value(model.Variable.shutdown);
%%---------------------------- tie lines ----------------------------------
out.ftie = value(model.Variable.ftie);
out.Ftie = value(model.Variable.Ftie);
out.Objective =value(model.Objective);
out.ThermalCost = value(model.Variable.ThermalCost);
out.WindCur = value(model.Variable.WindCur);