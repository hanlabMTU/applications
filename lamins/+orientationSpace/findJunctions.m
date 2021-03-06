function [ jxnMap , nlms_mip3] = findJunctions( R )
%findJunctions Find junctions in NLMS response

% parpool;
R3 = R.getResponseAtOrderFT(3);
[original.maxima,~,original.maximaV] = R.getRidgeOrientationLocalMaxima;
nlms = R3.nonLocalMaximaSuppressionPrecise(original.maxima);
% nms = R3.nonLocalMaximaSuppressionPrecise(original.maxima(:,:,1));
nms = nlms(:,:,1);
nlms_mip3 = nanmax(nlms,[],3);

T = thresholdOtsu(nlms_mip3);

nlms_binary = nlms_mip3 > T;
nms_binary = nms > T;
non_nms_binary = nlms_binary & ~nms_binary;

original.maximaV_sum = nansum(original.maximaV,3).*nms_binary;
% original.maximaV_sum = nansum(original.maximaV,3).*nlms_binary;
original.maximaV_sum_dilated = imdilate(original.maximaV_sum,ones(3));
original.spatial_maxima = original.maximaV_sum_dilated == original.maximaV_sum & nms_binary;

% T = thresholdRosin(original.maximaV_sum);
% original.maximaV_sum_threshed = original.maximaV_sum > T;

nhood_filter = ones(3);
nhood_filter(2,2) = 0;
% nhood_filter = [0 1 0; 1 1 1; 0 1 0];
numNeighbors = imfilter(double(nlms_binary),nhood_filter);
numNeighbors_gt_2 = numNeighbors > 2;

jxnMap = numNeighbors_gt_2 & original.spatial_maxima & nlms_binary;

nms_skel = bwmorph(nms_binary,'skel',Inf);
nms_endpts.map = bwmorph(nms_skel,'endpoints');
[nms_endpts.r,nms_endpts.c] = find(nms_endpts.map);

nms_skel_wo_bp = lamins.functions.bwRemoveBranchPoints(nms_skel);
nms_skel_bp = nms_skel & ~nms_skel_wo_bp;

nms_skel_wo_bp_cc = bwconncomp(nms_skel_wo_bp);
nms_skel_bp_cc = bwconncomp(nms_skel_bp);
nms_skel_wo_bp_label = labelmatrix(nms_skel_wo_bp_cc);

nlms_nms_skel_diff = nlms_binary - nms_skel_wo_bp;
nlms_nms_skel_diff_cc = bwconncomp(nlms_nms_skel_diff);
nlms_nms_skel_diff_label = labelmatrix(nlms_nms_skel_diff_cc);

nlms_nms_skel_diff_dilated_cc = connectedComponents.ccDilate(nlms_nms_skel_diff_cc,ones(3));

nlms_skel = bwmorph(nlms_binary,'skel',Inf);

adjacent_nms_wo_bp = cellfun(@(x) unique(nms_skel_wo_bp_label(x)),nlms_nms_skel_diff_dilated_cc.PixelIdxList,'Unif',false);
adjacent_nms_wo_bp = cellfun(@(x) x(x ~= 0),adjacent_nms_wo_bp,'Unif',false);

nlms_nms_diff_selected = connectedComponents.ccFilter(nlms_nms_skel_diff_cc,cellfun('length',adjacent_nms_wo_bp) > 1);

dist_to_nms_skel = bwdistgeodesic(nms_skel_wo_bp | labelmatrix(nlms_nms_diff_selected) > 0,nms_skel_wo_bp);

% Endpoints may be also classified as junctions
% Remove endpoints from the junction map
jxnMap = jxnMap & ~nms_endpts.map;
[jxns.r,jxns.c] = find(jxnMap);


jxnDist = bwdistgeodesic(nlms_binary,jxnMap);
% nms_endpts_neighborhood = imdilate(nms_endpts,ones(3));

jxnDist_NaNtoInf = jxnDist;
% Set to Inf if
% 1. Not in the NLMS extension of the NMS
% jxnDist_NaNtoInf(~non_nms_binary) = Inf;
% 2. is NaN
jxnDist_NaNtoInf(isnan(jxnDist_NaNtoInf)) = Inf;
% 3. Not in the neighborhood of an endpoint
% jxnDist_NaNtoInf(~nms_endpts.nhood_map) = Inf;

nms_endpts.nhood_map = imdilate(nms_endpts.map,nhood_filter);
nms_endpts.jxnDist = Inf(size(nms_endpts.map),'like',jxnDist);
nms_endpts.jxnDist(nms_endpts.map) = jxnDist_NaNtoInf(nms_endpts.map);
nms_endpts.jxnDistEroded = imerode(nms_endpts.jxnDist,ones(3));

jxnDist_NaNtoInf(~non_nms_binary) = Inf;
jxnDist_NaNtoInf(~nms_endpts.nhood_map) = Inf;

% Find pixel with minimum distance to a junction
candidates.map = imerode(jxnDist_NaNtoInf,ones(3));
candidates.map = candidates.map == jxnDist_NaNtoInf;
candidates.map = candidates.map & (jxnDist_NaNtoInf ~= Inf);
candidates.map = candidates.map & nms_endpts.nhood_map;
candidates.map(candidates.map) = jxnDist(candidates.map) <= nms_endpts.jxnDistEroded(candidates.map);
% [candidates.r,candidates.c] = find(candidates.map);

candidates.response = imdilate(candidates.map .* nlms_mip3,ones(3));
nms_endpts.candidateResponse = -Inf(size(nms_endpts.map),'like',candidates.response);
nms_endpts.candidateResponse(nms_endpts.map) = candidates.response(nms_endpts.map);
nms_endpts.candidateResponseDilated = imdilate(nms_endpts.candidateResponse,ones(3));
candidates.map = candidates.map & (nms_endpts.candidateResponseDilated == nlms_mip3);
[candidates.r,candidates.c] = find(candidates.map);

% O

figure; imshowpair(nlms_mip3,nms);
hold on; scatter(nms_endpts.c,nms_endpts.r);
hold on; scatter(jxns.c,jxns.r);
hold on; scatter(candidates.c,candidates.r);

end


