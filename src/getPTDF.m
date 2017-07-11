function H = getPTDF(Nb, BR_Bus,BR_X, slack)
[row, Nl] = size(BR_Bus);
b = 1./ BR_X';                    %% series susceptance

%% build connection matrix Cft = Cf - Ct for line and from - to buses
f = BR_Bus(1,:)';                           %% list of "from" buses
t = BR_Bus(2,:)';                           %% list of "to" buses
i = [(1:Nl)'; (1:Nl)'];                         %% double set of row indices
Cft = sparse(i, [f;t], [ones(Nl, 1); -ones(Nl, 1)], Nl, Nb);    %% connection matrix

%% build Bf such that Bf * Va is the vector of real branch powers injected
%% at each branch's "from" bus
Bf = sparse(i, [f; t], [b; -b]);    % = spdiags(b, 0, Nl, Nl) * Cft;
%% build Bbus
Bbus = Cft' * Bf;
%% compute PTDF for single slack_bus
noref   = (2:Nb)';      %% use bus 1 for voltage angle reference
noslack = find((1:Nb)' ~= slack);
H = zeros(Nl, Nb);
H(:, noslack) = full(Bf(:, noref) / Bbus(noslack, noref));