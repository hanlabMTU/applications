    function [traj,errFlag] = simSETARMA(nThresholds,vThresholds,delay,arOrder,...
    maOrder,arParam,maParam,noiseSigma,trajLength)
%SIMSETARMA simulates a Self Exciting Threshold Autoregressive Moving Average trajectory
%
%SYNOPSIS [traj,errFlag] = simSETARMA(nThresholds,vThresholds,delay,arOrder,...
%    maOrder,arParam,maParam,noiseSigma,trajLength)
%
%INPUT  nThresholds : Number of thresholds.
%       vThresholds : Column vector (of size nThresholds) of values of thresholds, 
%                     sorted in increasing order.
%       delay       : Time lag of value compared to vThresholds.
%       arOrder     : Order of autoregressive part.
%       maOrder     : Order of moving average part.
%       arParam     : (nThresholds+1) by arOrder matrix of autoregression parameters.
%       maPAram     : (nThresholds+1) by maOrder matrix of moving average parameters.
%       noiseSigma  : Standard deviation of noise used in simulation (noise mean = 0).
%       trajLength  : Length of trajectory to be simulated.
%
%OUTPUT traj        : Simulated trajectory.
%       errFlag     : 0 if function executes normally, 1 otherwise.
%
%Khuloud Jaqaman, February 2004

errFlag = 0;

%check if correct number of arguments were used when function was called
if nargin ~= nargin('simSETARMA')
    disp('--simSETARMA: Incorrect number of input arguments!');
    errFlag  = 1;
    traj = [];
    return
end

%check input data
if nThresholds < 0
    disp('--simSETARMA: "nThresholds" should be a nonnegative integer!');
    errFlag = 1;
end
if length(vThresholds) ~= nThresholds
    disp('--simSETARMA: Number of elements in "vThresholds" should equal "nThresholds"!');
    errFlag = 1;
else
    if min(vThresholds(2:end)-vThresholds(1:end-1)) <= 0
        disp('--simSETARMA: Entries in "vThresholds" should be sorted in increasing order, with no two elements alike!');
        errFlag = 1;
    end
end
if delay <= 0
    disp('--simSETARMA: "delay" should be a positive integer');
    errFlag = 1;
end
if arOrder < 0
    disp('--simSETARMA: "arOrder" should be a nonnegative integer!');
    errFlag = 1;
end
if maOrder < 0
    disp('--simSETARMA: "maOrder" should be a nonnegative integer!');
    errFlag = 1;
end
if errFlag
    disp('--simSETARMA: Please fix input data!');
    traj = [];
    return
end
if arOrder ~= 0
    [nRow,nCol] = size(arParam);
    if nRow ~= nThresholds+1
        disp('--simSETARMA: Wrong number of rows in "arParam"!');
        errFlag = 1;
    end
    if nCol ~= arOrder
        disp('--simSETARMA: Wrong number of columns in "arParam"!');
        errFlag = 1;
    end
    for i = 1:nThresholds+1
        r = abs(roots([-arParam(i,end:-1:1) 1]));
        if ~isempty(find(r<=1))
            disp('--simSETARMA: Causality requires the polynomial defining the autoregressive part of the model not to have any zeros for z <= 1!');
            errFlag = 1;
        end
    end
end
if maOrder ~= 0
    [nRow,nCol] = size(maParam);
    if nRow ~= nThresholds+1
        disp('--simSETARMA: Wrong number of rows in "maParam"!');
        errFlag = 1;
    end
    if nCol ~= maOrder
        disp('--simSETARMA: Wrong number of columns in "maParam"!');
        errFlag = 1;
    end
    for i = 1:nThresholds+1
        r = abs(roots([maParam(i,end:-1:1) 1]));
        if ~isempty(find(r<=1))
            disp('--simSETARMA: Invertibility requires the polynomial defining the moving average part of the model not to have any zeros for z <= 1!');
            errFlag = 1;
        end
    end
end
if noiseSigma < 0
    disp('--simSETARMA: "noiseSigma" should be nonnegative!');
    errFlag = 1;
end
if trajLength <= 0
    disp('--simSETARMA: "trajLength" should be a nonnegative integer!');
    errFlag = 1;
end
if errFlag
    disp('--simSETARMA: Please fix input data!');
    traj = [];
    return
end

vThresholds = [-Inf; vThresholds; Inf];

shift = max(max(arOrder,maOrder)-1,delay);
tempL = trajLength+10*shift;

noise = idinput(tempL,'rgs',[],[-noiseSigma noiseSigma]); %noise in simulation

traj = zeros(tempL,1); %initialize trajectory

for t = shift+1:tempL
    level = find(((vThresholds(1:end-1)<=traj(t-delay)) + ...
        (vThresholds(2:end)>traj(t-delay))) == 2);
    traj(t) = noise(t);
    for i = 1:arOrder
        traj(t) = traj(t) + arParam(level,i)*traj(t-i);
    end
    for i = 1:maOrder
        traj(t) = traj(t) + maParam(level,i)*noise(t-i);
    end
end

traj = traj(10*shift+1:end);

