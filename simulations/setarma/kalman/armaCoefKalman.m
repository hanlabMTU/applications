function [arParamK,maParamK,arParamL,maParamL,varCovMat,wnVariance,...
    wnVector,aic,errFlag] = armaCoefKalman(trajectories,arParamP0,...
    maParamP0,minOpt)
%ARMACOEFKALMAN fits an ARMA(p,q) model to a time series which could have missing data points.
%
%SYNOPSIS [arParamK,maParamK,arParamL,maParamL,varCovMat,wnVariance,...
%    wnVector,aic,errFlag] = armaCoefKalman(trajectories,arParamP0,...
%    maParamP0,minOpt)
%
%INPUT  trajectories: Observations of time series to be fitted. Either an 
%                     array of structures traj(1:nTraj).observations, or a
%                     2D array representing one single trajectory. 
%           .observations: 2D array of measurements and their uncertainties.
%                     Missing points should be indicated with NaN.
%       arParamP0   : Initial guess of partial autoregressive coefficients (row vector).
%       maParamP0   : Initial guess of partial moving average coefficients (row vector).
%       minOpt      : Optional. Minimization option: 
%                     -'ml' for Matlab local minimizer "fmincon";
%                     -'tl' for Tomlab local minimizer "ucSolve";
%                     -'tg' for Tomlab global minimizer "glbFast"' followed
%                       by Tomlab local minimizer "ucSolve";
%                     -'nag' for NAG's local minimizerE04JAF.
%                     Default: 'ml'
%
%OUTPUT arParamK    : Estimated AR parameters using likelihood maximization.
%       maParamK    : Estimated MA parameters using likelihood maximization.
%       arParamL    : Estimated AR parameters using least squares fitting.
%       maParamL    : Estimated MA parameters using least squares fitting.
%       varCovMat   : Variance-covariance matrix of ARMA coefficients, 
%                     estimated via least squares fitting.
%       wnVariance  : Estimated variance of white noise in process.
%       wnVector    : Structure array containing the field:
%           .observations: Estimated white noise series in corresponding 
%                          trajectory.
%       aic         : Akaike's Information Criterion.
%       errFlag     : 0 if function executes normally, 1 otherwise.
%
%REMARKS The Kalman filter & likelihood maximization algorithm implemented 
%        here is that presented in R. H. Jones, "Maximum Likelihood Fitting
%        of ARMA Models to Time Series with Missing Observations",
%        Technometrics 22: 389-395 (1980). All equation numbers used here 
%        are those in that paper. The main difference is that I do not 
%        estimate the observational error variance, but use that obtained 
%        from experimental data or simulated trajectories (and is thus 
%        time-dependent). 
%
%        After the ARMA coefficients and white noise in process are
%        estimated using the above algorithm, the latter is used to do a
%        least squares fitting of an ARMA model to the data. From this, one
%        gets another estimate of the ARMA cofficients, as well as the
%        variance-covariance matrix of the estimated coefficients. Note
%        that the values of the ARMA coeffients obtained via the two
%        methods should agree with each other.
%
%        Finally, trajectories are shifted to get zero mean before analysis
%        is done.
%
%Khuloud Jaqaman, July 2004

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Output
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

arParamK = [];
maParamK = [];
arParamL = [];
maParamL = [];
varCovMat = [];
wnVariance = [];
wnVector = [];
aic = [];
errFlag = 0;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Input
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%check whether correct number of input arguments was used
if nargin < 3
    disp('--armaCoefKalman: Incorrect number of input arguments!');
    errFlag  = 1;
    return
end

%check trajectory and turn it into struct if necessary
if ~isstruct(trajectories)
    tmp = trajectories;
    clear trajectories
    trajectories.observations = tmp;
    clear tmp
elseif ~isfield(trajectories,'observations')
    disp('--autoCorr: Please input the trajectories in fields ''observations''')
    errFlag = 1;
    return
end

