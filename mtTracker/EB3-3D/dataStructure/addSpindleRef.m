function [kinTracks,EB3Tracks,EB3TracksP,kinTracksP]=addSpindleRef(MD,varargin)
ip = inputParser;
ip.CaseSensitive = false;
ip.KeepUnmatched = true;
ip.addRequired('MD',@(MD) isa(MD,'MovieData'));
ip.addParameter('kinTracks',[],@(x) isa(x,'Tracks'));
ip.addParameter('EB3tracks',[],@(x) isa(x,'Tracks'));
ip.addParameter('kinSphericalCoord',[]);
ip.addParameter('EB3SphCoord',[]);
ip.addParameter('EB3Inlier',[]);
ip.addParameter('EB3PoleId',[]);
ip.addParameter('kinInliers',[]);
ip.addParameter('kinPoleId',[]);
ip.addParameter('kinPoleDist',[]);
ip.addParameter('printAll',false, @islogical);
ip.addParameter('testKinIdx',[19 46 156],@isnumeric);
ip.addParameter('distanceCutOff',0.1,@isnumeric);
ip.parse(MD,varargin{:});
p=ip.Results;

%% Load EB3 tracks add azimuth info, change coordinate to real space measurement. 
%%
if(isempty(p.EB3tracks)||isempty(p.EB3SphCoord))
    outputDirDetect=[MD.outputDirectory_ filesep 'EB3' filesep 'detection' filesep];
    tmp=load([outputDirDetect filesep 'sphericalCoord.mat']);
    EB3SphCoord=tmp.sphCoord;
    EB3PoleDist=load([outputDirDetect filesep 'dist.mat']);
    EB3PoleId=EB3PoleDist.poleId;
    EB3Inliers=EB3PoleDist.inliers;
    outputDirProj=[MD.outputDirectory_ filesep 'EB3' filesep 'track' filesep  ];
    tmp=load([outputDirProj filesep 'tracksLabRef.mat']);
    EB3Tracks=tmp.tracksLabRef;
else
    EB3Tracks=p.EB3tracks;
    EB3SphCoord=p.EB3SphCoord;
    EB3Inliers=p.EB3Inliers;
    EB3PoleId=p.EB3PoleId;
end

% Augment the structures with spherical Coordinate. 
%% Load the pole info
poleDetectionMethod=['simplex_scale_' num2str(3,'%03d')];
outputDirPoleDetect=[MD.outputDirectory_ filesep 'EB3' filesep 'poles' filesep poleDetectionMethod filesep];
tmp=load([outputDirPoleDetect filesep 'poleDetection.mat']);
poleMovieInfo=tmp.poleMovieInfo;

% WARNING: this is not a trajectory, merely a collection of poles to ease
% implementation.
P1=struct();
P1.x=arrayfun(@(d) MD.pixelSize_*(d.xCoord(1,1)-1)+1,poleMovieInfo)';
P1.y=arrayfun(@(d) MD.pixelSize_*(d.yCoord(1,1)-1)+1,poleMovieInfo)';
P1.z=arrayfun(@(d) MD.pixelSize_*(d.zCoord(1,1)-1)+1,poleMovieInfo)';

P2=struct();
P2.x=arrayfun(@(d) MD.pixelSize_*(d.xCoord(2,1)-1)+1,poleMovieInfo)';
P2.y=arrayfun(@(d) MD.pixelSize_*(d.yCoord(2,1)-1)+1,poleMovieInfo)';
P2.z=arrayfun(@(d) MD.pixelSize_*(d.zCoord(2,1)-1)+1,poleMovieInfo)';

refP1=FrameOfRef();
refP1.setOriginFromTrack(P1);
refP1.setZFromTrack(P2);
refP1.genBaseFromZ();

refP2=FrameOfRef();
refP2.setOriginFromTrack(P2);
refP2.setZFromTrack(P1);
refP2.genBaseFromZ();

poleRefs=[refP1 refP2];


