function M=fsmTrackTrackerBMTNNMain(I,J,threshold,influence,fsmParam,counter,gridSize)
% fsmTrackMain uses the interpolated vector field to refine the tracking
%
% SYNOPSIS   currentM=fsmTrackEnhancedTracker(I,J,threshold,influence,fsmParam,counter,gridSize)
%
% INPUT      I          : matrix [y x I]n of speckle coordinates and intensities for frame 1
%            J          : matrix [y x I]n of speckle coordinates and intensities for frame 2
%            threshold  : radius of the region searched by the tracker for matching speckles
%            influence  : radius of influence for the neural network tracker. This is the initial search
%                         radius; the neural network can more effectively reconstruct flow if it can
%                         search over larger areas and therefore take more particles into account. The final
%                         matches will be constrained to have a maximum distance = 'radius', but initially 
%                         a larger search radius ('influence') will be used.
%            fsmParam   : parameters structure used by SpeckTackle
%            counter    : number of the first frame (with respect to the movie)
%            gridSize   : (optional, default = 0) distance between two interpolation points on the grid [gy gx]
%                         if gridSize is set equal to zero, the field is interpolated onto
%                         the original vector positions
%
% OUTPUT     M          : matrix of matches [y1(1) x1(1) y1(2) x1(2)]n 
%
% DEPENDENCES   fsmTrackTrackerBMTNNMain uses { framework ; vectorFieldAdaptInterp ; fsmTrackPropSpecklePos }
%               fsmTrackTrackerBMTNNMain is used by { fsmTrackMain }
%
% Aaron Ponti, September 8th, 2004

if nargin<6 | nargin>7
    error('Six or seven input parameter expected.');
end

if nargin==6
    gridSize=0;
end

% Tack work path
userPath=fsmParam.main.path;

% Format string for numeric suffix
strg=fsmParam.specific.formString;

% Read current image number (in string format)
currentFrame=fsmParam.specific.fileList(counter,:);
[imagePath,imageBody,imageNo,imageExt]=getFilenameBody(currentFrame);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% IF NEEDED, LOAD THE INITIALIZER FROM DISC 
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Check whether the user asked for an initializer of the tracker
if fsmParam.track.init~=0
    
    switch fsmParam.track.init
        
        case 1            
            
            % Vectors provided by imKymoAnalysis - saved into /corr/vectors
            initPath=fsmParam.track.initPath;
            if isempty(initPath)
                error('This is a bug: fsmParam.track.init is different 0, still fsmParam.track.initPath is empty.');
            end
            
        otherwise
            
            error('The requested initializer does not exist!');
    end
    
    % Read current vector field (initializer) from initPath
    currentVectorField=[initPath,'vectors',imageNo,'.mat'];
    if exist(currentVectorField,'file')==2
        s=load(currentVectorField);
        fields=fieldnames(s);
        if length(fields)~=1
            errorMsg=['The vector fields found in ',initPath,' are not valid. Skipping initialization.'];
            fprintf(1,'%s\n',errorMsg);
        end
        if strcmp(fields,'vectors')==0
            errorMsg=['The vector fields found in ',initPath,' are not valid. Skipping initialization.'];
            fprintf(1,'%s\n',errorMsg);
        end
        vectors=s.vectors;
        if size(vectors,2)~=4
            errorMsg=['The vector fields found in ',initPath,' are not valid. Skipping initialization.'];
            fprintf(1,'%s\n',errorMsg);
        end        
        
        % Extract init vector field from vectors
        initM=vectors(find(vectors(:,1)~=0 & vectors(:,3)~=0),:);
        
        % Inform the user that the tracker will be initialized for this frame
        fprintf(1,'Frame %s: the tracker will be initialized for this frame.\n',imageNo);
        
    else
        errorMsg=['Frame ',imageNo,': could not find a vector field in ',initPath,' to use as an initializer. Skipping initialization.'];
        fprintf(1,'%s\n',errorMsg);
        initM=[];
    end
    
else
    
    % No initializer
    initM=[];
    
end
    
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% FIRST TRACKING 
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Track with initM as an initializer
if ~isempty(initM)
    M=fsmTrackTrackerBMTNNIterative(initM,I,J,threshold,influence);
else
    M=[];
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% HIERARCHICAL TRACKING
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Correlation length for the adaptive vector field averaging 
d0=fsmParam.track.corrLength;
imgSize=fsmParam.specific.imgSize;

if fsmParam.track.enhanced==1
    
    % M is empty if the first tracking with the initializer was NOT run
    if isempty(M)
        M=fsmTrackTrackerBMTNNIterative([],I,J,threshold,influence);
    end

    % Extract vector field from M (discard non-matched speckles)
    raw=M(find(M(:,1)~=0 & M(:,3)~=0),:);

    % In the very unlikely case that ALL particles are unmatched
    if isempty(raw)
        
        % Create zero vectors
        vectors=[0 0 0 0];
        
        % Save interpolated vector field to disk for later use with gap closer
        eval(['save ',userPath,filesep,'vectors',filesep,'vectors',imageNo,'.mat vectors;']);
        
        % Return the same matches
        return
        
    else
        
        % If needed, prepare interpolation grid
        if gridSize==0
            grid=raw(:,1:2); % Interpolate onto vector positions
        else
            grid=framework(imgSize,gridSize); % Interpolate onto a regular grid
        end
        
        % Average returned M to be used to propagate I again
        vectors=vectorFieldAdaptInterp(raw,grid,d0,[],'strain');
        
        % Save interpolated vector field to disk for later use with gap closer
        eval(['save ',userPath,filesep,'vectors',filesep,'vectors',imageNo,'.mat vectors;']);

    end

    % Track with vectors as an initializer
    M=fsmTrackTrackerBMTNNIterative(vectors,I,J,threshold,influence);

end

% If none of the above was run, simply track once with no propagation
if fsmParam.track.init==0 & fsmParam.track.enhanced==0
    M=fsmTrackTrackerBMTNNIterative([],I,J,threshold,influence);
end

% At this point, if the initializer is used (fsmParam.track.init~=0), and NO vector field has been created for 
%   the next frame by imKymoAnalysis, save the obtained (averaged) vector field as the initializer for the next frame
if fsmParam.track.init~=0
    
    % Next frame's vector field
    indxStr=sprintf(strg,str2num(imageNo)+1); % Next frame
    if exist([initPath,filesep,'vectors',indxStr,'.mat'],'file')~=2
        
        % Okay, we need to create the initializer for the next frame
            
        % Extract vectors from M
        raw=M(find(M(:,1)~=0 & M(:,3)~=0),:);

        % If needed, prepare interpolation grid
        if gridSize==0
            grid=raw(:,1:2); % Interpolate onto vector positions
        else
            grid=framework(imgSize,gridSize); % Interpolate onto a regular grid
        end

        % Average returned M to be used to propagate I again
        vectors=vectorFieldAdaptInterp(raw,grid,d0,[],'strain');

        % Save averaged vectors to the initializer subdirecory
        indxStr=sprintf(strg,str2num(imageNo)+1); % Next frame
        try
            eval(['save ',initPath,filesep,'vectors',indxStr,'.mat vectors;']);
        catch
            fprintf(1,'Could not save vectors to disk. They won''t be used to initialize the tracker for the next frame pair.\n');
        end

    else
   
        % A vector field already exists - skipping

    end

end
