function [traj,errFlag] = brownianMotion(dimension,diffConst,totalTime,...
    timeStep,constrained,cRadius)
%BROWNIANMOTION simulates constrained/unconstrained Brownian motion in 1, 2 and 3D
%
%SYNOPSIS [traj,errFlag] = brownianMotion(dimension,diffConst,totalTime,...
%    timeStep,constrained)
%
%INPUT  dimension  : Dimension of space: 1, 2 or 3.
%       diffConst  : Diffusion constant.
%       totalTime  : Total time of simulation.
%       timeStep   : Simulation time step. Optional. Default: 0.1/diffConst.
%                    Use [] for default.
%       constrained: 1 for constrained Brownian motion, 0 for uncontrained
%                    motion. Optional. Default: 0. Use [] for default.
%       cRadius    : Confinement radius. Needed only in case of constrained
%                    motion.
%
%OUTPUT traj    : Trajectory of Brownian particle.
%       errFlag : 0 if function executes normally, 1 otherwise.
%
%Khuloud Jaqaman, October 2004

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Output
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

errFlag = 0;
traj = [];

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Input
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%check if correct number of arguments were used when function was called
if nargin < 3
    disp('--brownianMotion: Incorrect number of input arguments!');
    errFlag  = 1;
    return
end

%check dimensionality of space
if dimension ~=1 && dimension ~= 2 && dimension ~= 3
    disp('--brownianMotion: Variable "dimension" should be 1, 2 or 3!');
    errFlag = 1;
    return
end

%check whether diffusion constant is positive
if ~isempty(find(diffConst <= 0))
    disp('--brownianMotion: Variable "diffConst" should be positive!');
    errFlag = 1;
end

%check whether totalTime is positive
if totalTime <= 0
    disp('--brownianMotion: "totalTime" should be positive!');
    errFlag = 1;
end

%check simulation time step
if nargin < 4 %if "timeStep" is not provided by user
    timeStep = 0.1/diffConst; %use default
elseif isempty(timeStep) %if no value for timeStep is provided
    timeStep = 0.1/diffConst; %use default
elseif timeStep <= 0
    disp('--brownianMotion: "timeStep" should be positive!');
    errFlag = 1;
end

%check whether motion is constrained
if nargin < 5 %if "constrained" is not provided by user
    constrained = 0; %use default
elseif isempty(constrained) %if not value is provided
    constrained = 0; %use defatul
elseif constrained ~= 0 && constrained ~= 1
    disp('--brownianMotion: "constrained" should be 0 or 1!');
    errFlag = 1;
end

%check confinement radius if motion is constrained
if constrained
    if nargin < 6
        disp('--brownianMotion: Confinement radius must be input for constrained motion!');
        errFlag = 1;
    elseif cRadius <= 0
        disp('--brownianMotion: Confinement radius must be positive!');
    end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Trajectory generation
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%determine number of iterations to perform
numIterations = ceil(totalTime/timeStep) + 1;

%assuming that the step taken in a timeStep is normally distributed with mean
%zero, get standard deviation of distribution from diffusion constant
stepStd = sqrt(2*diffConst*timeStep);

%initialize output vector
traj = zeros(numIterations,dimension);

if constrained %if motion is confined within a certain region

    for i=2:numIterations %go over all time points

        %get displacement
        displacementVec = stepStd*randn(1,dimension);

        %calculate square of new distance from center
        distance2 = sum((traj(i-1,:)+displacementVec).^2);

        %if new distance is larger than confinement radius, then bounce
        %the particle back
        if distance2 > cRadius^2
            
            prevPosVec = traj(i-1,:); %previoue position
            displacement2 = sum(displacementVec.^2); %square of mag. of original displacement

            %determine fraction of original displacement within confinement region
            dispFrac = roots([displacement2 2*displacementVec*prevPosVec' ...
                (sum(prevPosVec.^2)-cRadius^2)]); %solve equation
            dispFrac = dispFrac(find(dispFrac>0)); %assign correct root
            dispFrac = dispFrac(find(dispFrac<1)); %to fraction
            
            %get vector within confinement region and vector to be reflected
            vecInside = dispFrac*displacementVec;
            vecToReflect = (1-dispFrac)*displacementVec;
            
            %get radius vector and surface normal
            radiusVec = prevPosVec + vecInside;
            unitNormal = radiusVec/cRadius;

            %find component of vector (to be reflected) along surface normal
            normalComp = vecToReflect*unitNormal';

            %reflect vector
            vecToReflect = vecToReflect - 2*normalComp*unitNormal;
            
            %calculate new position of particle
            traj(i,:) = radiusVec + vecToReflect;
            
            %fix new position in case algorithm messed up due to some
            %numerical inaccuracies
            distance2 = sum(traj(i,:).^2);
            if distance2 > cRadius^2
                traj(i,:) = traj(i,:)*0.999*cRadius/sqrt(distance2);
            end

        else
            
            traj(i,:) = traj(i-1,:) + displacementVec;
        
        end %(if distance2 > cRadius^2)
        
    end %(for i=2:numIterations)

else %if motion is not constrained

    for i=2:numIterations %go over all time points

        %get particle's position at this time point
        traj(i,:) = traj(i-1,:) + stepStd*randn(1,dimension);

    end %(for i=2:numIterations)
    
end %(if constrained)


%%%%% ~~ the end ~~ %%%%%
