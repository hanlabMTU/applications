function correctMovieStageDrift(movieData,varargin)
% correctMovieStageDrift corrects stage drift using reference frame and channel
%
% correctMovieStageDrift 
%
% SYNOPSIS correctMovieStageDrift(movieData,paramsIn)
%
% INPUT   
%   movieData - A MovieData object describing the movie to be processed
%
%   paramsIn - Structure with inputs for optional parameters. The
%   parameters should be stored as fields in the structure, with the field
%   names and possible values as described below
%
% OUTPUT   

% Sebastien Besson, Sep 2011

%% ----------- Input ----------- %%

%Check input
ip = inputParser;
ip.CaseSensitive = false;
ip.addRequired('movieData', @(x) isa(x,'MovieData'));
ip.addOptional('paramsIn',[], @isstruct);
ip.parse(movieData,varargin{:});
paramsIn=ip.Results.paramsIn;

%Get the indices of any previous stage drift processes                                                                     
iProc = movieData.getProcessIndex('StageDriftCorrectionProcess',1,0);

%If the process doesn't exist, create it
if isempty(iProc)
    iProc = numel(movieData.processes_)+1;
    movieData.addProcess(StageDriftCorrectionProcess(movieData,...
        movieData.outputDirectory_));                                                                                                 
end
displFieldProc = movieData.processes_{iProc};
%Parse input, store in parameter structure
p = parseProcessParams(displFieldProc,paramsIn);

%% --------------- Initialization ---------------%%
if feature('ShowFigureWindows')
    wtBar = waitbar(0,'Initializing...','Name',displFieldProc.getName());
end

% Reading various constants
imDirs  = movieData.getChannelPaths;
imageFileNames = movieData.getImageFileNames;
bitDepth = movieData.camBitdepth_;
nFrames = movieData.nFrames_;
maxIntensity =(2^bitDepth-1);

% Set up the input directories (input images)
inFilePaths = cell(3,numel(movieData.channels_));
for j = p.ChannelIndex
    inFilePaths{1,j} = imDirs{j};
end
displFieldProc.setInFilePaths(inFilePaths);
    
% Set up the output directories
outFilePaths = cell(4,numel(movieData.channels_));
for i = p.ChannelIndex;    
    %Create string for current directory
    outFilePaths{1,i} = [p.OutputDirectory filesep 'channel_' num2str(i)];
    mkClrDir(outFilePaths{1,i});
end
[~,refName,refExt]=fileparts(movieData.processes_{1}.funParams_.referenceFramePath);
outFilePaths{2,p.ChannelIndex(1)} = [p.OutputDirectory filesep refName refExt];
outFilePaths{3,p.ChannelIndex(1)} = [p.OutputDirectory filesep 'transformationMatrix.mat'];
outFilePaths{4,p.ChannelIndex(1)} = [p.OutputDirectory filesep 'flow_for_channel_' num2str(p.ChannelIndex(1))];
outFilePaths{5,p.ChannelIndex(1)} = [p.OutputDirectory filesep 'x_flow.fig'];
outFilePaths{6,p.ChannelIndex(1)} = [p.OutputDirectory filesep 'y_flow.fig'];
mkClrDir(outFilePaths{4,p.ChannelIndex(1)});
displFieldProc.setOutFilePaths(outFilePaths);

%% --------------- Stage drift correction ---------------%%% 

disp('Starting correcting stage drift...')
% Anonymous functions for reading input/output
inImage=@(chan,frame) [imDirs{chan} filesep imageFileNames{chan}{frame}];
outFile=@(chan,frame) [outFilePaths{1,chan} filesep imageFileNames{chan}{frame}];

% Loading reference channel images and cropping reference frame
refFrame = double(imread(p.referenceFramePath));
croppedRefFrame = imcrop(refFrame,p.cropROI);
stack = zeros([movieData.imSize_ nFrames]);
disp('Loading stack...');
for j = 1:nFrames, stack(:,:,j) = double(imread(inImage(p.ChannelIndex(1),j))); end

% Detect beads in reference frame
disp('Detecting beads in the reference frame...')
filteredRefFrame = filterGauss2D(croppedRefFrame/maxIntensity,...
    movieData.channels_(p.ChannelIndex(1)).psfSigma_);
k = fzero(@(x)diff(normcdf([-Inf,x]))-1+p.alpha,1);
noiseParam = [k/p.GaussRatio p.sDN 0 p.I0];
cands = detectSpeckles(filteredRefFrame,noiseParam,[1 0]);
M = vertcat(cands([cands.status]==1).Lmax);
beads = M(:,2:-1:1);

