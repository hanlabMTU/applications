function [tracksNAfailing,tracksNAmaturing,lifeTimeNAfailing,lifeTimeNAmaturing,maturingRatio] = separateMatureAdhesionTracks(tracksNA, MD, outputPath)
% [tracksNA,lifeTimeNA] = separateMatureAdhesionTracks
% separates failing and maturing NA tracks from existing tracksNA, obtain life time of each NA tracks

% Sangyoon Han April 2014

% Set up the output file path
pathForTheMovieDataFile = MD.getPath;
outputFilePath = [pathForTheMovieDataFile filesep outputPath];
dataPath = [outputFilePath filesep 'data'];
if ~exist(dataPath,'dir') 
    mkdir(dataPath);
end
%% Lifetime analysis
minLifetime = 5;
maxLifetime = 61;
p=0;
idx = false(numel(tracksNA),1);
for k=1:numel(tracksNA)
    % look for tracks that had a state of 'BA' and become 'NA'
    firstNAidx = find(strcmp(tracksNA(k).state,'NA'),1,'first');
    % see if the state is 'BA' before 'NA' state
%     if (~isempty(firstNAidx) && firstNAidx>1 && strcmp(tracksNA(k).state(firstNAidx-1),'BA')) || (~isempty(firstNAidx) &&firstNAidx==1)
    if ~isempty(firstNAidx)
        p=p+1;
        idx(k) = true;
        tracksNA(k).emerging = true;
        tracksNA(k).emergingFrame = firstNAidx;
    else
        tracksNA(k).emerging = false;
    end        
end
%% Analysis of those whose force was under noise level: how long does it take
% Analysis shows that force is already developed somewhat compared to
% background. 
% Filter out any tracks that has 'Out_of_ROI' in their status (especially
% after NA ...)
trNAonly = tracksNA(idx);
indMature = false(numel(trNAonly));
indFail = false(numel(trNAonly));
p=0; q=0;

for k=1:numel(trNAonly)
    if trNAonly(k).emerging 
        % maturing NAs
        if (any(strcmp(trNAonly(k).state(trNAonly(k).emergingFrame:end),'FC')) || ...
                any(strcmp(trNAonly(k).state(trNAonly(k).emergingFrame:end),'FA'))) && ...
                sum(trNAonly(k).presence)>8
            
            trNAonly(k).maturing = true;
            indMature(k) = true;
            p=p+1;
            % lifetime until FC
            lifeTimeNAmaturing(p) = sum(strcmp(trNAonly(k).state(trNAonly(k).emergingFrame:end),'NA'));
            % it might be beneficial to store amplitude time series. But
            % this can be done later from trackNAmature
        elseif sum(trNAonly(k).presence)>minLifetime && sum(trNAonly(k).presence)<maxLifetime 
        % failing NAs
            trNAonly(k).maturing = false;
            indFail(k) = true;
            q=q+1;
            % lifetime until FC
            lifeTimeNAfailing(q) = sum(strcmp(trNAonly(k).state(trNAonly(k).emergingFrame:end),'NA'));
        end
    end
end
maturingRatio = p/(p+q);
tracksNAmaturing = trNAonly(indMature);
tracksNAfailing = trNAonly(indFail);
save([dataPath filesep 'failingMaturingTracks.mat'], 'tracksNAfailing','tracksNAmaturing','maturingRatio','lifeTimeNAfailing','lifeTimeNAmaturing')

end