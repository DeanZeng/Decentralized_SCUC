%%multi-area decentralized SCUC
matFile = {'data\testcase\areadata1.mat', 'data\testcase\areadata2.mat'};
A=2;       % number of area 
T=24;

NtieC    = cell(A,1);
TieAreaC = cell(A,1);
TieBusC  = cell(A,1);
Tie_BusC = cell(A,1);
ftie_outC= cell(A,1);
ftie_avgC= cell(A,1);

QUIET    = false;
MAX_ITER = 400;
epsP     = 1e-3;
epsD     = 1e-3;
ABSTOL   = 1;
RELTOL   = 1e-2;
Rho      = 10;
alpha    = 1;
% parpool(A);
%-------------- plot
figure(1)
ax11 = subplot(3,1,1);
hold on
ax12 = subplot(3,1,2);
hold on
ax13 = subplot(3,1,3);
hold on
figure(2)
ax21 = subplot(2,1,1);
hold on
ax22 = subplot(2,1,2);
hold on
figure(3)
ax31 = subplot(2,1,1);
hold on
ax32 = subplot(2,1,2);
hold on
%-------------- plot
tic;
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
    if k==1
        spmd
            %%--------------------------- x update -------------------------------
            [scuc_out,ftie_out] = scuc_modelSolve(scuc_model,ftie_avg,lamda,0);   
        end
    else 
        spmd
            %%--------------------------- x update -------------------------------
            [scuc_out,ftie_out] = scuc_modelSolve(scuc_model,ftie_avg,lamda,Rho);   
        end
    end
    %%--------------------------- z update --------------------------------
    % fetch x
    for a=1:A
        ftie_outC{a} = ftie_out{a};
    end
    for a=1:A
        for la=1:NtieC{a}
            b  = TieAreaC{a}(la);
            ab = Tie_BusC{a};
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
%         epsD)));     %¾ø¶ÔÎó²î
        quiet = (all(all(abs(resP) <= ABSTOL + abs(RELTOL.*ftie_avg))))&&(all(all(abs(resD) <= ABSTOL + abs(RELTOL.*lamda)))); %Ïà¶ÔÎó²î
    end
    %-------------- plot
    for a=1:A
        resPC{a} = resP{a};
        resDC{a} = resD{a};
        lamdaC{a}= lamda{a};
    end
    figure(1)
    plot(ax11, ftie_avgC{1});
    plot(ax12, ftie_outC{1});
    plot(ax13, -ftie_outC{2});
    figure(2)
    plot(ax21, abs(resPC{1}));
    hold(ax21, 'on')
    plot(ax21, ABSTOL + abs(RELTOL.*ftie_avgC{1}));
    hold(ax21, 'off')
    plot(ax22, abs(resDC{1}));
    hold on
    plot(ax22, ABSTOL + abs(RELTOL.*lamdaC{1}));
    hold off
    figure(3)
    plot(ax31, lamdaC{1});
    plot(ax32, lamdaC{2});
    %-------------- plot
    QUIET = true;
    for a=1:A
        QUIET = QUIET && quiet{a};
    end
    if QUIET
        break;
    end
    k
    toc;
end
% delete(gcp());