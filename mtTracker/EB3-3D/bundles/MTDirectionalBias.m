function [kinTracksInliers,randKinTracksInlier]=MTDirectionalBias(MD,varargin)
% Swipe different angle used to consider capute Detection, output the
% bundle, save them if a process is input. 
ip = inputParser;
ip.CaseSensitive = false;
ip.KeepUnmatched = true;
ip.addRequired('MD',@(MD) isa(MD,'MovieData'));
ip.addParameter('kinTracksWithSpindle',[]);
ip.addParameter('randKinTracksWithSpindle',[]);
ip.addParameter('EB3TracksWithSpindle',[]);
ip.addParameter('printAll',false, @islogical);
ip.addParameter('cutoffs',0.1, @isnumeric);
ip.addParameter('distType','angle');
ip.addParameter('plotHandle',[]);
ip.addParameter('process',[]);
ip.parse(MD,varargin{:});
p=ip.Results;

printAll=p.printAll;
%%
if(isempty(p.kinTracksWithSpindle)||isempty(p.EB3TracksWithSpindle))
    [kinTracks,EB3Tracks]=addSpindleRef(MD);
else
    EB3Tracks=p.EB3TracksWithSpindle;
    kinTracks=p.kinTracksWithSpindle;
end

%% inlier index
inliersEB3=(logical(arrayfun(@(eb) eb.inliers(1),EB3Tracks)));
EB3TracksInliers=EB3Tracks(inliersEB3);
inliersKin=logical(arrayfun(@(k) k.inliers(1),kinTracks));
kinTracksInliers=kinTracks(inliersKin);
%%
outputDirAmira=[MD.outputDirectory_ filesep 'Kin' filesep 'directionalBias' filesep  'Amira' filesep];

if(isempty(p.randKinTracksWithSpindle))
 %%
% Randomize pixel domain Kinetochore and create the associted sphercial coordinates.
randomDist=10; % in pixel

outputDirTrack=[MD.outputDirectory_ filesep 'Kin' filesep 'track' filesep ];
kinTrackData=load([outputDirTrack  filesep 'tracksLabRef.mat']);
kinTracksOrig=kinTrackData.tracksLabRef;
[randKinTracks]=randomizeKinetochore(kinTracksOrig,randomDist);

% Translate these changes in the detection structure and associated polar
% coordiante
% Load associated data
outputDirDetect=[MD.outputDirectory_ filesep 'Kin'  filesep 'detection' filesep];
tmp=load([outputDirDetect 'detectionLabRef.mat']);
detectionsLabRef=tmp.detectionsLabRef;

dataIsotropy=[MD.pixelSize_ MD.pixelSize_ MD.pixelSize_];
EB3poleDetectionMethod=['simplex_scale_003'];
outputDirPoleDetect=[MD.outputDirectory_ filesep 'EB3' filesep 'poles' filesep EB3poleDetectionMethod filesep];
poleData=load([outputDirPoleDetect filesep 'poleDetection.mat']);
poleMovieInfo=poleData.poleMovieInfo;

[~,kinSphericalCoord,inliers]=tracks2detections(randKinTracks,detectionsLabRef,poleMovieInfo,dataIsotropy);

% Rebuild the augmented kin
[randKinTracksPlus]=addSpindleRef(MD,'kinTracks',randKinTracks,'kinSphericalCoord',kinSphericalCoord,'kinInliers',inliers);

% Estimate bundle outside the Kin-Plan refencial
randKinTracksInlier=randKinTracksPlus(inliersKin);
%%
else
    randKinTracksInlier=p.randKinTracksWithSpindle;
end
%%
cutoffs=p.cutoffs;

%%
numAngle=length(cutoffs);
[Hs]=setupFigure(1,(numAngle),numAngle,'AspectRatio',1,'AxesWidth',4);

for aIdx=1:numAngle
    cutoff=cutoffs(aIdx);
    mapMTApparitionToKin(kinTracksInliers,EB3TracksInliers,cutoff,'distType',p.distType);
    appearingMTBias(kinTracksInliers);
  
    % For each kinetochore, plot an Amira file with attached mt
    if(printAll)
        %% For each kinetochore, plot an Amira file with attached mt
        for kIdx=1:length(kinTracksInliers)
            trackSet=[kinTracksInliers(kIdx); kinTracksInliers(kIdx).appearingMTP1];
            trackType=[1; zeros(length(kinTracksInliers(kIdx).appearingMTP1),1)];
            amiraWriteTracks([outputDirAmira filesep 'kin_' num2str(kIdx) '.am'],trackSet,'cumulativeOnly',true,'edgeProp',{{'kinEB3',trackType}})
        end
        for kIdx=1:length(kinTracksInliers)
            trackSet=[kinTracksInliers(kIdx); kinTracksInliers(kIdx).appearingMTP1; kinTracksInliers(kIdx).appearingMTP2];
            trackType=[4; kinTracksInliers(kIdx).MTP1Angle; kinTracksInliers(kIdx).MTP2Angle];
            amiraWriteTracks([outputDirAmira filesep 'kin_' num2str(kIdx) '.am'],trackSet,'cumulativeOnly',true,'edgeProp',{{'angle',trackType}})
        end
        %% For each kinetochore, plot an Amira file with attached mt in the spindle
        % ref
        for kIdx=1:length(kinTracksInliers)
            appearingMT=[kinTracksInliers(kIdx).appearingMTP1];
            if (~isempty(appearingMT))
                trackSet=[kinTracksInliers(kIdx).pole1,[appearingMT.pole1]];
            else
                trackSet=kinTracksInliers(kIdx).pole1;
            end
            trackType=[4; kinTracksInliers(kIdx).MTP1Angle];
            amiraWriteTracks([outputDirAmira filesep 'spindleRefP1' filesep 'kin_' num2str(kIdx) '.am'],trackSet,'cumulativeOnly',true,'edgeProp',{{'kinEB3',trackType}})
        end
    end
    
    %% Estimate bias outside KinPole axis
    mapMTApparitionToKin(randKinTracksInlier,EB3TracksInliers,cutoff,'distType',p.distType);
    appearingMTBias(randKinTracksInlier);
%     displayBiasStat({kinTracksInliers,randKinTracksInlier},{'kin','rand'},'plotHandleArray',Hs(aIdx));
    process=p.process;
    procFolder=[MD.outputDirectory_ filesep 'Kin' filesep 'directionalBias' filesep p.distType filesep];
    system(['mkdir ' procFolder]);
    if(~isempty(process))
        save([procFolder 'kinAndRand.mat'],'kinTracksInliers','randKinTracksInlier');
        process.setOutFilePaths({[procFolder 'kinAndRand.mat']})
    end;
    
    displayBiasStat({kinTracksInliers,randKinTracksInlier},{'kin','rand'});
end


disp('end');
