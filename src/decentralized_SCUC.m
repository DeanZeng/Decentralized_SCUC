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
MAX_ITER = 4;
epsP     = 1;
epsD     = 1e-1;
Rho      = 0.001;
alpha    = 1;
quiet    = false(A,1);
parpool(A);
tic;
spmd
        % load data in work;
        scuc_in = load(matFile{labindex});
        % variables for ADMM
        lamda = zeros(scuc_in.T,scuc_in.Ntie);
        resP  = 10*ones(scuc_in.T,scuc_in.Ntie);
        resD  = 10*ones(scuc_in.T,scuc_in.Ntie);
        % tie data in client; 
        Ntie    = scuc_in.Ntie;
        TieArea = scuc_in.TieArea;
        TieBus  = scuc_in.TieBus;
        Tie_Bus  = scuc_in.Tie_Bus;
        % scuc model define in local work;
        scuc_model = scuc_modelDefine(scuc_in);
        ftie_avg = zeros(scuc_in.T,scuc_in.Ntie);
        %%--------------------------- x update --------------------------------
        [scuc_out,ftie_out] = scuc_modelSolve(scuc_model,ftie_avg,lamda,0);   
end
for a=1:A
    NtieC{a}     = Ntie{a};
    TieAreaC{a}  = TieArea{a};
    TieBusC{a}   = TieBus{a};
    Tie_BusC{a}  = Tie_Bus{a};
    ftie_outC{a} = ftie_out{a};
    ftie_avgC{a} = ftie_avg{a};
end
for k= 2:MAX_ITER
    %%--------------------------- z update --------------------------------
    for a=1:A
        ftie_outC{a} = ftie_out{a};
    end
    for a=1:A
        for la=1:NtieC{a}
            b  = TieAreaC{a}(la);
            ab = Tie_BusC{a};
            bb = TieBusC{a}(la);
            lb = find ( (TieAreaC{b}==a)&(TieBusC{b}==ab)&(Tie_BusC{b}== bb));
            %% communication
            ftie_avgC{a}(:,la,k) = 0.5*(ftie_outC{a}(:,la)-ftie_outC{b}(:,lb));
        end
    end
    spmd
            ftie_avg = ftie_avgC{labindex};
            lamda = lamda + Rho*(ftie_out - ftie_avg(:,:,k));
            resP  = (ftie_out - ftie_avg(:,:,k));
            resD  = Rho*(ftie_avg(:,:,k)-ftie_avg(:,:,k-1));   
            quiet = (all(all(resP <= epsP)))&&(all(all(resD <= epsD)));
    end
    QUIET = true;
    for a=1:A
        QUIET = QUIET && quiet{a};
    end
    if QUIET
        break;
    end
    spmd
        %%--------------------------- x update -------------------------------
        [scuc_out,ftie_out]   = scuc_modelSolve(scuc_model,ftie_avg(:,:,k),lamda,Rho);   
    end
    k
    toc;
end
delete(gcp());