%get number of trajectories and add column for observational error if necessary
trajOriginal = trajectories;
for i=1:length(trajectories);
    traj = trajectories(i).observations;
    [trajLength,nCol] = size(traj);
    if nCol ~= 2
        if nCol == 1 %if no error is supplied, it is assumed that there is no observational error
            traj = [traj zeros(trajLength,1)];
        else
            disp('--armaCoefKalman: "trajectories.observations" should have either 1 column for measurements, or 2 columns: 1 for measurements and 1 for measurement uncertainties!');
            errFlag = 1;
        end
    end
    trajectories(i).observations = traj;
end

%get arOrder and check partial AR coefficients
[nRow,arOrder] = size(arParamP0);
if ~isempty(arParamP0)
    if nRow ~= 1
        disp('--armaCoefKalman: "arParamP0" should be a row vector!');
        errFlag = 1;
    end
    if ~isempty(find(abs(arParamP0)>=1))
        disp('--armaCoefKalman: All entries in "arParamP0" should be smaller than 1 in magnitude!');
        errFlag = 1;
    end
end

%get maOrder and check partial MA coefficients
[nRow,maOrder] = size(maParamP0);
if ~isempty(maParamP0)
    if nRow ~= 1
        disp('--armaCoefKalman: "maParamP0" should be a row vector!');
        errFlag = 1;
    end
    if ~isempty(find(abs(maParamP0)>=1))
        disp('--armaCoefKalman: All entries in "maParamP0" should be smaller than 1 in magnitude!');
        errFlag = 1;
    end
end

%check whether minOpt has one of the required values
if nargin == 3
    minOpt = 'ml';
else
    if (~strcmp(minOpt,'ml') && ~strcmp(minOpt,'tl') ...
            && ~strcmp(minOpt,'tg') && ~strcmp(minOpt,'nag'))
        disp('--armaCoefKalman: "minOpt" should be either "ml", "tl" or "tg"!');
        errFlag = 1;
    end
end

%exit function if there are problems in input data
if errFlag
    disp('--armaCoefKalman: Please fix input data!');
    return
end

%obtain number of available observations and shift trajectories to get zero mean
for i=1:length(trajectories)
    
    traj = trajectories(i).observations;
    numAvail(i) = length(find(~isnan(traj(:,1)))); %get # of available points
    traj(:,1) = traj(:,1) - nanmean(traj(:,1)); %shift trajectory
    trajectories(i).observations = traj;

end
totAvail = sum(numAvail); %calculate total number of available points

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Maximum likelihood estimation of model
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

