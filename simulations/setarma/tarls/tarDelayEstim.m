function [tarParam,varCovMat,residuals,noiseSigma,fitSet,delay,errFlag] = tarDelayEstim(...
    traj,vThresholds,delayTest,tarOrder,method,tol)
%TARLSESTIM0 fits a TAR model to a trajectory (which could have missing data points) using least squares.
%
%SYNOPSIS [tarParam,varCovMat,residuals,noiseSigma,fitSet,delay,errFlag] = tarDelayEstim(...
%    traj,vThresholds,tarOrder,method,tol)
%
%INPUT  traj         : Trajectory to be modeled (with measurement uncertainties).
%                      Missing points should be indicated with NaN.
%       vThresholds  : Column vector of thresholds, sorted in increasing order.
%       delayTest    : Values of delay parameter to be tested.
%       tarOrder     : Order of proposed TAR model in each regime.
%       method (opt) : Solution method: 'dir' (default) for direct least square 
%                      minimization using the matlab "\", 'iter' for iterative 
%                      refinement using the function "lsIterRefn".
%       tol (opt)    : Tolerance at which calculation is stopped.
%                      Needed only when method 'iter' is used. If not
%                      supplied, 0.001 is assumed. 
%
%OUTPUT tarParam     : Estimated parameters in each regime.
%       varCovMat    : Variance-covariance matrix of estimated parameters.
%       residuals    : Difference between measurements and model predictions.
%       noiseSigma   : Estimated standard deviation of white noise in each regime.
%       fitSet       : Set of points used for data fitting. Each column in 
%                      matrix corresponds to a certain regime. 
%       delay        : Time lag (delay parameter) of value compared to vThresholds.
%       errFlag      : 0 if function executes normally, 1 otherwise.
%
%Khuloud Jaqaman, April 2004

errFlag = 0;

%check if correct number of arguments was used when function was called
if nargin < 4
    disp('--tarDelayEstim: Incorrect number of input arguments!');
    errFlag  = 1;
    tarParam = [];
    varCovMat = [];
    residuals = [];
    noiseSigma = [];
    fitSet = [];
    delay = [];
    return
end

%check input data
dummy = size(delayTest,1);
if dummy ~= 1
    disp('--tarDelayEstim: "delayTest" must be a row vector!');
    errFlag = 1;
end
if errFlag
    disp('--tarDelayEstim: Please fix input data!');
    tarParam = [];
    varCovMat = [];
    residuals = [];
    noiseSigma = [];
    fitSet = [];
    delay = [];
    return
end

%check optional parameters
if nargin >= 5
    
    if ~strncmp(method,'dir',3) && ~strncmp(method,'iter',4) 
        disp('--tarDelayEstim: Warning: Wrong input for "method". "dir" assumed!');
        method = 'dir';
    end
    
    if strncmp(method,'iter',4)
        if nargin == 4
            if tol <= 0
                disp('--tarDelayEstim: Warning: "tol" should be positive! A value of 0.001 assigned!');
                tol = 0.001;
            end
        else
            tol = 0.001;
        end
    end
    
else
    method = 'dir';
    tol = [];
end

%initial sum of squares of residuals
sumSqResid = 1e20; %ridiculously large number

for delay1 = delayTest %go over all suggested delay parameters
    
    %estimate coeffients and residuals
    [tarParam1,varCovMat1,residuals1,noiseSigma1,fitSet1,errFlag] = tarlsestim0(...
        traj,vThresholds,delay1,tarOrder,method,tol);
    if errFlag
        disp('--tarDelayEstim: tarlsestim0 did not function properly!');
        tarParam = [];
        varCovMat = [];
        residuals = [];
        noiseSigma = [];
        fitSet = [];
        delay = [];
        return
    end
    
    %get sum over squares of all residuals
    sumSqResid1 = fitSet1(1,:)*noiseSigma1';
    
    %compare current sum over squared residuals to sum in previous delay parameter trial
    %if it is smaller, then update results
    if sumSqResid1 < sumSqResid
        tarParam = tarParam1;
        varCovMat = varCovMat1;
        residuals = residuals1;
        noiseSigma = noiseSigma1;
        fitSet = fitSet1;
        delay = delay1;
        sumSqResid = sumSqResid1;
    end
    
end %(for delay = delayTest)