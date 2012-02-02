function stepInfo = process3DMigrationMovie(movieData,varargin)
%PROCESS3DMIGRATIONMOVIE - runs all necessary analysis/processing steps on the input 3D movie
% 
% stepInfo = process3DMigrationMovie(movieData3D);
% stepInfo = process3DMigrationMovie(movieData3D,'OptionName1',optionValue1,...);
% 
% This function runs all necessary processing and analysis steps on the
% input 3D migration movie. Individual processing steps will be run if they
% meet ANY of the following criteria:
%
%   -The process has not been run yet successfully
%   -The process has been run, but with different parameters than currently specified
%   -The process depends on output from a process which is going to be run.
%   -The ForceRun option has been enabled for this or all processes
%
% completed with the same parameter values will not be run, unless forceRun
% is enabled, or if a step which it depends on is to be run.
% 
%
%   Processing functions which are run include, in this order:
% 
%       1 - segment3DMovie.m
%       2 - analyze3DMovieMaskGeometry.m
%       3 - skeletonize3DMovieMasks.m
%       4 - prune3DMovieSkeletonBranches.m
%       5 - track3DMaskObjects.m
%
% Input: 
% 
%   movieData3D - the MovieData3D object describing the movie to analyze.
% 
%   'OptionName',optionValue - A string giving an option name followed by
%   the value for that option. Available options are:
% 
%       ('OptionName'->possible values)
% 
%       ('ChannelIndex -> positive integer scalar) The index of the
%       channel to use for segmentation.
%       Default is 1.
%       
%       ('BatchMode'->logical scalar) If true, graphical output (figures,
%       progress bars, etc) will be suppressed in this function and in each
%       processing step.
% 
%       ('ForceRun'->integer scalar or vector) This specifies under what
%       conditions to run each step. If input as a scalar, the same value
%       is used for all steps, if a vector then it specifies a different
%       value for each step. If = 0 then the step is run if it hasn't been
%       run previously, if parameters have changed, or if a step it depends
%       on is being Run. If =1 the step is run no matter what. If = -1, the
%       step is will not be run no matter what. Use caution when setting
%       ForceRun to -1 as this will override dependencies!
%       Optional. Default is 0 for all steps.
%   
%       Additionally, parameters for a specific step can be passed to the
%       function for that step using this format:
%
%           '#OptionName',optionValue
%
%       Where % is the number of that step. For example, to pass the option
%       "ShowPlots"=1 to step 3, you would input:
%       
%           process3DMigrationMovie(movieData,'3ShowPlots',1)
%
%
% Output:
%
%   stepInfo- A cell array the same size as the number of steps containing
%   information about the steps, including the time they took to run, any
%   error messages that were generated by the processing functions, etc. If
%   a step wasn't attempted, the corresponding element in this array will
%   be empty.
%
%
% Hunter Elliott      
% 4/2011
%

%% ------------- Parameters --------------------- %%
%Hard-coded parameters determining order, functions and parameters for
%processing. Not the ideal way to set this up, but it works...

%**NOTE***: This should all be contained in a Package class definition, and
%3d migration should be implemented as a package, but I'm waiting on
%revisions to the package class - HLE (TEMP)

%Function handles for calling processing functions
funHands = {@segment3DMovie,...                         % 1
            @analyze3DMovieMaskGeometry,...             % 2
            @skeletonize3DMovieMasks,...                % 3
            @prune3DMovieSkeletonBranches,...           % 4
            @track3DMaskObjects};                       % 5
%Process names corresponding to each function
processNames = {'SegmentationProcess3D',...             % 1
                'MaskGeometry3DProcess',...             % 2
                'SkeletonizationProcess',...            % 3
                'SkeletonPruningProcess',...            % 4
                'MaskObjectTrackingProcess'};           % 5

%Dependency matrix for processing functions            
          %   1 2 3 4 5
depMat    = [ 0 0 0 0 0;   % 1
              1 0 0 0 0;   % 2
              1 0 0 0 0;   % 3
              0 1 1 0 0;   % 4
              1 0 0 0 0];  % 5
            
nSteps = numel(funHands);
if numel(processNames) ~= nSteps
    error('Check hard-coded parameter values - number of process handles and names do not match!')
end

%% --------------------- Input ----------------------- %%


%Parse all the inputs
ip = inputParser;
ip.FunctionName = mfilename;
ip.KeepUnmatched = true; %Keep extra parameters for passing to processing functions
ip.addRequired('movieData',@(x)(isa(x,'MovieData3D')));
ip.addParamValue('ChannelIndex',1,@(x)(numel(x) == 1 && isposint(x)));
ip.addParamValue('BatchMode',false,(@(x)(numel(x)==1)));
ip.addParamValue('ForceRun',0,(@(x)(numel(x) == 1 || numel(x) == nSteps)));
ip.parse(movieData,varargin{:});

p = ip.Results;
procP = ip.Unmatched;%Unrecognized parameters will be passed to processing functions

%If scalar forceRun input, use it for all steps
if numel(p.ForceRun) == 1
    p.ForceRun = repmat(p.ForceRun,nSteps,1);
end

%Check the values in forceRun
if ~all(p.ForceRun == 1 | p.ForceRun == 0 | p.ForceRun == -1)
    error('the ForceRun option can only have values of 0, 1 or -1 !')
end

%% --------------------- Init ------------------------ %%


%Set common parameters for passing to every function
commonParams.ChannelIndex = p.ChannelIndex;
commonParams.BatchMode = p.BatchMode;

%Parse the step-specific parameters into the parameter array, if any are
%specified
funParams = parseStepParams(procP,commonParams,nSteps);


%Go through each step and determine if it needs to be run beforehand so we
%can let the user know what steps will be run.
runStep = true(1,nSteps);

for iStep = 1:nSteps
    
    if p.ForceRun(iStep) == 0
        %Check if this step has been successfully run previously
        iCurrProc = movieData.getProcessIndex(processNames{iStep},1,~p.BatchMode);      
        if ~isempty(iCurrProc) && movieData.processes_{iCurrProc}.checkChannelOutput(p.ChannelIndex)

            %If different parameters have been specified, run it anyways
            runStep(iStep) = hasParamChanged(funParams{iStep},movieData.processes_{iCurrProc});

        end
    elseif p.ForceRun(iStep) == 1
        runStep(iStep) = true;    
    end
    
end





%Process dependencies so that if a step is going to be run, we run all
%those steps which depend on it.
runStep = processDependencies(runStep,depMat);

%ForceRun of -1 overrides the dependencies
runStep(p.ForceRun == -1) = false;

if ~any(runStep)
    disp('All steps have already been successfully run with these settings - doing nothing. Enable the ForceRun option if you would like to run them anyways!');
    stepInfo = {};
    return
else
    %Tell the user which steps are going to be run
    iRunSteps = find(runStep);
    numStrings = arrayfun(@(x)([num2str(x) ' ']),iRunSteps,'UniformOutput',false);
    disp(['Starting processing, running step numbers: ' numStrings{:}])    
    stepInfo = cell(nSteps,1);
end

%% -------------------- Processing ------------------ %%
%Call the function for each necessary step with the specified parameters


for iStep = iRunSteps
                    
            
        try
            start = tic;%Start timer
            
            %Log the function and parameters used
            stepInfo{iStep}.function = funHands{iStep};
            stepInfo{iStep}.passedParameters = funParams{iStep};
            
            %Call the processing function for this step with its
            %parameters. We don't need the output because the only output
            %is the movieData, which is a handle
            funHands{iStep}(movieData,funParams{iStep});
            
            %Log the stats in the info array
            stepInfo{iStep}.runDuration = toc(start);                        
            
        catch em
            disp(['Error in step ' num2str(iStep) ' : ' em.message])
            stepInfo{iStep}.error = em;
            stepInfo{iStep}.errorAfter = toc(start);            
        end
            
        
end




%%  ----------------------- Sub-Routines --------------------- %%

function tf = hasParamChanged(par,proc)
%Sub-function for checking if new parameters have been specified. Returns
%true if the parameters have changed.

parField = fieldnames(par);
nPar = numel(parField);
procField = fieldnames(proc.funParams_);

%Go through each input parameter and compare it to the parameter stored in
%the process
tf = false;
for j = 1:nPar

    
    if any(strcmp(parField{j},procField)) 
        
        %Check if it has changed, ignoring the BatchMode parameter which
        %doesn't affect output.
        if ~strcmp(parField{j},'BatchMode') && ~isequalwithequalnans(par.(parField{j}),...
                proc.funParams_.(parField{j}))
                        
           %Return true, and stop checking further parameters.
           tf = true;
           break            
        end        
        
    else
        %warn the user that the parameter is not recognized by the process
        warning(['3DMigration:' mfilename ':unrecognizedParameter'],...
                ['Unrecognized parameter field "' parField{j} '" for process "' proc.name_ '"']);
    end            

end

function funParams = parseStepParams(procP,commonParams,nSteps)
%Parses any step-specific parameters into the funParams array for passing
%to the processing functions for a particular step

%Parse the common parameters to every element
funParams = cell(nSteps,1);
[funParams{:}] = deal(commonParams);


pFields = fieldnames(procP);
nFields = numel(pFields);    
for j = 1:nFields
    
    %Make sure there is a leading number, and get the number of digits
    iFirstChar = regexp(pFields{j},'\D','once');
    
    if isempty(iFirstChar) || iFirstChar == 1
        error(['Parameter "' pFields{j} '" is not recognized by ' mfilename ...
            ' and does not contain a leading number specifying a step number! Check input!'])
        
    end
    
    procNum = str2double(pFields{j}(1:(iFirstChar-1)));
    
    if isnan(procNum) || procNum > nSteps || ~isposint(procNum)
        error(['Invalid process number specified for parameter ' ...
            pFields{j} ' - check input!'])
    else
    
        funParams{procNum}.(pFields{j}(iFirstChar:end)) = procP.(pFields{j});
        
    end
        
    
end



function runStep = processDependencies(runStep,depMat)
%Handles process dependencies by ensuring that if a given step is run,
%those which depend on it will be run also.

nStep = numel(runStep);

%Go through each step and check if the steps it depends on are going to be
%run
for j = 1:nStep
    %Get all the steps this step depends on
    iDepSteps = [];
    iDepSteps = findDeps(depMat,j,iDepSteps);
    if ~isempty(iDepSteps) && any(runStep(iDepSteps))
        runStep(j) = true;
    end    
end

function iDep = findDeps(depMat,j,iDep)
%Recursive function for traversing dependency matrix to find dependencies

iPar = find(depMat(j,:));

if ~isempty(iPar)
    %Find the dependencies for this step also
    for j = 1:numel(iPar)
        iDep = [iPar findDeps(depMat,iPar(j),iDep)];       
    end
      
else
    iDep = [];
end