switch minOpt

    case 'ml' %local minimization using Matlab's fmincon

        %define optimization options.
        options = optimset('Display','final','DiffMaxChange',1e-3,...
            'DiffMinChange',1e-8,'TolFun',1e-4,'TolX',1e-4,...
            'maxFunEvals',4000,'maxIter',3000);

        %define structure containing additional parameters
        %note that it's written in Tomlab notation for convenience
        prob.user.arOrder = arOrder;
        prob.user.trajectories = trajectories;
        prob.user.numAvail = totAvail;

        %initial parameter values
        param0 = [arParamP0 maParamP0];

        %minimize -2ln(likelihood) using fmincon
        [params,fval,exitFlag] = fmincon(@neg2LnLikelihood,param0,[],...
            [],[],[],-0.99*ones(1,arOrder+maOrder),0.99*ones(1,...
            arOrder+maOrder),[],options,prob);

        %proceed if minimization was successful
        if exitFlag > 0
            proceed = 1;
        else
            proceed = 0;
        end

    case 'tl' %local minimization using Tomlab's ucSolve

        %initial parameter values
        param0 = [arParamP0 maParamP0];

        %define local minimizaton problem
        prob = conAssign('neg2LnLikelihood',[],[],[],-0.99*ones(1,...
            arOrder+maOrder),0.99*ones(1,arOrder+maOrder),'locMinNegLik',...
            param0);
        prob.PriLevOpt = 1;
        prob.optParam.MaxFunc = 4000;
        prob.optParam.MaxIter = 4000;
        %         prob.optParam.IterPrint = 1;
        prob.user.arOrder = arOrder;
        prob.user.trajectories = trajectories;
        prob.user.numAvail = totAvail;
        %         prob.Solver.Alg = 1;

        %minimize -2ln(likelihood) using Tomlab's ucSolve
        result = tomRun('ucSolve',prob,[],2);

        %proceed if minimization was successful
        if result.ExitFlag == 0
            params = result.x_k';
            proceed = 1;
        else
            proceed = 0;
        end

    case 'tg' %global minimization using Tomlab's glbFast and ucSolve

        %initial parameter values
        param0 = [arParamP0 maParamP0];

        %define global minimization problem
        prob = glcAssign('neg2LnLikelihood',-0.99*ones(1,arOrder+maOrder),...
            0.99*ones(1,arOrder+maOrder),'globMinNegLik',[],[],[],[],[],...
            [],param0);

        prob.PriLevOpt = 1;
        prob.optParam.MaxFunc = 300;
        prob.optParam.MaxIter = 300;
        %         prob.optParam.IterPrint = 1;
        prob.user.arOrder = arOrder;
        prob.user.trajectories = trajectories;
        prob.user.numAvail = totAvail;

        %find global minimum of -2ln(likelihood) using Tomlab's glbFast
        result = tomRun('glbFast',prob,[],2);

        if result.ExitFlag == 0 %if global minimization was successful
            paramI = result.x_k(:,1)'; %use its results as initial guess for local minimization
        else %if global minimization failed
            paramI = param0; %use user's initial guess as initial guess for local minimization
        end

        %define local minimizaton problem
        prob = conAssign('neg2LnLikelihood',[],[],[],-0.99*ones(1,...
            arOrder+maOrder),0.99*ones(1,arOrder+maOrder),'locMinNegLik',...
            paramI);
        prob.PriLevOpt = 1;
        prob.optParam.MaxFunc = 1000;
        prob.optParam.MaxIter = 1000;
        %         prob.optParam.IterPrint = 1;
        prob.user.arOrder = arOrder;
        prob.user.trajectories = trajectories;
        prob.user.numAvail = totAvail;

        %refine minimum using ucSolve
        result = tomRun('ucSolve',prob,[],2);

        %proceed if minimization was successful
        if result.ExitFlag == 0
            params = result.x_k';
            proceed = 1;
        else
            proceed = 0;
        end

    case 'nag' %local minimization using NAG's E04JAF

        %define structure containing parameters required for function
        %evaluation; they are written in Tomlab notation for convenience
        prob.user.arOrder = arOrder;
        prob.user.trajectories = trajectories;
        prob.user.numAvail = totAvail;

        %save "prob" in file "funct1Input" so that funct1 loads the
        %variables when called.
        save('funct1Input','prob');
        
        %initial parameter values
        params = [arParamP0 maParamP0];

        [params,fval,lowerB,upperB,exitFlag] = ...
            e04jaf(params,[-0.99*ones(1,arOrder+maOrder)],...
            [0.99*ones(1,arOrder+maOrder)],0);

        %proceed if minimization was successful
        if (exitFlag == 0 || exitFlag == 5 || exitFlag == 6)
            params = params';
            proceed = 1;
        else
            proceed = 0;
        end

end %(switch minOpt)

