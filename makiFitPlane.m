function dataStruct = makiFitPlane(dataStruct,verbose)
%MAKIFITPLANE attempts to fit planes into kinetochore clusters
%
% SYNOPSIS: dataStruct = makiFitPlane(dataStruct,verbose)
%
% INPUT dataStruct (opt): maki data structure. If empty, it will be loaded
%                         via GUI
%       verbose (opt)   : 0: No plotting
%                         1: plot results in the end (default)
%                         2: also plot plane fit for every frame
%                         The plots of verbose==1 can also be generated by
%                         calling makiFitPlanePlot(dataStruct)
%
% OUTPUT dataStruct.planeFit structure of length nTimepoints. 
%
%               for a timepoint where no plane could either be derived from the
%               eigenvecotrs or interpolated only the fields .planeVectorClassifier,
%               .eigenvector, and .eigenvalue are populated. 
%
%               .plane [a b c d] for the plane equation ax+by+cz-d=0; 
%               .planeCoord      spot coordinates relative to the plane.
%                   The first dimension is perpendicular to the plane, the
%                   second direction is the intersect between the plane and
%                   the xy-plane
%               .planeVectorClassifier 1 | 0 dependent on whether the
%                   planeVectors orginate from eigenvalues, or are
%                   interpolated (onset of anaphase). In prophase and early
%                   prometaphase, where planeVectors can neither be derived
%                   from eigenvalues nor interpolated, the classifier is
%                   set to 0 and the .planeVectors field is empty
%               .planeVectors    unit vectors of the plane coordinate
%                   system
%               .planeOrigin     Origin of the plane (center of mass of the
%                   inlier spots)
%               .eigenVectors    eigenVectors of the spot covariance matrix
%               .eigenValues     corresponding eigenValues
%               .inlierIdx       index into initCoord of all spots that are
%                   considered to be inliers
%               .unalignedIdx    index into initCoord of all spots that are
%                   considered to belong to lagging chromosomes 
%                   (occurs late prometaphase through anaphase)
%               .laggingIdx      index into initCoord of all spots that are
%                   considered to belong to lagging chromosomes
%                   (occurs only in anaphase frames)
%               .phase either 'e' prophase/early prometaphase -> no plane
%                   fit possible; 'p' late prometaphase -> planefit possible but 
%                   unaligned kinetochores found; 'm' metaphase -> plane
%                   fit possible and no unaligned kinetochores found; 'a'
%                   anaphase -> planefit possible with eigenvalue normal
%                   >> mean eigenvalue;
%               .distParms       [variance,skewness,kurtosis,pNormal]' for
%                   the planeCoord. pNormal is the p-value that the data
%                   comes from a normal distribution. The tabulated values
%                   for the Lilliefors test only go from 0.01 to 0.5!
%               .deltaP          p-value of the ks-test comparing the
%                   distribution of the distances of inlier spots from the
%                   metaphase plate of t and t+1
%               .deltaAngle      difference in angle between planes in t
%                   and t+1
%
%
% REMARKS  - When the spots have been tracked, plane fit should be refined.
%          - The last of the metaphaseFrames is automatically removed,
%            because at least in WT cells, it is actually anaphase.
%
%
% created with MATLAB ver.: 7.4.0.287 (R2007a) on Windows_NT
%
% created by: jdorn, kjaqaman, gdanuser
% DATE: 03-Jul-2007
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

warningState = warning;
warning off stats:lillietest:OutOfRangeP

% threshold for an acceptable eigenvalue ratio
minEigenValRatio = 3;

% rank of n of neighbors used for the initial detection of outlier
% kinetochore; n/2 reflects the number of expected unaligned sister pairs
rankNNearestNeighbors = 10; 

% remove last frame?
% removeLastFrames = 1; % number of frames to remove at the end of M

%TEST input
if nargin == 0 || isempty(dataStruct)
    dataStruct = makiLoadDataFile;
end
if nargin < 2 || isempty(verbose)
    verbose = 1;
end
% check whether analysis has been done
if isempty(dataStruct.initCoord)
    dataStruct = makiInitCoord(dataStruct,0);
end

