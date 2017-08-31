%%multi-area decentralized SCUC
matFile = {'data\case118\areadata1.mat', 'data\case118\areadata2.mat','data\case118\areadata3.mat'};
resultFile ='data\case118\result.mat';
A=3;       % number of area 
T=24;

NtieC    = cell(A,1);
TieAreaC = cell(A,1);
TieBusC  = cell(A,1);
Tie_BusC = cell(A,1);
ftie_outC= cell(A,1);
ftie_avgC= cell(A,1);
%-------------- admm struct -----------------------
admm.Converge = false;
admm.MAX_ITER = 400;
admm.Iteration=0;
admm.ABSTOL   = 1;
admm.RELTOL   = 1e-2;
admm.Rho      = 1;
admm.penaltyAdjust = 1;    %% 0-不调整惩罚系数Rho， 1-调整惩罚系数
admm.tau = 2;              %% 惩罚系数调整的相关系数 >1
admm.mu  = 10;             %% 惩罚系数调整的相关系数 >1   
admm.Solvetime=0;
admm.Problem = 'not start';
%-------------- admm struct -----------------------

epsP     = 1e-3;
epsD     = 1e-3;
%------------- accelerate method ------------------
accelerate_mode = true;
insens_times = 4;                  %% 机组状态变化不灵敏判断次数 >=2
MIPGap       = 0.001;
%------------- accelerate method ------------------
parpool(A);
%-------------- plot -------------------
% figure(1)
% ax11 = subplot(3,1,1);
% hold on
% ax12 = subplot(3,1,2);
% hold on
% ax13 = subplot(3,1,3);
% hold on
% figure(2)
% ax21 = subplot(2,1,1);
% hold on
% ax22 = subplot(2,1,2);
% hold on
% figure(3)
% ax31 = subplot(2,1,1);
% hold on
% ax32 = subplot(2,1,2);
% hold on
%-------------- plot ------------------
tic;
MAX_ITER = admm.MAX_ITER;
ABSTOL = admm.ABSTOL;
RELTOL = admm.RELTOL;
Rho = admm.Rho;
%% ADMM algorithm
spmd
        % load data in work;
        scuc_in = load(matFile{labindex});
        % variables for ADMM
        ftie_out = zeros(scuc_in.T,scuc_in.Ntie);           % x
        ftie_avg = zeros(scuc_in.T,scuc_in.Ntie);           % z
        lamda = zeros(scuc_in.T,scuc_in.Ntie);              % y
        resP  = 10*ones(scuc_in.T,scuc_in.Ntie);
        resD  = 10*ones(scuc_in.T,scuc_in.Ntie);
        % tie data in client; 
        Ntie    = scuc_in.Ntie;
        TieArea = scuc_in.TieArea;
        TieBus  = scuc_in.TieBus;
        Tie_Bus  = scuc_in.Tie_Bus;
        % scuc model define in local work;
        scuc_model = scuc_modelDefine(scuc_in); 
        % insensitive units initialization in accelerate mode
        if accelerate_mode == true 
            iu.onoff_old = zeros(scuc_in.T,scuc_in.Ng);  % 机组上次迭代状态 
            iu.invar_times = zeros(1,scuc_in.Ng);        % 机组状态不变次数
            iu.fix_units = zeros(1,scuc_in.Ng);          % 状态固定机组 0-没有固定， 1-固定，未加入约束， 2-固定，已加入约束 
            iu.insens_times = insens_times;                 % 机组状态变化不灵敏判断次数 >=2
        end
end
for a=1:A
    NtieC{a}     = Ntie{a};
    TieAreaC{a}  = TieArea{a};
    TieBusC{a}   = TieBus{a};
    Tie_BusC{a}  = Tie_Bus{a};
    ftie_outC{a} = ftie_out{a};
    ftie_avgC{a} = ftie_avg{a};
end
for k= 1:MAX_ITER
    admm.Iteration = k;
    MIPGap = 0.005;  % 0.001+0.1./k;   
    if k==1
        if accelerate_mode == true 
            spmd
                %%--------------------------- x update -------------------------------
                [scuc_out,ftie_out,iu] = scuc_accelerateSolve(scuc_model,ftie_avg,lamda,0,iu);   
            end
        else
            spmd
                %%--------------------------- x update -------------------------------
                
                [scuc_out,ftie_out] = scuc_modelSolve(scuc_model,ftie_avg,lamda,0,MIPGap);   
            end
        end
    else 
        if accelerate_mode == true 
            spmd
                %%--------------------------- x update -------------------------------
                [scuc_out,ftie_out,iu] = scuc_accelerateSolve(scuc_model,ftie_avg,lamda,Rho,iu);   
            end
        else 
            
            spmd
                %%--------------------------- x update -------------------------------
                [scuc_out,ftie_out] = scuc_modelSolve(scuc_model,ftie_avg,lamda,Rho,MIPGap);   
            end
        end 
    end
%     iuu1=iu{1}
%     iuu2=iu{2}
    %%--------------------------- z update --------------------------------
    % fetch x
    for a=1:A
        ftie_outC{a} = ftie_out{a};
    end
    for a=1:A
        for la=1:NtieC{a}
            b  = TieAreaC{a}(la);
            ab = Tie_BusC{a}(la);
            bb = TieBusC{a}(la);
            lb = find ( (TieAreaC{b}==a)&(TieBusC{b}==ab)&(Tie_BusC{b}== bb));
            % update z
            ftie_avgC{a}(:,la) = 0.5*(ftie_outC{a}(:,la)-ftie_outC{b}(:,lb));
        end
    end
    %%--------------------------- y update --------------------------------
    spmd
        ftie_avg_old = ftie_avg;
        % fetch z
        ftie_avg = ftie_avgC{labindex};
        % update y
        lamda = lamda + Rho*(ftie_out - ftie_avg);
        resP  = (ftie_out - ftie_avg);
        resD  = Rho*(ftie_avg-ftie_avg_old);   
