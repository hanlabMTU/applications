function featuresInfo = detectFocalAdhesionParticles(ima, mask, sigmaPSF, kSigma)

ima = double(ima);
[nrows ncols] = size(ima);

% Filter image with laplacian
bandPassIso = filterLoG(ima,sigmaPSF);
bandPassIso(bandPassIso < 0) = 0;
bandPassIso(~mask) = 0;

% Filter image with steerable filter
[~,T] = steerableFiltering(ima,2,sigmaPSF);

% Compute the local maxima of the bandpass filtered images
locMaxIso = locmax2d(bandPassIso, [5 5]);

bw = blobSegmentThreshold(bandPassIso,0,0,mask);

locMaxIso(~bw) = 0;

indMax = find(locMaxIso);
[y x] = ind2sub(size(ima), indMax);

P = zeros(size(y, 1), 6);
P(:,1) = x;
P(:,2) = y;
P(:,3) = ima(indMax);
P(:,4) = 4 * sigmaPSF; % sigmaX
P(:,5) = sigmaPSF; % sigmaY
P(:,6) = T(indMax);

% Subresolution detection
radius = kSigma * sigmaPSF;
hside = ceil(radius);
xmin = x - hside;
xmax = x + hside;
ymin = y - hside;
ymax = y + hside;

isValid = find(xmin >= 1 & xmax <= ncols & ymin >= 1 & ymax <= nrows);

xmin = xmin(isValid);
xmax = xmax(isValid);
ymin = ymin(isValid);
ymax = ymax(isValid);
P = P(isValid,:);

stdP = zeros(size(P));

[X,Y] = meshgrid(-hside:hside);
disk = X.^2 + Y.^2 - hside^2 <= 0;

isIn = false(numel(xmin),1);

for iFeature = 1:numel(xmin)
        
    crop = ima(ymin(iFeature):ymax(iFeature), xmin(iFeature):xmax(iFeature));
    C = min(crop(:));
    A = P(iFeature,3) - C;
    crop(~disk) = NaN;
    
    [params stdParams] = fitAnisoGaussian2D(crop, [0, 0, A, P(iFeature,4), P(iFeature,5), P(iFeature,6), C], 'xyArtC');
    
    if max(abs(params(1:2))) < radius
        isIn(iFeature) = true;
         
        P(iFeature,1) = P(iFeature,1) + params(1);
        P(iFeature,2) = P(iFeature,2) + params(2);
        P(iFeature,3) = params(3);
        P(iFeature,4) = params(4);
        P(iFeature,5) = params(5);
        P(iFeature,6) = params(6);
        
        stdP(iFeature,1) = stdParams(1);
        stdP(iFeature,2) = stdParams(2);
        stdP(iFeature,3) = stdParams(3);
        stdP(iFeature,6) = stdParams(4);
    end
end

featuresInfo.xCoord = [P(:,1), stdP(:,1)];
featuresInfo.yCoord = [P(:,2), stdP(:,2)];
featuresInfo.amp = [P(:,3), stdP(:,3)];
featuresInfo.theta = [P(:,6), stdP(:,6)];