% get coordinates, dataProperties, etc
initCoord = dataStruct.initCoord;
nTimePoints = length(initCoord);
nSpots = cat(1,initCoord.nSpots);

planeFit(1:nTimePoints) = struct('plane',[],'planeCoord',[],'planeVectorClassifier', 0, ...
    'planeVectors',[],'planeOrigin',[],'eigenVectors',[],'eigenValues',[],...
    'inlierIdx',[],'unalignedIdx',[],'laggingIdx',[],'phase','e',...
    'distParms',[],'deltaP',[],'deltaAngle',[]);

% initialize lists of frames with and without plane
framesNoPlane = 1:nTimePoints;
framesWiPlane = [];

% loop through timepoints. Get covariance of point cloud, and the
% corresponding eigenvalues. Compare the two most similar eigenvalues to
% the third to find out how much of a plane there is. Consider a ratio of
% below 1 to roughly be metaphase
eigenValues = zeros(nTimePoints, 3);
eigenVectors = zeros(3,3,nTimePoints);  %vectors in cols
meanCoord = zeros(nTimePoints,3);

goodFrames = [];
for t=1:nTimePoints

    % make an initial outlier detection
    dist = pdist(initCoord(t).allCoord(:,1:3));
    dist = squareform(dist); 
    sortedDist = sort(dist);
    meanNearestDist = mean(sortedDist(2:rankNNearestNeighbors+1,:));
    % get kinetochores whose mean distance to the rankNNearestNeighbors is
    % falls within the scatter of most of the kinetochores
    [dummy, dummy, inlierIdx] = robustMean(meanNearestDist,2);
    
    %%% DEBUG
    % inlierIdx = 1:length(initCoord(t).allCoord(:,1));
    
    % store an initial inlier index (this may be modified later)
    planeFit(t).inlierIdx = inlierIdx;
    planeFit(t).unalignedIdx = setdiff(1:length(initCoord(t).allCoord(:,1)),inlierIdx);
    
    
    % tree = linkage(dist);
    % dendrogram(tree);
    % treeInc = inconsistent(tree,size(initCoord(t).allCoord,1)-1); 
    
    % get data for eigenRatio, subsequent plane fitting
    [eigenVectors(:,:,t), eigenValues(t,:), meanCoord(t,:)] = ...
        eigenCalc(initCoord(t).allCoord(inlierIdx,1:3));
    
    % fill in the center of mass into the planeOrigin no matter whether
    % there will ever be a plane
    planeFit(t).planeOrigin = meanCoord(t,:);
    
    
    % classify the anisotropy of the point cloud
    [maxEigenVal, maxIndx] = max(eigenValues(t,:));
    [minEigenVal, minIndx] = min(eigenValues(t,:));
    if( (eigenValues(t,maxIndx)/mean(eigenValues(t,setdiff(1:3,maxIndx)))> minEigenValRatio) ||...
        (eigenValues(t,minIndx)/mean(eigenValues(t,setdiff(1:3,minIndx)))< 1/minEigenValRatio))
    % there is sufficient anisotropy
        planeFit(t).planeVectorClassifier = 1;
        goodFrames = [goodFrames t]; 
    end
end