%         quiet = (all(all(abs(resP) <= epsP)))&&(all(all(abs(resD) <=
%         epsD)));     %绝对误差
%         quiet = (all(all(abs(resP) <= ABSTOL + abs(RELTOL.*ftie_avg))))&&(all(all(abs(resD) <= ABSTOL + abs(RELTOL.*lamda)))); %相对误差
%-------------------- 矩阵范数 inf ------------------
%         resPnorm = norm(reshape(resP,inf);
%         resDnorm = norm(resP,inf); 
%-------------------- 向量范数 2 ---------------------
        resPnorm = norm(reshape(resP,[1,scuc_in.T*scuc_in.Ntie]));
        resDnorm = norm(reshape(resD,[1,scuc_in.T*scuc_in.Ntie])); 
        epsP  = sqrt(scuc_in.T*scuc_in.Ntie)*ABSTOL + RELTOL*norm(reshape(ftie_avg,[1,scuc_in.T*scuc_in.Ntie]));
        epsD  = sqrt(scuc_in.T*scuc_in.Ntie)*ABSTOL + RELTOL*norm(reshape(lamda,[1,scuc_in.T*scuc_in.Ntie]));
    end
    %-------------- fetch resPnorm, resDnorm, lamda------------
    for a=1:A
        resPnormC(a) = resPnorm{a};
        resDnormC(a) = resDnorm{a};
        epsPC(a) = epsP{a};
        epsDC(a) = epsD{a};
        lamdaC{a}= lamda{a};
    end
    resPnormG(k) = norm(resPnormC);
    resDnormG(k) = norm(resDnormC);
    epsPG(k) = norm(epsPC);
    epsDG(k) = norm(epsDC);
    %-------------- plot-----------------------------
%         figure(1)
%     plot(ax11, ftie_avgC{1}(:,1));
%     plot(ax12, ftie_outC{1}(:,1));
%     plot(ax13, -ftie_outC{2}(:,1));
%     figure(2)
%     plot(ax21, abs(resPC{1}(:,1,k)));
%     hold(ax21, 'on')
%     plot(ax21, ABSTOL + abs(RELTOL.*ftie_avgC{1}(:,1)));
%     hold(ax21, 'off')
%     plot(ax22, abs(resDC{1}(:,1,k)));
%     hold on
%     plot(ax22, ABSTOL + abs(RELTOL.*lamdaC{1}(:,1)));
%     hold off
%     figure(3)
%     plot(ax31, lamdaC{1}(:,1));
%     plot(ax32, lamdaC{2}(:,1));
%     pause(0.1)
%-------------- convegence criterion ----------
    if (resPnormG(k) < epsPG(k) && resDnormG(k) <epsDG(k))
        admm.Converge = true;
         break;
    end 
    %-------------- adjust penalty ---------
    if admm.penaltyAdjust == 1
        if resPnormG(k) > admm.mu * resDnormG(k)
            Rho = Rho * admm.tau;
        elseif resDnormG(k) > admm.mu * resPnormG(k)
            Rho = Rho / admm.tau;
        end
    end
    disp(['第' num2str(k) '次迭代:' num2str(toc) 's']);
end
admm.Solvetime = toc;
%% save results
if admm.Converge
    admm.Problem = 'Successfully solved';
    disp( 'Successfully solved');
    %-------------- fetch results --------------------------
    for a=1:A
        scuc_outC{a}=scuc_out{a};
    end
    %-------------- result table ----------------------------
    resTb = zeros(A+1,3);
    rowNames =cell(A+1,1);
    for a=1:A
        resTb (a,1) = scuc_outC{a}.ThermalCost;
        resTb (a,2) = scuc_outC{a}.WindCur;
        resTb (a,3) = scuc_outC{a}.Objective;
        rowNames{a} = ['area ' num2str(a)];        
    end
    resTb(A+1,:) = sum(resTb(1:A,:));
    rowNames{A+1} = 'sum';
    resTb = array2table(resTb,'RowNames',rowNames,'VariableNames',{'coalCost','WindCurtailment','Objective'});
    resTb
elseif admm.Iteration >= admm.MAX_ITER
    admm.Problem = 'Maximum iterations exceeded';
    disp( 'Maximum iterations exceeded');
else
    admm.Problem = 'Unexpected Iterruption';
    disp( 'Unexpected Iterruption');
end
save(resultFile ,'scuc_outC');
%% display error
isPlot = true;
if isPlot
    g = figure;
    subplot(2,1,1);                                                                                                                    
    semilogy(1:k, max(1e-8, resPnormG), 'k',1:k, epsPG, 'k--',  'LineWidth', 2); 
    ylabel('||r||_2'); 
    subplot(2,1,2);                                                                                                                    
    semilogy(1:k, max(1e-8, resDnormG), 'k',1:k, epsDG, 'k--', 'LineWidth', 2);   
    ylabel('||s||_2'); xlabel('iter (k)'); 
end
delete(gcp());