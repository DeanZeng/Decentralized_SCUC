%%multi-area decentralized SCUC
% stopping criterion: infinite-norm of residuals 
%                     absolut tolerance 
clear all;
delete(gcp());
matFile = {'data\case118\areadata1.mat', 'data\case118\areadata2.mat','data\case118\areadata3.mat'};
resultFile ='data\case118\decentralized_result.mat';
A=3;       % number of area 
T=24;
isStep = true;
isPlot = true;

NtieC    = cell(A,1);
TieAreaC = cell(A,1);
TieBusC  = cell(A,1);
Tie_BusC = cell(A,1);
ftie_outC= cell(A,1);
ftie_avgC= cell(A,1);
%-------------- admm struct -----------------------
admm.Converge = false;
admm.MAX_ITER = 200;
admm.Iteration=0;
admm.ABSTOL   = 0.05;
admm.RELTOL   = 1e-2;
admm.Rho      = 16.8;
admm.penaltyAdjust = 1;    %% 0-不调整惩罚系数Rho， 1-调整惩罚系数
admm.tau = 2;              %% 惩罚系数调整的相关系数 >1
admm.mu  = 10;             %% 惩罚系数调整的相关系数 >1   
admm.mu0 =10;
admm.Solvetime=0;
admm.Problem = 'not start';
admm.gamma = 1.618;  %1.618;   %% lamada乘子更新系数 取值范围[0,(1+sqrt(5)/2)]
%-------------- admm struct -----------------------

%------------- accelerate method ------------------
accelerate_mode = true;
insens_times = 3;                  %% 机组状态变化不灵敏判断次数 >=2
MIPGap       = 0.005;
%------------- accelerate method ------------------
%------------- oscillating handle ------------------
Osch.start = false;
Osch.centre = 0;
Osch.rang = sqrt(20);
Osch.maxIter = 20;
Osch.iter = 0;
%------------- oscillating handle------------------
%------------- history information ----------------
hsit.Rho(1)=admm.Rho;
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
                [scuc_out,ftie_out,iu,scuc_model] = scuc_accelerateSolve(scuc_model,ftie_avg,lamda,0,iu);  
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
                [scuc_out,ftie_out,iu,scuc_model] = scuc_accelerateSolve(scuc_model,ftie_avg,lamda,Rho,iu);    
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
        lamda = lamda + admm.gamma*Rho*(ftie_out - ftie_avg);
        resP  = (ftie_out - ftie_avg);
        resD  = Rho*(ftie_avg-ftie_avg_old);   
%-------------------- 向量范数 2 ---------------------
%         resPnorm = norm(reshape(resP,[1,scuc_in.T*scuc_in.Ntie]));
%         resDnorm = norm(reshape(resD,[1,scuc_in.T*scuc_in.Ntie])); 
%         epsP  = sqrt(scuc_in.T*scuc_in.Ntie)*ABSTOL + RELTOL*norm(reshape(ftie_avg,[1,scuc_in.T*scuc_in.Ntie]));
%         epsD  = sqrt(scuc_in.T*scuc_in.Ntie)*ABSTOL + RELTOL*norm(reshape(lamda,[1,scuc_in.T*scuc_in.Ntie]));
%-------------------- 向量范数 inf ---------------------
        resPnorm = norm(reshape(resP,[1,scuc_in.T*scuc_in.Ntie]),inf);
        resDnorm = norm(reshape(resD,[1,scuc_in.T*scuc_in.Ntie]),inf); 
        epsP  = ABSTOL ;
        epsD  = ABSTOL ;
    end
    %-------------- fetch resPnorm, resDnorm, lamda------------
    for a=1:A
        resPnormC(a) = resPnorm{a};
        resDnormC(a) = resDnorm{a};
        epsPC(a) = epsP{a};
        epsDC(a) = epsD{a};
        lamdaC{a}= lamda{a};
    end