%if minimization was successful
if proceed

    %assign parameters obtained through minimization
    arParamP = params(1:arOrder);
    maParamP = params(arOrder+1:end);

    %get AR and MA coefficients from the partial AR and MA coefficients, respectively
    if ~isempty(arParamP)
        [arParamK,errFlag] = levinsonDurbinAR(arParamP);
    else
        arParamK = [];
    end
    if ~isempty(maParamP)
        [maParamK,errFlag] = levinsonDurbinMA(maParamP);
    else
        maParamK = [];
    end

    %check for causality and invertibility of estimated model
    %these two criteria should be taken care of by using the partial AR and
    %MA coefficients, but I do this check just in case something goes wrong
    r = abs(roots([-arParamK(end:-1:1) 1]));
    if ~isempty(find(r<=1))
        disp('--armaCoefKalman: Predicted model not causal!');
        errFlag = 1;
        return
    end
    r = abs(roots([maParamK(end:-1:1) 1]));
    if ~isempty(find(r<=1))
        disp('--armaCoefKalman: Predicted model not invertible!');
        errFlag = 1;
        return
    end

    %obtain likelihood, white noise sequence and white noise variance
    sum1 = 0;
    sum2 = 0;
    for i = 1:length(trajectories)

        %get the innovations, their variances and the estimated white noise series
        %using Kalman prediction and filtering
        [innovation,innovationVar,wnVector(i).observations,errFlag] = ...
            armaKalmanInnov(trajectories(i).observations,arParamK,maParamK);
        if errFlag
            disp('--armaCoefKalman: "armaKalmanInnov" did not function properly!');
            return
        end

        %calculate white noise variance of current trajectory
        wnVarianceSamp(i) = nanmean(innovation.^2./innovationVar);

        %1st sum in Eq. 3.15
        sum1 = sum1 + nansum(log(innovationVar));
        %2nd sum in Eq. 3.15
        sum2 = sum2 + nansum(innovation.^2./innovationVar);

    end %(for i = 1:length(trajectories))

    %calculate -2ln(likelihood)
    neg2LnLikelihoodV = sum1 + totAvail*log(sum2);

    %calculate mean white noise variance of all trajectories
    wnVariance = sum(numAvail.*wnVarianceSamp)/totAvail;

    %get number of parameters estimated: arOrder AR coefficients, maOrder MA
    %coefficients and white noise variance
    numParam = arOrder + maOrder + 1;

    %evaluate Akaike's Information Criterion
    aic = neg2LnLikelihoodV + 2*numParam;

    %evaluate the bias-corrected Akaike's Information Criterion
    aicc = neg2LnLikelihoodV + 2*numParam*totAvail/(totAvail-numParam-1);

    %put partial coefficients in 2nd row of coefficients matrix
    arParamK(2,:) = arParamP;
    maParamK(2,:) = maParamP;

else %if minimization was not successful
    
    errFlag = 1;
    return
    
end %(if proceed)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Least squares fitting
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%reformulate the problem as a least square fitting and obtain the
%variance-covariance matrix of the estimated ARMA coefficients
[varCovMat,arParamL,maParamL,errFlag] = armaVarCovLS(trajOriginal,...
    wnVector,length(arParamK(1,:)),length(maParamK(1,:)));

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Post-processing
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%check if parameters found through least squares fitting are statistically
%equivalent to those found through maximum likelihood estimation with
%Kalman filtering. If they are not equivalent, then results cannot be
%trusted and model is skipped

%prepare input
armaCoef1.arParam = arParamK(1,:);
armaCoef1.maParam = maParamK(1,:);
armaCoef2.arParam = arParamL;
armaCoef2.maParam = maParamL;

%compare parameters
[H,errFlag] = armaCoefComp(armaCoef1,varCovMat,armaCoef2,varCovMat);

%report failure of fit and do not consider results if coefficients are significantly different
if H == 1
    disp('--armaCoefKalman: Discrepency beween least squares and maximum likelihood!')
    errFlag = 1;
    return
end

%check whether residuals are white noise. If not, then fit is not good
%enough and model is skipped

%portmanteau test
[H,errFlag] = portmanteau(wnVector,20,0.01);

%report failure of fit and do not consider results if residuals are not white noise
if H == 1
    disp('--armaCoefKalman: Residuals did not pass portmanteau test!')
    errFlag = 1;
    return
end

%turning point test
[H,errFlag] = turningPointTest(wnVector,0.01);

%report failure of fit and do not consider results if residuals are not white noise
if H == 1
    disp('--armaCoefKalman: Residuals did not pass turning point test!')
    errFlag = 1;
    return
end

%difference sign test
[H,errFlag] = differenceSignTest(wnVector,0.01);

%report failure of fit and do not consider results if residuals are not white noise
if H == 1
    disp('--armaCoefKalman: Residuals did not pass difference sign test!')
    errFlag = 1;
    return
end

%%%%% ~~ the end ~~ %%%%%
