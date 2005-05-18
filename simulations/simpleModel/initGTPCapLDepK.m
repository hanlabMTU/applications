function [initialState,modelParam,runInfo,saveTraj,saveStats] = initGTPCapLDepK
%INITGTPCAPLDEPK initializes input variables for analyzeMtTrajectory

%If mtGTPCapLDepK alone is called, runInfo and saveStats are not needed.

%See function "mtGTPCapLDepK" for details.
initialState = struct('mtLength0',3,'capSize0',3,'unitConc',20);

%See function "analyzeMtTrajectory" for description of variables 
runInfo = struct('maxNumSim',1,'totalTime',1000,'simTimeStep',0.5,'timeEps',0.9,...
    'expTimeStep',0.01,'aveInterval',1);

%See function "mtGTPCapLDepK" for meanings and units of variables
modelParam = struct('minLength',0,'maxLength',10,'kTOnTFree',0.03,'addAmpT',0,...
    'addWidT',15,'addLenT',0.62,'kTOff',0.0,'kTOnD',0.023,'kDOffFree',0.9,'addAmpD',0,...
    'addWidD',15,'addLenD',0.6,'kHydrolysis',0.99);

%Indicates whether and where generated trajectories trajectories should be saved
saveTraj = struct('saveOrNot',0,'fileName','tempTraj');

%Indicated whether and where trajectory statistics should be saved
saveStats = struct('saveOrNot',0,'fileName','tempStat');