%-------------------- 向量范数 2 ---------------------
%     resPnormG(k) = norm(resPnormC);
%     resDnormG(k) = norm(resDnormC);
%     epsPG(k) = norm(epsPC);
%     epsDG(k) = norm(epsDC);
%-------------------- 向量范数 inf --------------------- 
    resPnormG(k) = norm(resPnormC,inf);
    resDnormG(k) = norm(resDnormC,inf);
    epsPG(k) = ABSTOL;
    epsDG(k) = ABSTOL;
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
%             if accelerate_mode == true 
%                 spmd
%                     %%--------------------------- x update -------------------------------
%                     [scuc_out,iu] = scuc_fixftie_accelerateSolve(scuc_model,ftie_avg,iu); 
%                 end
%             else 
% 
%                 spmd
%                     %%--------------------------- x update -------------------------------
%                     [scuc_out] = scuc_fixftie_modelSolve(scuc_model,ftie_avg);   
%                 end
%             end
         disp(['第' num2str(k) '次迭代:' num2str(toc) 's']);
         break;
    end 
    %-------------- adjust penalty ---------
    if admm.penaltyAdjust == 1
        if resPnormG(k) > admm.mu * resDnormG(k)
            if resDnormG(k) > 1e-6
                Rho = Rho * (1+log10(resPnormG(k)/resDnormG(k)));
            else
                Rho = Rho * admm.tau;
            end
            admm.mu = admm.mu0;
        elseif resDnormG(k) > admm.mu * resPnormG(k)
            if resPnormG(k) >1e-6
                Rho = Rho / (1+log10(resDnormG(k)/resPnormG(k)));
            else
                Rho = Rho / admm.tau;
            end
            admm.mu = admm.mu0;
        end
        if resPnormG(k) < 10*epsPG(k) && resDnormG(k) <10*epsDG(k)
            admm.penaltyAdjust = false;         %% 在收敛误差附近，停止修改惩罚系数，避免震荡
        end
    end
    if Osch.start
        % 检测震荡，发生震荡时，减少admm.mu，减弱修改惩罚系数的条件
        if k==1
            Osch.centre = [resPnormG(k),resDnormG(k)];
        end
        if ( Osch.centre(1)/Osch.rang < resPnormG(k) &&  resPnormG(k) < Osch.rang*Osch.centre(1) &&...
                Osch.centre(2)/Osch.rang < resDnormG(k) && resDnormG(k)< Osch.rang*Osch.centre(2))
            Osch.centre = [mean(resPnormG(k-Osch.iter:k)),mean(resDnormG(k-Osch.iter :k))];
            Osch.iter = Osch.iter+1;
        else
            Osch.centre = [resPnormG(k),resDnormG(k)];
            Osch.iter = 0;
        end
        if Osch.iter >= Osch.maxIter
%              admm.mu = admm.mu /1.618;
%              Rho = Rho + 2*(rand(1)-0.5);
             Rho = Rho *10^((resPnormG(k)/resDnormG(k)-0.1)/9.9)/sqrt(10);
             admm.penaltyAdjust = true;
             Osch.iter = 0;
        end
    end
    hist.Rho(k) = Rho;
    if isStep == true
        if k==1
            figure;
            rplot = subplot(2,1,1);                                                                                                                    
            semilogy(rplot,1:k, max(1e-8, resPnormG), 'k',1:k, epsPG, 'k--',1:k, hist.Rho, 'k-.',  'LineWidth', 2); 
            ylabel('primal residual'); 
            axis([1 admm.MAX_ITER 10e-3 10e5]);
            grid on;
            hold (rplot,'off'); 
            dplot = subplot(2,1,2);                                                                                                                    
            semilogy(dplot,1:k, max(1e-8, resDnormG), 'k',1:k, epsDG, 'k--',1:k, hist.Rho, 'k-.', 'LineWidth', 2);   
            ylabel('dual residual'); xlabel('iter (k)');
            axis([1 admm.MAX_ITER 10e-3 10e5]);
            grid on
            hold (dplot,'off'); 
        else 
            hold (rplot,'on');                                                                                                                    
            semilogy(rplot,1:k, max(1e-8, resPnormG), 'k',1:k, epsPG, 'k--',1:k, hist.Rho, 'k-.',  'LineWidth', 2); 
            drawnow;
            hold (rplot,'off'); 
            hold (dplot,'on');                                                                                                                    
            semilogy(dplot,1:k, max(1e-8, resDnormG), 'k',1:k, epsDG, 'k--',1:k, hist.Rho, 'k-.', 'LineWidth', 2);  
            drawnow;
            hold (dplot,'off'); 
%             pause(0.05);
        end
    end    
    disp(['第' num2str(k) '次迭代:' num2str(toc) 's']);
end
admm.Rho = Rho;
admm.Solvetime = toc;
%% save results
if admm.Converge
    admm.Problem = 'Successfully solved';
    disp( 'Successfully solved');
    %-------------- fetch results --------------------------
    for a=1:A
        scuc_outC{a}=scuc_out{a};
    end
    save(resultFile ,'scuc_outC','ftie_avgC');
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
    save(resultFile ,'admm');
else
    admm.Problem = 'Unexpected Iterruption';
    disp( 'Unexpected Iterruption');
    save(resultFile ,'admm');
end
%% display error
if isPlot
    glog = figure;
    subplot(2,1,1);                                                                                                                    
    semilogy(1:k, max(1e-8, resPnormG), 'k',1:k, epsPG, 'k--',  'LineWidth', 2); 
    ylabel('primal residual'); 
    grid on;
    subplot(2,1,2);                                                                                                                    
    semilogy(1:k, max(1e-8, resDnormG), 'k',1:k, epsDG, 'k--', 'LineWidth', 2);   
    ylabel('dual residual'); xlabel('iter (k)');
    grid on;
    
    g = figure;
    subplot(2,1,1);                                                                                                                    
    plot(1:k, max(1e-8, resPnormG), 'k',1:k, epsPG, 'k--',  'LineWidth', 2); 
    ylabel('primal residual'); 
    subplot(2,1,2);                                                                                                                    
    plot(1:k, max(1e-8, resDnormG), 'k',1:k, epsDG, 'k--', 'LineWidth', 2);   
    ylabel('dual residual'); xlabel('iter (k)');
end
delete(gcp());