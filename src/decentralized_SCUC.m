%%multi-area decentralized SCUC
matFile = {'data\testcase\areadata1.mat', 'data\testcase\areadata2.mat'};
parpool(2);
spmd
    scuc_in = load(matFile{labindex});
    scuc_model = scuc_modelDefine(scuc_in);
    scuc_out   = scuc_modelSolve(scuc_model);
end
delete(gcp());