% For MT
tic;
for tIdx=1:length(EB3Tracks)
    %progressText(tIdx/length(EB3tracks),'Loading EB3 spherical coordinates.');

    tr=EB3Tracks(tIdx);
     try
        tr.addprop('inliers');
        tr.addprop('poleId');
        tr.addprop('azimuth');      % DEPRECATED
        tr.addprop('elevation');    % DEPRECATED
        tr.addprop('rho');          % DEPRECATED
    catch
    end;
    tr.x=(tr.x-1)*MD.pixelSize_+1;
    tr.y=(tr.y-1)*MD.pixelSize_+1;
    tr.z=(tr.z-1)*MD.pixelSize_+1;

    nonGap=~tr.gapMask();
    tr.poleId=nan(size(tr.f));
    tr.poleId(nonGap)=arrayfun(@(i,f) EB3PoleId{f}(i), tr.tracksFeatIndxCG(nonGap),tr.f(nonGap));
    tr.inliers=nan(size(tr.f));
    tr.inliers(nonGap)=arrayfun(@(i,f) EB3Inliers{f}(i), tr.tracksFeatIndxCG(nonGap),tr.f(nonGap));    
    
    % DEPRECATED
    tr.azimuth=nan(2,length(tr.f));
    tr.elevation=nan(2,length(tr.f));
    tr.rho=nan(2,length(tr.f));
    for poleID=1:2
        tr.azimuth(poleID,nonGap)=arrayfun(@(i,f) EB3SphCoord.azimuth{f}(i,poleID), tr.tracksFeatIndxCG(nonGap),tr.f(nonGap));
        tr.elevation(poleID,nonGap)=arrayfun(@(i,f) EB3SphCoord.elevation{f}(i,poleID), tr.tracksFeatIndxCG(nonGap),tr.f(nonGap));
        tr.rho(poleID,nonGap)=arrayfun(@(i,f) EB3SphCoord.rho{f}(i,poleID), tr.tracksFeatIndxCG(nonGap),tr.f(nonGap));
    end 
    % END DEPRECATED
end

%addReferential(EB3Tracks,poleRefs,'poleRef');

EB3TracksP1= poleRefs(1).applyBaseToTrack(EB3Tracks);
EB3TracksP2= poleRefs(2).applyBaseToTrack(EB3Tracks);
EB3TracksP={EB3TracksP1, EB3TracksP2};

for tIdx=1:length(EB3Tracks)
%     trackPoleRefs=[];
    for poleID=1:length(poleRefs);
        % Copying EB3 track
        tr=EB3TracksP{poleID}(tIdx);
        % Adding correponding spherical coordinate
        try
            tr.addprop('azimuth');
            tr.addprop('elevation');
            tr.addprop('rho');
        catch
        end;
               
        nonGap=~tr.gapMask();
        tr.azimuth=nan(1,length(tr.f));
        tr.elevation=nan(1,length(tr.f));
        tr.rho=nan(1,length(tr.f));       
         
        tr.azimuth(nonGap)=arrayfun(@(i,f) EB3SphCoord.azimuth{f}(i,poleID), tr.tracksFeatIndxCG(nonGap),tr.f(nonGap));
        tr.elevation(nonGap)=arrayfun(@(i,f) EB3SphCoord.elevation{f}(i,poleID), tr.tracksFeatIndxCG(nonGap),tr.f(nonGap));
        tr.rho(nonGap)=arrayfun(@(i,f) EB3SphCoord.rho{f}(i,poleID), tr.tracksFeatIndxCG(nonGap),tr.f(nonGap));
    end
end
toc
%% load Kinetochores spherical coordinate
ip.addParameter('kin',[]);
ip.parse(MD,varargin{:});
p=ip.Results;

%%
if(isempty(p.kinTracks)||isempty(p.kinSphericalCoord))
    outputDirDetect=[MD.outputDirectory_ filesep 'Kin'  filesep 'detection' filesep];
    kinSphericalCoord=load([outputDirDetect filesep 'sphericalCoordBothPoles.mat']);
    kinSphericalCoord=kinSphericalCoord.sphCoord;
    kinPoleDist=load([outputDirDetect filesep 'dist.mat']);       
    kinPoleId=kinPoleDist.poleId;
    kinInliers=kinPoleDist.inliers;
    outputDirProj=[MD.outputDirectory_ filesep 'Kin' filesep 'track' filesep ];
    kinTrackData=load([outputDirProj  filesep 'tracksLabRef.mat']);
    kinTracks=kinTrackData.tracksLabRef;

