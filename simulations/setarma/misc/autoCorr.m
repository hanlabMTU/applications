function [gamma,errFlag] = autoCorr(traj,maxLag)
%AUTOCORR calculates the unbiased autocorrelation function of a time series with missing data points
%
%SYNOPSIS [gamma,errFlag] = autoCorr(traj,maxLag)
%
%INPUT  traj   : Time series whose autocorrelation function is to be
%                calculated. Missing points should be indicated with NaN.
%       maxLag : Maximum lag at which autocorrelation function is calculated.

%
%OUTPUT gamma  : Unbiased autocorrelation function of series, 
%                where gamma(i) is the autocovariance at lag i-1.
%       errFlag: 0 if function executes normally, 1 otherwise.
%
%Khuloud Jaqaman, April 2004

errFlag = 0;

%check if correct number of arguments were used when function was called
if nargin ~= nargin('autoCorr')
    disp('--autoCorr: Incorrect number of input arguments!');
    errFlag  = 1;
    gamma = [];
    return
end

%check input data
if maxLag <= 0
    disp('--autoCorr: Variable "maxLag" should be a positive integer!');
    errFLag = 1;
end
if length(traj) < 5*maxLag
    disp('--autoCorr: Trajectory length should be at least 5*maxLag!');
    errFlag = 1;
end
if errFlag
    disp('--autoCorr: Please fix input data!');
    gamma = [];
    return
end

%get series mean
trajMean = mean(traj(find(~isnan(traj))));

%calculate unnormalized autocorrelation function for lags 0 through maxLag
gamma = zeros(maxLag+1,1);
for i = 0:maxLag 
    
    %find tentative pairs of points to be used in calculation
    vec1 = traj(1:end-i);
    vec2 = traj(i+1:end);
    
    %remove all pairs with a missing point in the first vector
    indx = find(~isnan(vec1));
    vec1 = vec1(indx);
    vec2 = vec2(indx);
    
    %remove all pairs with a missing point in the second vector
    indx = find(~isnan(vec2));
    vec1 = vec1(indx) - trajMean;
    vec2 = vec2(indx) - trajMean;
    
    %calculare the autocorrelation function
    gamma(i+1) = mean(vec1.*vec2);
    
end

%normalize the autocorrelation function
gamma = gamma/gamma(1);