% Select only beads  which are minCorLength away from the border of the
% cropped reference frame
beadsMask = true(size(filteredRefFrame));
erosionDist=p.minCorLength+1;
beadsMask(erosionDist:end-erosionDist,erosionDist:end-erosionDist)=false;
indx=beadsMask(sub2ind(size(beadsMask),beads(:,2),beads(:,1)));
beads(indx,:)=[];

if p.doPreReg % Perform pixel-wise registration by auto-correlation
    % Initialize subpixel transformation array
    preT=zeros(nFrames,2);

    disp('Calculating pixel-wise pre-registration...')
    logMsg = 'Please wait, performing pixel-wise pre-registration';
    timeMsg = @(t) ['\nEstimated time remaining: ' num2str(round(t)) 's'];
    tic;
    
    % Create crop of reference frame for autocorrelation
    [rows, cols] = size(croppedRefFrame);
    rect=[floor(cols/4) floor(rows/4) floor(cols/2)-1 floor(rows/2)-1] ;
    preRegTemplate = imcrop(croppedRefFrame,rect);
    
    % Caclulate autocorrelation of the reference frame
    selfCorr = normxcorr2(preRegTemplate,croppedRefFrame);
    [~ , imax] = max(abs(selfCorr(:)));
    [rowPosInRef, colPosInRef] = ind2sub(size(selfCorr),imax(1));

    if feature('ShowFigureWindows'), waitbar(0,wtBar,sprintf(logMsg)); end
    for j= 1:nFrames       
        % Find the maximum of the cross correlation between the template and
        % the current image:
        xCorr  = normxcorr2(preRegTemplate,imcrop(stack(:,:,j),p.cropROI));
        [~ , imax] = max(abs(xCorr(:)));
        [rowPosInCurr, colPosInCurr] = ind2sub(size(xCorr),imax(1));
        
        % The shift is thus:
        rowShift = rowPosInCurr-rowPosInRef;
        colShift = colPosInCurr-colPosInRef;
        
        % and the Transformation is:
        preT(j,:)=-[rowShift colShift];
        
        % Update the waitbar
        if mod(j,5)==1 && feature('ShowFigureWindows')
            tj=toc;
            waitbar(j/nFrames,wtBar,sprintf([logMsg timeMsg(tj*nFrames/j-tj)]));
        end
    end
    
    % Apply pixel-wise registration to thre reference channel
    disp('Applying pixel-wise pre-registration...')
    logMsg = 'Please wait, applying pixel-wise pre-registration';
    timeMsg = @(t) ['\nEstimated time remaining: ' num2str(round(t)) 's'];
    tic;
    % Get limits of transformation array
    maxX = ceil(max(abs(preT(:, 2))));
    maxY = ceil(max(abs(preT(:, 1))));
    stack = padarray(stack, [maxY, maxX, 0]);
    refFrame = padarray(refFrame, [maxY, maxX]);
    p.cropROI=p.cropROI+[maxX maxY 0 0];
      
    if feature('ShowFigureWindows'), waitbar(0,wtBar,sprintf(logMsg)); end
    for j = 1:nFrames
        % Pad image and apply transform
        Tr = maketform('affine', [1 0 0; 0 1 0; fliplr(preT(j,:)) 1]);
        stack(:,:,j) = imtransform(stack(:,:,j), Tr, 'XData',[1 size(refFrame, 2)],'YData', [1 size(refFrame, 1)]);
        
        % Update the waitbar
        if mod(j,5)==1 && feature('ShowFigureWindows')
            tj=toc;
            waitbar(j/nFrames,wtBar,sprintf([logMsg timeMsg(tj*nFrames/j-tj)]));
        end
    end  
else
    % Initialize transformation array
    preT=zeros(nFrames,2);
end

% Initialize transformation array
T=zeros(nFrames,2);

disp('Calculating subpixel-wise registration...')
logMsg = 'Please wait, performing sub-pixel registration';
timeMsg = @(t) ['\nEstimated time remaining: ' num2str(round(t/60)) 'min'];
tic;
% Initialize diagnosis tools
frameIndx =[1 ceil(nFrames)/2 nFrames];
vx=cell(1,numel(frameIndx));
vy=vx;