else
    kinTracks=p.kinTracks;
    kinSphericalCoord=p.kinSphericalCoord;
    kinInliers=p.kinInliers;
end

tic;
% Augment the structures with spherical Coordinate. 
for kIdx=1:length(kinTracks)
    %progressText(kIdx/length(kinTracks),'Loading kin spherical coordinates.');
    tr=kinTracks(kIdx);
    try
        tr.addprop('inliers');
        tr.addprop('azimuth');
        tr.addprop('elevation');
        tr.addprop('rho');
    catch
    end;
    tr.x=(tr.x-1)*MD.pixelSize_+1;
    tr.y=(tr.y-1)*MD.pixelSize_+1;
    tr.z=(tr.z-1)*MD.pixelSize_+1;
    
    nonGap=~tr.gapMask();
    tr.azimuth=nan(2,length(tr.f));
    tr.elevation=nan(2,length(tr.f));
    tr.rho=nan(2,length(tr.f));
    tr.inliers=nan(size(tr.f));
    tr.inliers(nonGap)=arrayfun(@(i,f) kinInliers{f}(i), tr.tracksFeatIndxCG(nonGap),tr.f(nonGap));
    for poleID=1:2
        tr.azimuth(poleID,nonGap)=arrayfun(@(i,f) kinSphericalCoord.azimuth{f}(i,poleID), tr.tracksFeatIndxCG(nonGap),tr.f(nonGap));
        tr.elevation(poleID,nonGap)=arrayfun(@(i,f) kinSphericalCoord.elevation{f}(i,poleID), tr.tracksFeatIndxCG(nonGap),tr.f(nonGap));
        tr.rho(poleID,nonGap)=arrayfun(@(i,f) kinSphericalCoord.rho{f}(i,poleID), tr.tracksFeatIndxCG(nonGap),tr.f(nonGap));
    end 
end

kinTracksP1= poleRefs(1).applyBaseToTrack(kinTracks);
kinTracksP2= poleRefs(2).applyBaseToTrack(kinTracks);
kinTracksP={kinTracksP1, kinTracksP2};

for tIdx=1:length(kinTracks)
%     trackPoleRefs=[];
    for poleID=1:length(poleRefs);
        % Copying EB3 track
        tr=kinTracksP{poleID}(tIdx);
        % Adding correponding spherical coordinate
        try
            tr.addprop('azimuth');
            tr.addprop('elevation');
            tr.addprop('rho');
        catch
        end;
               
        nonGap=~tr.gapMask();
        tr.azimuth=nan(1,length(tr.f));
        tr.elevation=nan(1,length(tr.f));
        tr.rho=nan(1,length(tr.f));       
         
        tr.azimuth(nonGap)=arrayfun(@(i,f) kinSphericalCoord.azimuth{f}(i,poleID), tr.tracksFeatIndxCG(nonGap),tr.f(nonGap));
        tr.elevation(nonGap)=arrayfun(@(i,f) kinSphericalCoord.elevation{f}(i,poleID), tr.tracksFeatIndxCG(nonGap),tr.f(nonGap));
        tr.rho(nonGap)=arrayfun(@(i,f) kinSphericalCoord.rho{f}(i,poleID), tr.tracksFeatIndxCG(nonGap),tr.f(nonGap));
    end
end

toc
outputDirCatchingMT=[MD.outputDirectory_ filesep 'Kin' filesep 'track'];
save([outputDirCatchingMT filesep 'augmentedSpindleRef.mat'],'kinTracks')
outputDirCatchingMT=[MD.outputDirectory_ filesep 'EB3' filesep 'track'];
save([outputDirCatchingMT filesep 'augmentedSpindleRef.mat'],'EB3Tracks')