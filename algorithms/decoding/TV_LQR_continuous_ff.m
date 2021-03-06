function r = TV_LQR_continuous_ff(model, r, currPos, rFactor)
% Continuous linear quadratic tracking controller with feedforward term
%
% Copyright (c) 2016 Idiap Research Institute
% Written by Ajay Tanwani, Danilo Bruno and Sylvain Calinon

%% LQR with feedforward term
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
nbData = size(r.currTar,2);
nbVarPos = model.nbVarPos;

%Definition of a double integrator system (DX = A X + B u with X = [x; dx])
A = kron([0 1; 0 0], eye(nbVarPos)); 
B = kron([0; 1], eye(nbVarPos)); 
%C = kron([1,zeros(1,model.nbDeriv-1)],eye(model.nbVarPos)); % Output Matrix (we assume we only observe position)

%Initialize Q and R weighting matrices
Q = zeros(model.nbVarPos*2, model.nbVarPos*2);
R = eye(model.nbVarPos) * rFactor;

P = zeros(model.nbVarPos*2, model.nbVarPos*2, nbData);
d = zeros(model.nbVarPos*2, nbData);

diagRegularizationFactor = 2E-3;

%%%% Compute the P at final time P at t=T using infinite horizon gain
%%%% evaluation
Q_T(1:model.nbVar,1:model.nbVar) = inv(r.currSigma(:,:,nbData) + diagRegularizationFactor*eye(model.nbVar)); 
% P_T = solveAlgebraicRiccati_eig(A, B/R*B', (Q_T+Q_T')/2); 
% K_T = R\B'*P_T; 
    
% sf = 1e-4;
% P(1:model.nbVar,1:model.nbVar,end) = inv(r.currSigma(:,:,nbData));
% P(1:model.nbVar,1:model.nbVar,end) = P_T;
P(1:model.nbVar,1:model.nbVar,end) = zeros(model.nbVar);

tar = zeros(model.nbVarPos*2,nbData);
tar(1:model.nbVar,:) = r.currTar;
% tar = [r.currTar; zeros(nbVarOut,nbData)];
dtar = gradient(tar,1,2)/model.dt;



%Backward integration of the Riccati equation
for t=nbData-1:-1:1
    Q(1:model.nbVar,1:model.nbVar) = inv(r.currSigma(:,:,t+1)  + diagRegularizationFactor*eye(model.nbVar));
%     Q(1:model.nbVar,1:model.nbVar) = eye(model.nbVar)*sf;
    P(:,:,t) = P(:,:,t+1) + model.dt * (A'*P(:,:,t+1) + P(:,:,t+1)*A - P(:,:,t+1)*B*(R\B')*P(:,:,t+1) + Q);        
    d(:,t) = d(:,t+1) + model.dt * ((A'-P(:,:,t+1)*B*(R\B'))*d(:,t+1) + P(:,:,t+1)*dtar(:,t+1) - P(:,:,t+1)*A*tar(:,t+1));
end

%% Reproduction with varying impedance parameters
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

x = currPos(1:nbVarPos);
dx = zeros(nbVarPos,1);

for t=1:nbData
    K(:,:,t) = R\B' * P(:,:,t);
    M(:,t) = R\B' * d(:,t);

    currTar = zeros(model.nbVarPos*2,1);
    currTar(1:model.nbVar) = r.currTar(:,t);
	%Compute acceleration (with both feedback and feedforward terms)	
	ddx = -K(:,:,t) * ([x;dx]-currTar) + M(:,t); 
	
	%Update velocity and position
	dx = dx + ddx * model.dt;
	x = x + dx * model.dt;

	%Log data (with additional variables collected for analysis purpose)
	r.Data(:,t) = x;
    r.dData(:,t) = dx;
	r.ddxNorm(t) = norm(ddx);
	%r.Kp(:,:,t) = L(:,1:nbVarPos,t);
	%r.Kv(:,:,t) = L(:,nbVarPos+1:end,t);
	r.kpDet(t) = det(K(:,1:nbVarPos,t));
	r.kvDet(t) = det(K(:,nbVarPos+1:end,t));
    r.P(:,:,t) = P(:,:,t);
    r.K(:,:,t) = K(:,:,t);
	%Note that if [V,D] = eigs(L(:,1:nbVarPos)), we have L(:,nbVarPos+1:end) = V * (2*D).^.5 * V'
end