% Perform sub-pixel registration
if feature('ShowFigureWindows'), waitbar(0,wtBar,sprintf(logMsg)); end
for j= 1:nFrames
    % Stack reference frame and current frame and track beads displacement
    corrStack =cat(3,imcrop(refFrame,p.cropROI),imcrop(stack(:,:,j),p.cropROI));
    [dx,dy] = trackStackFlow(corrStack,beads(:,1),beads(:,2),...
        p.minCorLength,p.minCorLength,'maxSpd',p.maxFlowSpeed);
    
    % Remove infinite flow and save raw displacement under [pos1 pos2] format
    finiteFlow  = ~isinf(dx);
    flow = [beads(finiteFlow,2) beads(finiteFlow,1) ...
        beads(finiteFlow,2)+dy(finiteFlow) beads(finiteFlow,1)+dx(finiteFlow)];
    flowFileName = [outFilePaths{4,p.ChannelIndex(1)} filesep 'flow' num2str(j) '.mat'];
    save(flowFileName,'flow');
    
    %The transformation has the same form as the registration method from
    %Sylvain. Here we take simply the median of the determined flow
    %vectors. We take the median since it is less distorted by outliers.
    T(j,:)=-[nanmedian(dy(finiteFlow)) nanmedian(dx(finiteFlow))];
    
    if ismember(j,frameIndx),
        vy{j==frameIndx}=dy(finiteFlow);
        vx{j==frameIndx}=dx(finiteFlow);
    end
    % Update the waitbar
    if mod(j,5)==1 && feature('ShowFigureWindows')
        tj=toc;
        waitbar(j/nFrames,wtBar,sprintf([logMsg timeMsg(tj*(nFrames-j)/j)]));
    end
end

% Create diagnostic tools
nbins=10;
colors=hsv(numel(frameIndx));
flowFig=figure('Visible','off');
hold on;
for i=1:numel(frameIndx),     
    [n,x]=hist(vx{i},nbins);
    plot(x,n,'Color',colors(i,:),'Linewidth',2);
end
legend(arrayfun(@(x) ['Frame ' num2str(x)],frameIndx,'UniformOutput',false));
xlabel('Flow along the x-axis');
ylabel('Number');
set(flowFig,'Visible','off');
saveas(flowFig,outFilePaths{5,p.ChannelIndex(1)});
close(flowFig);

flowFig=figure('Visible','off');
hold on;
for i=1:numel(frameIndx),     
    [n,x]=hist(vy{i},nbins);
    plot(x,n,'Color',colors(i,:),'Linewidth',2);
end
legend(arrayfun(@(x) ['Frame ' num2str(x)],frameIndx,'UniformOutput',false));
xlabel('Flow along the y-axis');
ylabel('Number');
set(flowFig,'Visible','off');
saveas(flowFig,outFilePaths{6,p.ChannelIndex(1)});
close(flowFig);

T=T+preT;
disp('Applying stage drift correction...')
logMsg = @(chan) ['Please wait, correcting stage drift for channel ' num2str(chan)];
timeMsg = @(t) ['\nEstimated time remaining: ' num2str(round(t)) 's'];
tic;

nChan = length(p.ChannelIndex);
nTot = nChan*nFrames;
for i = 1:numel(p.ChannelIndex)
    iChan = p.ChannelIndex(i);
    % Log display
    disp('Results will be saved under:')
    disp(outFilePaths{1,iChan});
    
    % Get limits of transformation array
    maxX = ceil(max(abs(T(:, 2))));
    maxY = ceil(max(abs(T(:, 1))));
    refFrame = padarray(double(imread(p.referenceFramePath)), [maxY, maxX]);
    
    for j= 1:nFrames
        % Apply subpixel-wise registration to thre reference channel
        I = padarray(double(imread(inImage(iChan,j))), [maxY, maxX]);
        if iChan==1
            Tr = maketform('affine', [1 0 0; 0 1 0; fliplr(round(T(j, :))) 1]);
        else           
            Tr = maketform('affine', [1 0 0; 0 1 0; fliplr(T(j, :)) 1]);
        end
        I2 = imtransform(I, Tr, 'XData',[1 size(I, 2)],'YData', [1 size(I, 1)]);
          
        % Statistically test the local maxima to extract (significant) speckles
        imwrite(uint16(I2), outFile(iChan,j));
        
        % Update the waitbar
        if mod(j,5)==1 && feature('ShowFigureWindows')
            tj=toc;
            nj = (i-1)*nFrames+ j;
            waitbar(nj/nTot,wtBar,sprintf([logMsg(iChan) timeMsg(tj*nTot/nj-tj)]));
        end
    end
end

imwrite(uint16(refFrame), outFilePaths{2,p.ChannelIndex(1)});
save(outFilePaths{3,p.ChannelIndex(1)},'preT','T');
% Close waitbar
if feature('ShowFigureWindows'), close(wtBar); end

disp('Finished correcting stage drift!')
