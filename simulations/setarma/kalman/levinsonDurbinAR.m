function [arParam,errFlag] = levinsonDurbinAR(arParamP)
%LEVINSONDURBINAR determines AR coefficients from partial AR coefficients using Levinson-Durbin recursions.
%
%SYNOPSIS [arParam,errflag] = LevinsonDurbinAR(arParamP)
%
%INPUT  arParamP : Partial autoregressive coefficients (row vector).
%
%OUTPUT arParam     : autoregressive coefficients (row vector).
%       errFlag     : 0 if function executes normally, 1 otherwise.
%
%REMARKS The recursion used is that presented in R. H. Jones,
%        "Maximum Likelihood Fitting of ARMA Models to Time Series with
%        Missing Observations", Technometrics 22: 389-395 (1980), Eq. 6.2. 
%
%Khuloud Jaqaman, July 2004

%initialize output
arParam = [];
errFlag = [];

%get AR order
arOrder = length(arParamP);

temp = [];
for i=1:arOrder
    temp = [temp zeros(2,1)];
    temp(2,i) = arParamP(i);
    for j=1:i-1
        temp(2,j) = temp(1,j) - arParamP(i)*temp(1,i-j);
    end
    temp(1,:) = temp(2,:);
end

arParam = temp(2,:);
