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
MAX_ITER = 100;
epsP     = 1;
epsD     = 1e-1;
Rho      = 0.001;
alpha    = 1;
% parpool(A);
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
    spmd
        ftie_avg_old = ftie_avg;
        % fetch z
        ftie_avg = ftie_avgC{labindex};
        % update y
        lamda = lamda + Rho*(ftie_out - ftie_avg);
        resP  = (ftie_out - ftie_avg);
        resD  = Rho*(ftie_avg-ftie_avg_old);   
        quiet = (all(all(resP <= epsP)))&&(all(all(resD <= epsD)));
    end
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