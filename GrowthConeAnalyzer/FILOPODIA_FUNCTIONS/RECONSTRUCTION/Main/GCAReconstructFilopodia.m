function [filoBranch,TSFigsFinal,TSFigsRecon,errorHist] = GCAReconstructFilopodia(img,veilStemMaskC,protrusionC,leadProtrusionPtC,LPIndices,idxEnter,varargin)
% GCAReconstructFilopodia: (Step VI of GCA PACKAGE)
% This function rebuilds and records the filopodia network around a
% veil/stem mask (in the case of the neurite) or any binary cell mask 
% where small scale (often low fidelity) protrusion detections have been 
% removed. 
% 
% STEP I: It applies a small scale steerable ridge filter followed 
%         by NMS (non-maximum suppression) to detect filopodia. 
%         It then reconstructs the filopodia network from this 
% 
%% INPUT: REQUIRED AND OPTIONAL
%
%   img: (REQUIRED) : RxC double array
%      of image to analyze where R is the height (ny) and C is the width
%     (nx) of the input image
%
%  veilStemMaskC: (REQUIRED)  RxC logical array (binary mask)
%      of veil/stem reconstruction where R is the height (ny) and C is the width
%      (nx) of the  original input image
%
%  protrusionC: (OPTIONAL) : structure with fields:
%    .normals: a rx2 double of array of unit normal
%      vectors along edge: where r is the number of
%      coordinates along the veil/stem edge
%
%    .smoothedEdge: a rx2 double array of edge coordinates
%       after spline parameterization:
%       where r is the number of coordinates along the veil/stem edge
%      (see output: output.pixel_tm1_output in prSamProtrusion)
%     Default : [] , NOTE: if empty the field
%                    filoInfo(xFilo).orientation for all filodpodia attached
%                    to veil will be set to NaN (not calculated)- there will be a warning if
%                    to the user if this is the case
%    Output from the protrusion process (see getMovieProtrusion.m)
% 
%  Rotate
%% PARAMS
%    
% %% PARAMS: STEERABLE FILTER: RIDGE FINDING %%
%
%    'FiloScale' (PARAM) : Positive scalar or vector
%        Sigmas (standard deviation of the Gaussian kernel) to use for
%        the steerable filter estimation of the small-scale ridges. Note if a vector
%        is specified, responses for all scales are calculated and the
%        scale with the largest steerable filter
%        response at each point is chosen for the final backbone estimation.
%        Default: [1.5] (in pixels)
%        See gcaMultiscaleSteerableDetector.m
%
%    'FilterOrderFilo' (PARAM) : Scalar 2 or 4
%        4 provides better orientation selectivity than 2
%        and is less sensitive to noise, at a small trade-off in
%        computational cost. 
%        Default: 4
%        See gcaMultiscaleSteerableDetector.m
%
%
% %% PARAMS: RIDGE CLEANING %% 
%
%    'multSTDNMSResponse': (PARAM) Scalar   
%         
%    'minCCRidgeOutsideVeil' : Scalar (Default 3 Pixels)
%
%
% %% PARAMS: RIDGE LINKING %%  
%
%    % FILO CANDIDATE BUILDING %
%      'maxRadiusLink' (PARAM) : Scalar 
%         Maximum radius for connecting linear endpoints points of two 
%         filopodia candidates in the initial candidate building step of the 
%         algorithm.
%         Default: 5
%         See gcaAttachFilopodiaStructuresMain.m 
%
%    % TRADITIONAL FILO/BRANCH LINKING %
%      'maxRadiusLinkFiloOutsideVeil' (PARAM): Scalar  
%         Maximum radius for connecting endpoints of candidate filopodia ridges 
%         to the current iteration of the  high confidence seed. 
%         Default : 
% 
% 
%    % EMBEDDED ACTIN SIGNAL LINKING %
%      'maxRadiusLinkEmbedded' (PARAM) : Scalar 
%          Only embedded ridge candidate end points that are within this max 
%          search radius around each seed ridge endpoint are considered for matching.
%          Default: 10 Pixels
%          (Only applicable if 'detectEmbedded' set to 'true')
%          See: gcaAttachFilopodiaStructuresMain.m 
%                   gcaReconstructEmbedded.m 
%                       gcaConnectEmbeddedRidgeCandidates.m 
%
%      'geoThreshEmbedded' (PARAM) : Scalar 
%          Only embedded ridge candidates meeting this geometric criteria
%          will be considered. 
%          Default: 0.9 
%          (Only applicable if 'detectEmbedded' set to 'true')
%          See: gcaAttachFilopodiaStructuresMain.m 
%                   gcaReconstructEmbedded.m 
%                       gcaConnectEmbeddedRidgeCandidates.m 
%
%% OUTPUT: 
% adds a field to filoBranch. called filoInfo
% filoInfo is a R structure x 1 structure with fields providing information
% regarding each "filopodia" (ie independent ridge segment): where R is the
% number of filopodia segments reconstructed in iFrame.  
% Currently 'filopodia' can be 
% IDed into select branch groups. 
% groups via the field groupCount. 
% (My version notes addition : Nested fields were avoided here to facilitate the data
% extraction in later steps (ie each filopodia was given an field ID 
% specifying branch order rather than nesting the structure)

%% Input Parser 
ip = inputParser;

ip.CaseSensitive = false;
ip.KeepUnmatched = true;

ip.addRequired('img');
ip.addRequired('veilStemMaskC');
ip.addRequired('protrusionC'); 
ip.addRequired('leadProtrusionPtC'); 
ip.addRequired('LPIndices'); 
ip.addRequired('idxEnter'); 
%OPTIONAL
%ip.addOptional('protrusionC',[],@(x) iscell(x)); % if restarting


% PARAMS: STEERABLE FILTER: RIDGE FINDING
% Pass to gcaMultiscaleSteerableDetector.m
ip.addParameter('FilterOrderFilo',4,@(x) ismember(x,[2,4]));
ip.addParameter('FiloScale',1.5);

% ESTIMATE BACKGROUND TO LOCALIZE REGION OF INTEREST 
ip.addParameter('filterBackEst',true); % flag to estimate high confidence 
% background using the image intensity histogram : < mean + 2std 
% is considered background
ip.addParameter('dilateLocalRegion',false); % flag to dilate further the 
% local region of interest estimation (ie decrease the background
% estimation)
ip.addParameter('LRDilRad',10); % dilation radius of the structuring element 
% applied to inital guess of the localized region of interest. 


% RIDGE CLEANING
ip.addParameter('multSTDNMSResponse',3);
ip.addParameter('minCCRidgeOutsideVeil',3);

% CANDIDATE BUILDING %
% Pass to: gcaAttachFilopodiaStructuresMain.m
ip.addParameter('maxRadiusLink',5); 
ip.addParameter('geoThresh',0.9, @(x) isscalar(x));  

% TRADITIONAL FILOPODIA/BRANCH RECONSTRUCT           
% Pass to: gcaAttachFilopodiaStructuresMain.m
ip.addParameter('maxRadiusConnectFiloBranch',15);
ip.addParameter('geoThreshFiloBranch',0.5);


% EMBEDDED ACTIN SIGNAL LINKING %
ip.addParameter('detectEmbedded',true)
% Pass to: gcaAttachFilopodiaStructuresMain.m
ip.addParameter('maxRadiusLinkEmbedded',10);
%ip.addParameter('geoThreshEmbedded',0.9,@(x) isscalar(x));
ip.addParameter('geoThreshEmbedded',0.5,@(x) isscalar(x)); 
ip.addParameter('curvBreakCandEmbed',0.05,@(x) isscalar(x));
% TROUBLE SHOOT FLAG 
ip.addParameter('TSOverlays',true);

% FOR FILOPODIA ORIENTATION CALC (GC Only as it has an axis
ip.addParameter('rotateVeilStemNormals',true); 


ip.parse(img,veilStemMaskC,protrusionC,leadProtrusionPtC,LPIndices,idxEnter,varargin{:});
p = ip.Results;
p = rmfield(p,{'img','veilStemMaskC','protrusionC'}); 
%% Initiate 
countFigs = 1; 
dims = size(img); 
[ny,nx] = size(img);
normalsC = protrusionC.normal;
TSFigsFinal = []; 
errorHist = 0; 
%% these were the pixelated values used to calculate the normals 
 %Get the outline of the object in this mask. We use contourc instead of
    %bwboundaries for 2 reasons: It returns its results in matrix
    %coordinates, and the resulting outline encloses the border pixels
    %instead of running through their centers. This better agrees with the
    %windows, as the windows are designed to enclose the entire mask.
    
    
    veilStemMaskC(1:ny,1) =0;
    veilStemMaskC(1:ny,nx)=0;
    veilStemMaskC(1,1:nx)= 0;
    veilStemMaskC(ny,1:nx) =0;
    
    % after this step make sure to clean up CCs as well 
    veilStemMaskC = logical(getLargestCC(veilStemMaskC)); 
    
    currOutline = contourc(double(veilStemMaskC),[0 0]);
    currOutline = separateContours(currOutline);%Post-processing of contourc output
    currOutline = cleanUpContours(currOutline);    
    currOutline = currOutline{1}';%We know we only have one object...
   % currOutline = currOutline(:,[2,1]); 
    %Make sure the outline is correctly oriented
    %if ~isCurrClosed
        %Close the curve before checking handedness
        %closedOutline = closeContours({currOutline'},bwdist(~veilStemMaskC));
       % isClockWise = isCurveClockwise(closedOutline{1});        
    %else
        isClockWise = isCurveClockwise(currOutline);        
    %end        
    
    if ~isClockWise
        %Sam requires the curves run in the same direction
        currOutline = currOutline(end:-1:1,:);
    end

%% OLD From Testing to Remove
% figure
% cmap = hsv(length(smoothedEdgeC(:,1))); 
% imshow(-img,[]); 
% hold on 
% %quiver(smoothedEdgeC(:,1),smoothedEdgeC(:,2),normalsC(:,1),normalsC(:,2),'b')
% 
% arrayfun(@(i) scatter(smoothedEdgeC(i,1),smoothedEdgeC(i,2),10,cmap(i,:),'filled'),1:length(smoothedEdgeC(:,1)));   
% text(5,5,'1'); 
% %quiver(currOutline(:,1),currOutline(:,2),normalsC(:,1),normalsC(:,2),'b')
%  imshow(-img,[]); 
%  hold on 
%  arrayfun(@(i) scatter(currOutline(i,1),currOutline(i,2),10,cmap(i,:),'filled'),1:length(currOutline(:,1)));

%% Reorient Normals Toward Outgrowth 
%smoothedEdgeC = protrusionC.smoothedEdge;  
% rotate the normals of the edge of the veilstem in the direction of the
% outgrowth for orientation metrics. 
if ip.Results.rotateVeilStemNormals

[normalsCRotated,smoothedEdgeC,normalsC ]= gcaReorientVeilStemNormalsTowardsOutgrowth(leadProtrusionPtC,LPIndices,normalsC,currOutline,dims,idxEnter); 
% add the rotated field. 

if ip.Results.TSOverlays
  TSFigs(countFigs).h  =  setFigure(dims(2),dims(1),'on'); 
  TSFigs(countFigs).name = 'Normals_Rotated'; 
  TSFigs(countFigs).group = []; 
    imshow(-img,[]); 
    hold on 
    side1 = find(normalsCRotated(:,3) == 1); 
    side2 = find(normalsCRotated(:,3) == 2) ; 
    % sanity check 
    side1 = find(normalsCRotated(:,3) == 1); 
    side2 = find(normalsCRotated(:,3) == 2) ; 
    quiver(smoothedEdgeC(side1,1),smoothedEdgeC(side1,2),normalsCRotated(side1,1),...
    normalsCRotated(side1,2),'b'); 
    quiver(smoothedEdgeC(side2,1),smoothedEdgeC(side2,2),normalsCRotated(side2,1),...
    normalsCRotated(side2,2),'r');
    quiver(smoothedEdgeC(:,1),smoothedEdgeC(:,2),normalsC(:,1),normalsC(:,2),'g')
    scatter(leadProtrusionPtC(:,1),leadProtrusionPtC(:,2),'k','filled'); 
    maskPath = false(dims); 
    maskPath(LPIndices) = true; 
    spy(maskPath,'k'); 
    
    text(5,10,'"Lead" Protrusion Point From Skeleton ', 'color','k','FontSize',10); 
    text(5,20,'Veil/Stem Edge Normals', 'color','g','FontSize',10); 
    text(5,30,'Direction Veil/Stem Edge Toward Lead Protrusion Side 1 (0 Degrees)','color','b','FontSize',10); 
    text(5,40,'Direction Veil/Stem Edge Toward Lead Protrusion Side 2 (0 Degrees)', 'color', 'r','FontSize',10);
    
   % text(5,40,'Direction Veil/Stem Edge Normal','color','g'); 
    countFigs = countFigs+1; 
  %  text
end 
protrusionC.normal = normalsC; % note sometimes have to remove some of the boundary pixels from the original 
protrusionC.smoothedEdge = smoothedEdgeC; 
protrusionC.normalsRotated = normalsCRotated;  
end 
%% STEP I: Detect Thin Ridge Structures 
    
[maxRes, maxTh ,maxNMS ,scaleMap]= gcaMultiscaleSteerableDetector(img,ip.Results.FilterOrderFilo,ip.Results.FiloScale); 

% (NOTE: MB, possibly make this output verbose only?) 
filoBranchC.filterInfo.maxTh = maxTh;
filoBranchC.filterInfo.maxRes = maxRes;
filoBranchC.filterInfo.scaleMap = scaleMap; 

%% STEP II :  PREPARE HIGH CONFIDENCE RIDGE 'SEEDS' FOR SUBSEQUANT ITERATIVE MATCHING STEPS
%% Estimate the background of the image based on intensity (permissive definition) 
% delete small ridge filter signal from these regions in order to not waste
% computational time 
 if ip.Results.filterBackEst
    [maskBack,~,~] = gcaEstimateBackgroundArea(img,'PostProcess',true);
    if ip.Results.dilateLocalRegion
        maskBack = ~imdilate(~maskBack,strel('disk',ip.Results.LRDilRad)); % added 20170503 % was set to 10 
    end
    else 
        maskBack = false(size(img)); % no mask 
 end

%% Take out the first gaussian mode of ridge response intensities (assume it is background) 
    % Determine Threshold
    forValues = maxNMS.*~maskBack; % take out background response based on fluorescence intensity
    valuesFilter = forValues(forValues~=0);  
    if ~isempty(ip.Results.multSTDNMSResponse)
        [respNMSMean,respNMSSTD]   = fitGaussianModeToPDF(valuesFilter);
        cutoffTrueResponse = respNMSMean+ip.Results.multSTDNMSResponse*respNMSSTD; % can make this a variable
    else 
        cutoffTrueResponse = min(valuesFilter); 
    end
    %check and make sure the cutoffTrueResponse makes sense. 
    if cutoffTrueResponse>max(valuesFilter)
        % try thresholdFluorescenceImage 
        cutoffTrueResponse = thresholdFluorescenceImage(valuesFilter); 
        errorHist = 1; 
    end ; 
    n1 = hist(valuesFilter,500);
    
    % Filter NMS based on Threshold: This will form the basis for your
    % candidate ridges
    canRidges = maxNMS.*~maskBack;
    canRidgesPre = canRidges;
    canRidges(canRidges<cutoffTrueResponse) = 0; 
    filoBranchC.filterInfo.ThreshNMS = canRidges; 
    
    canRidges = bwmorph(canRidges,'thin',inf ); 
%% OPTIONAL TS PLOT : Show Histogram to see if cut-off reasonable given the distribution
        if ip.Results.TSOverlays == true % plot the histogram with cut-off overlay so can see what losing 
         
          TSFigs(countFigs).h = setAxis('on'); 
          
          TSFigs(countFigs).name =  'Thin_Ridge_NMS_ResponseHist'; 
          TSFigs(countFigs).group = 'Cleaning_Small_Ridges' ; 
         
      
          hist(valuesFilter,500); 
          hold on 
          line([cutoffTrueResponse cutoffTrueResponse],[0,max(n1)],'color','r','Linewidth',2); 
          axis([min(valuesFilter),max(valuesFilter),0,max(n1)]); 
          title(['Red line ' num2str(ip.Results.multSTDNMSResponse) '*std of first mode']); 
          xlabel('Response per pixel (NMS Pixels Only)'); 
          ylabel('Count'); 
          
          countFigs = countFigs+1; % close figure 
        end
%% Eliminate Junctions in the Ridge Detection
% Break any remaining junctions so they may be assigned 
% can appropriately assign these junction pixels to individual filopdodia in the
% subsequent matching steps.

% Initiate the cleaned array.
canRidgeClean =  canRidges; 

%% Break the junctions Original 
nn = padarrayXT(double(canRidgeClean~=0), [1 1]);
sumKernel = [1 1 1];
nn = conv2(sumKernel, sumKernel', nn, 'valid');
nn1 = (nn-1) .* (canRidgeClean~=0);
junctionMask = nn1>2;

canRidgeClean(junctionMask) =0;

%% Filter Small Size Connected Component Ridge Pieces
% typically keep this very small as do not want to remove signal 
% < 3 pixel connected components are just typically less 
% well suited to orientation measurements required in the next steps
CCRidges = bwconncomp(canRidgeClean,8); % 
csize = cellfun(@(c) numel(c), CCRidges.PixelIdxList);
nsmall = sum(csize<=ip.Results.minCCRidgeOutsideVeil);% 
CCRidges.NumObjects = CCRidges.NumObjects-nsmall;
CCRidges.PixelIdxList(csize<=ip.Results.minCCRidgeOutsideVeil) = []; % was 3 pixels

% MASK OF CLEANED RIDGES MINUS ALL JUNCTIONS
cleanedRidgesAll = labelmatrix(CCRidges)>0;
%% Optional TS Figure : Ridge Signal Cleaning Steps 
 if ip.Results.TSOverlays == true % plot the histogram with cut-off overlay so can see what losing 
         
          TSFigs(countFigs).h = setFigure(nx,ny,'on'); 
       
          TSFigs(countFigs).name =  'Thin_Ridge_NMS_Cleaning';
          TSFigs(countFigs).group = 'Cleaning_Small_Ridges'; 
         
          imshow(-img,[]) ; 
          hold on 
          spy(canRidgesPre,'b'); 
          spy(cleanedRidgesAll,'r'); 
          text(5,5,'Ridges Before Cleaning','Color','b','FontSize',10);
          text(5,20,'Ridges After Cleaning', 'Color','r','FontSize',10); 
          countFigs = countFigs +1; 
 end 

%% Run Main Function that performs the reconstructions
[reconstruct,filoInfo,TSFigs2,TSFigsRecon] = gcaAttachFilopodiaStructuresMain(img,cleanedRidgesAll,veilStemMaskC,filoBranchC,protrusionC,p);
if ip.Results.TSOverlays == 1 
TSFigsFinal = [TSFigs  TSFigs2 ]; 
end 
filoBranch.filoInfo = filoInfo; % 
filoBranch.reconstructInfo = reconstruct;


end % 


        
        
        