if ~isempty(goodFrames)
    % assign the eigenvectors so that they generate minimal global rotation
    % between good frames.
    [eigenVecAssign,eigenVectors(:,:,goodFrames),eigenVectorRotCos] = assignEigenVecs(eigenVectors(:,:,goodFrames));

    % assume no rotation between the first from of the movie and the virtual
    % time point before
    eigenVectorCos = [[1;1;1] eigenVectorRotCos];
    eigenVectorRotation = acos(eigenVectorCos);

    % copy updated eigenvectors and eigenvalues into the data structure
    for t = 1:nTimePoints
        planeFit(t).eigenVectors = eigenVectors(:,:,t);
        planeFit(t).eigenValues = eigenValues(t,:);
    end

    evecScore= [0;0;0];

    % define the normal vector of the rotating plane as the one whose eigenvalue is
    % overall the most distant from the two other eigenvalues
    for t = 1:length(goodFrames)
        % calculate geometric means of the pairwise distances in every time
        % point
        diffs = pdist(eigenValues(goodFrames(t),:)');
        geomDist(1,t) = sqrt(diffs(1)*diffs(2));
        geomDist(2,t) = sqrt(diffs(1)*diffs(3));
        geomDist(3,t) = sqrt(diffs(2)*diffs(3));

        % score : minimize the rotation of the normal and maximize the gemotric
        % mean distance of the eigenvalue associated with the normal to the two
        % in plane eignevalues.
        % on average: eigenvectors associated with the plane normal have a
        % large geometric mean difference to inplane eigenvectors, and inplane
        % eigenvectors tend to rotate more

        evecScore(:) = evecScore(:) + eigenVectorRotation(:,t)./geomDist(eigenVecAssign(:,t),t);
    end

    % the normal is the one with the largest distance
    [dummy, normalIndx] = min(evecScore);


    % define plane vectors etc.
    for t = 1:length(goodFrames)
        goodNormals(:,t) = eigenVectors(:,eigenVecAssign(normalIndx,t),goodFrames(t));
        e_plane = calcPlaneVectors(goodNormals(:,t));
        planeFit(goodFrames(t)).plane = [goodNormals(:,t)',meanCoord(goodFrames(t),:)*goodNormals(:,t)];
        planeFit(goodFrames(t)).planeVectors = e_plane;

        % assignment of metaphase or anaphase; distinction of late prometaphase
        % to metaphase will be done during the search for unaligned
        % kinetochores
        eigenRatio = eigenValues(goodFrames(t),eigenVecAssign(normalIndx,t))/...
            mean(eigenValues(goodFrames(t),setdiff(1:3,eigenVecAssign(normalIndx,t))));
        if(eigenRatio > 1)
            planeFit(goodFrames(t)).phase = 'a';
        else
            planeFit(goodFrames(t)).phase = 'm';
        end
    end

    % find frames whose normal need to be interpolated; no extrapolation is
    % being done
    gapFrames = setdiff(goodFrames(1):goodFrames(end),goodFrames);

    if ~isempty(gapFrames)
        % B-spline interpolation of the normals in gap frames
        % The interpolation is forced to use derivative 0 at the boundary frames
        gapNormals = spline(goodFrames,[[0;0;0] goodNormals [0;0;0]], gapFrames);

        % normalization of interpolated vectors
        gapNormalsNorm = sqrt(sum(gapNormals.^2));
        for i = 1:size(gapNormals,1)
            gapNormals(:,i) = gapNormals(:,i)/gapNormalsNorm(i);
        end

        % define the interpolated plane vectors etc.
        for t = 1:length(gapFrames)
            e_plane = calcPlaneVectors(gapNormals(:,t));
            planeFit(gapFrames(t)).plane = [gapNormals(:,t)',meanCoord(gapFrames(t),:)*gapNormals(:,t)];
            planeFit(gapFrames(t)).planeVectors = e_plane;

            % assign the mitotic phase to what the next good frame is classified
            % for, i.e. in a sequence 'm' 'm' 'e' 'm', 'e' will be replaced by 'm';
            % in a sequence 'm' 'm' 'e' 'e' 'e' 'a' 'a', all 'e's will be replaced
            % by 'a's;
            % dependent on the noise level there might be inconsistencies in the
            % classification. Those will be fetched later in a global consistency
            % check of the mitotic phase classification
            nextGoodFrames = find(goodFrames > gapFrames(t));
            planeFit(gapFrames(t)).phase = planeFit(goodFrames(nextGoodFrames(1))).phase;
        end
    end

    %% refinement of phase classification and identification of unaligned and
    %  lagging kinetochores

    % get all classified frames (goodFrames and gapFrames)
    framesWiPlane = [goodFrames(1):goodFrames(end)];
    framesNoPlane = setxor((1:nTimePoints),framesWiPlane);

    % get distance from plane, in-plane coordinates by transformation
    % with inverse of in-plane vectors



    % % do only for good frames
    % if ~isempty(metaphaseFrames)
    %     for t = metaphaseFrames'
    %         done = false;
    %         % initially: assume no bad spots. Allow for 10 iterations
    %         badSpotIdxLOld = false(nSpots(t),10);
    %         ct = 1;
    %
    %         while ~done
    %
    %             % get distance from plane, in-plane coordinates by transformation
    %             % with inverse of in-plane vectors
    %             normal = eigenVectors(:,1,t);
    %             e_plane = zeros(3);
    %             e_plane(:,1) = normal;
    %             e_plane(:,2) = [-normal(2),normal(1),0]./sqrt(sum(normal(1:2).^2));
    %             e_plane(:,3) = cross(e_plane(:,1),e_plane(:,2));
    %             % planeCoord: [d,xplane,yplane]
    %             planeFit(t).planeCoord = ...
    %                 (inv(e_plane)*...
    %                 (initCoord(t).allCoord(:,1:3)-repmat(meanCoord(t,:),nSpots(t),1))')';
    %
    %             % find outliers
    %             [dummy, dummy, goodSpotIdx] = robustMean(planeFit(t).planeCoord(:,1));
    %             badSpotIdxL = true(initCoord(t).nSpots,1);
    %             badSpotIdxL(goodSpotIdx) = false;
    %
    %             %         % DEBUG plot plane in matlab
    %             %         pc=planeFit(t).planeCoord;
    %             %         pos = pc(:,1)>0;
    %             %         neg = pc(:,1)<0;
    %             %         figure,plot3(pc(pos,1),pc(pos,2),pc(pos,3),'.k',...
    %             %             pc(neg,1),pc(neg,2),pc(neg,3),'or',...
    %             %             pc(badSpotIdxL,1),pc(badSpotIdxL,2),pc(badSpotIdxL,3),'+b')
    %
    %             % check whether there was any change
    %             if any(all(repmat(badSpotIdxL,1,10) == badSpotIdxLOld,1)) || ct == 10
    %                 % done. Fill information into planeFit-structure
    %
    %                 planeFit(t).plane = [normal',meanCoord(t,:)*normal];
    %                 planeFit(t).planeVectors = e_plane;
    %                 planeFit(t).eigenVectors = eigenVectors(:,:,t);
    %                 planeFit(t).eigenValues = eigenValues(t,:);
    %                 planeFit(t).planeOrigin = meanCoord(t,:);
    %
    %                 % lagging chromosomes are outliers (until we can identify pairs
    %                 planeFit(t).laggingIdx = find(badSpotIdxL);
    %                 planeFit(t).inlierIdx = goodSpotIdx;
    %
    %                 % distribution parameters (do for all unit directions -
    %                 % the second vector is also interesting, as it lies in the xy
    %                 % plane, in which the metaphase plate should not be cut off
    %                 % distribution parameters (rows):
    %                 % var
    %                 % skew
    %                 % kurtosis
    %                 % p for normal distribution (lilliefors test)
    %                 % correct all parameters for bias
    %                 planeFit(t).distParms = zeros(4,3);
    %                 planeFit(t).distParms(1,:) = var(planeFit(t).planeCoord(goodSpotIdx,:));
    %                 planeFit(t).distParms(2,:) = skewness(planeFit(t).planeCoord(goodSpotIdx,:),0);
    %                 planeFit(t).distParms(3,:) = kurtosis(planeFit(t).planeCoord(goodSpotIdx,:),0);
    %                 [dummy,planeFit(t).distParms(4,1)] = ...
    %                     lillietest(planeFit(t).planeCoord(goodSpotIdx,1));
    %                 [dummy,planeFit(t).distParms(4,2)] = ...
    %                     lillietest(planeFit(t).planeCoord(goodSpotIdx,2));
    %                 [dummy,planeFit(t).distParms(4,3)] = ...
    %                     lillietest(planeFit(t).planeCoord(goodSpotIdx,3));
    %
    %                 % plot plane in matlab
    %                 if verbose > 1
    %                     [ygrid,zgrid] = meshgrid(...
    %                         linspace(min(planeFit(t).planeCoord(:,2)),...
    %                         max(planeFit(t).planeCoord(:,2)),5), ...
    %                         linspace(min(planeFit(t).planeCoord(:,3)),...
    %                         max(planeFit(t).planeCoord(:,3)),5));
    %                     xgrid = zeros(5,5);
    %                     pc=planeFit(t).planeCoord;
    %                     pos = pc(:,1)>0;
    %                     neg = pc(:,1)<0;
    %                     figure('Name',...
    %                         sprintf('Metaphase plate frame %i for %s',...
    %                         t,dataStruct.projectName))
    %                     plot3(pc(pos,1),pc(pos,2),pc(pos,3),'.k',...
    %                         pc(neg,1),pc(neg,2),pc(neg,3),'or',...
    %                         pc(badSpotIdxL,1),pc(badSpotIdxL,2),pc(badSpotIdxL,3),'+b')
    %                     hold on
    %                     mesh(xgrid,ygrid,zgrid,'EdgeColor',[0 0 1],'FaceAlpha',0);
    %                     grid on
    %                 end
    %
    %
    %                 done = true;
    %
    %             else
    %                 % re-"fit" the plane. Update eigenVectors etc.
    %                 [eigenVectors(:,:,t), eigenValues(t,:), meanCoord(t,:)] = ...
    %                     eigenCalc(initCoord(t).allCoord(goodSpotIdx,1:3));
    %                 % count fit
    %                 ct = ct + 1;
    %                 % remember current bad spots
    %                 badSpotIdxLOld(:,ct) = badSpotIdxL;
    %
    %             end
    %
    %         end
    %     end % loop good frames
    % end

    % % loop to get the "between frames" - stuff
    % if length(metaphaseFrames) > 1
    %     for t=[metaphaseFrames(1:end-1),metaphaseFrames(2:end)]'
    %         % p-value of distribution comparison
    %         [dummy,planeFit(t(1)).deltaP] = kstest2(...
    %             planeFit(t(1)).planeCoord(planeFit(t(1)).inlierIdx,1),...
    %             planeFit(t(2)).planeCoord(planeFit(t(2)).inlierIdx,1));
    %
    %         % change in plane orientation
    %         planeFit(t(1)).deltaAngle = acos(dot(planeFit(t(1)).planeVectors(:,1),...
    %             planeFit(t(2)).planeVectors(:,1))) *180/pi;
    %     end
    % end
end

%% align frames wherever possible to get rid of overall rotation


%for frames with a plane, use plane origin as the frame origin
%for frames without a plane, use the center of mass as the frame origin
frameOrigin = vertcat(planeFit.planeOrigin);

%shift the coordinates in each frame such that frameOrigin 
%in each frame is the origin
tmpCoord = repmat(struct('allCoord',[]),nTimePoints,1);
for iTime = 1 : nTimePoints
    tmpCoord(iTime).allCoord = initCoord(iTime).allCoord;
    tmpCoord(iTime).allCoord(:,1:3) = tmpCoord(iTime).allCoord(:,1:3) - ...
        repmat(frameOrigin(iTime,:),nSpots(iTime),1);
end

%if there are frames to rotate ...
if length(framesWiPlane) > 1

    %get first frame to rotate
    firstFrameRotate = framesWiPlane(1);

    %find frames without plane that are before the first frame with plane
    framesBefore1 = framesNoPlane(framesNoPlane < firstFrameRotate);
    framesAfter1 = setxor(framesNoPlane,framesBefore1); % the rest of the frames

    %get the coordinate system of each frame with a plane
    coordSystem = zeros(3,3,nTimePoints);
    coordSystem(:,:,framesWiPlane) = cat(3,planeFit.planeVectors);

    %assign the coordinate system of each frame without a plane
    %if they are before the first frame with a plane, take the coordinate
    %system of the plane after
    %if they are after the first frame with a plane, take the coordinate
    %system of the plane before
    for iTime = framesBefore1(end:-1:1)
        coordSystem(:,:,iTime) = coordSystem(:,:,iTime+1);
    end
    for iTime = framesAfter1
        coordSystem(:,:,iTime) = coordSystem(:,:,iTime-1);
    end
    
    %rotate the coordinates in all frames
    %propagate errors to the new coordinates
    for iTime = 1 : nTimePoints
        rotationMat = inv(coordSystem(:,:,iTime)); %rotation matrix
        errorPropMat = rotationMat.^2; %error propagation matrix
        tmpCoord(iTime).allCoord(:,1:3) = (rotationMat*(tmpCoord(iTime).allCoord(:,1:3))')';
        tmpCoord(iTime).allCoord(:,4:6) = sqrt((errorPropMat*((tmpCoord(iTime).allCoord(:,4:6)).^2)')');
    end
    
end %(if length(framesWiPlane) > 1)

%store rotated coordinates in planeFit structure
for iTime = 1 : nTimePoints
    planeFit(iTime).rotatedCoord = tmpCoord(iTime).allCoord;
end

%% output

% assign out
dataStruct.planeFit = planeFit;


% plot everything
if verbose > 0
    % makiFitPlanePlot(dataStruct)
    makiPlotRotatingPlanes(dataStruct);
end

% turn warnings back on
warning(warningState);



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% SUBFUNCTIONS
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [eigenVectors, eigenValues, meanCoord] = eigenCalc(coordinates)
% find eigenVectors, eigenValues, meanCoordinates for plane fitting
coordCov = cov(coordinates);

meanCoord = mean(coordinates,1);

% eigenVectors/eigenValues
[eigenVectors,eVals] = eig(coordCov);
eigenValues = diag(eVals)';

% compare eigenValues
diffs = pdist(eigenValues');
% indices to understand lowest
[u,v] = find(tril(ones(3),-1));
[dummy,idx] = min(diffs);
% find two close, one far
closestIdx = [u(idx),v(idx)];
farIdx = setdiff(1:3,closestIdx);


% sort eigenVectors, eigenValues. X-component of first eigenvector should
% always be positive
eigenVectors = eigenVectors(:,[farIdx,closestIdx]).*sign(eigenVectors(1,farIdx));
eigenValues = eigenValues([farIdx,closestIdx]);


function [aList, evec, rotList] = assignEigenVecs(evec) 
% assign the indices of the eignevectors such that the tripof between
% consecutive frames undergoes minimal overall rotation
% The output of the function is a 3 x nTimePoints matrix where columns list
% eigenvector index for a specific frame, while the next column lists the
% indices of the associated eigenvector in the next frame. For instance,
%           1 1 1 1 2 1 1 ...
% aList = [ 2 2 3 2 1 3 3 ...
%           3 3 2 3 3 2 2 ...
%
% indicates that the eigenvectors in order of input have a the best match
% between frame 1 and 2; but between frame 2 and 3 eigenvectors 2 and 3
% have been swapped, etc.
%
% The function also updates the eigenvectors to remove near-180 degrees
% jumps
%
% rotList contains the cos(Phi_t->t+1) for each the eigenvector assignments

nTimePoints = size(evec,3);
aList = zeros(3,nTimePoints);
aList(:,1) =[1 ; 2; 3]; 

for i = 2:nTimePoints
    % calculate the cost matrix eignevector assignment
    costMat = transpose(evec(:,:,i-1))*evec(:,:,i);
    % the cost for a rotation is 1 - abs(cos(evec_i(t)*evec_j(t+1))
    costMat = 1 - abs(costMat);
    links = lap(costMat);
    aList(:,i)=links(aList(:,i-1));
    rotList(:,i-1)= diag(1 - costMat(aList(:,i-1),aList(:,i)));
    
    % check for negative dot products -- these indicate 180 degree jumps
    for j = 1:3
        if(transpose(evec(:,aList(j,i-1),i-1))*evec(:,aList(j,i),i) < 0)
            evec(:,aList(j,i),i)=-1*evec(:,aList(j,i),i);
        end
    end
end

function e_plane = calcPlaneVectors(normal)
% calculates the plane vectors from a normal based on the criterion that
% the first plane vector is the normal, the second is the vector
% perpependicular to the normal and parallel to the XY-plane and the third
% vector is perpendicular to both

e_plane = zeros(3);
e_plane(:,1) = normal;
e_plane(:,2) = [-normal(2),normal(1),0]./sqrt(sum(normal(1:2).^2));
e_plane(:,3) = cross(e_plane(:,1),e_plane(:,2));



