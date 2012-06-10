% Francois Aguet, 05/30/2012

function plotIntensityCohorts(data, varargin)

ip = inputParser;
ip.CaseSensitive = false;
ip.addRequired('data', @isstruct);
ip.addOptional('ch', []);
ip.addParamValue('Overwrite', false, @islogical);
% ip.addParamValue('CohortBounds_s', [10 20 40 60 80 100 125 150]);
ip.addParamValue('CohortBounds_s', [10 20 40 60 80 100 120]);
ip.addParamValue('ShowSEM', true, @islogical);
ip.addParamValue('ShowBackground', false, @islogical);
ip.addParamValue('Rescale', true, @islogical);
ip.addParamValue('RescalingReference', 'med', @(x) any(strcmpi(x, {'max', 'med'})));
%ip.addParamValue('ScaleChannels', 'end', @(x) isempty(x) || any(strcmpi(x, {'start', 'end'})));
ip.addParamValue('ScaleChannels', false, @islogical);
ip.addParamValue('MaxIntensityThreshold', 0);

ip.parse(data, varargin{:});
cohortBounds = ip.Results.CohortBounds_s;


% if no specific channel is selected, all channels are shown
ch = ip.Results.ch;

nCh = numel(data(1).channels);
mCh = find(strcmp(data(1).source, data(1).channels));
sCh = setdiff(1:nCh, mCh);

nd = numel(data);

nc = numel(cohortBounds)-1;
b = 5;
framerate = data(1).framerate;

lftData = getLifetimeData(data, 'Overwrite', ip.Results.Overwrite);

% Scale max. intensity distributions
offset = zeros(nCh,nd);
if ip.Results.Rescale
    for c = 1:nCh
        maxA_all = arrayfun(@(i) nanmax(i.intMat_Ia(:,:,c),[],2), lftData, 'UniformOutput', false);
        [a offset(c,:)] = rescaleEDFs(maxA_all, 'Display', true, 'Reference', ip.Results.RescalingReference, 'FigureName', ['Channel ' num2str(c)]);
        
        % apply scaling
        for i = 1:nd
            lftData(i).intMat_Ia(:,:,c) = a(i) * lftData(i).intMat_Ia(:,:,c);
            lftData(i).sigma_r_Ia(:,:,c) = a(i) * lftData(i).sigma_r_Ia(:,:,c);
        end
    end
end

% test for outliers
if nd>3
    outlierIdx = [];
    for c = 1:nCh
        maxA_all = arrayfun(@(i) nanmax(i.intMat_Ia(:,:,c),[],2), lftData, 'UniformOutput', false);
        cOut = detectEDFOutliers(maxA_all, offset(c,:), 'FigureName', ['Outliers, channel ' num2str(c)]);
        outlierIdx = [outlierIdx cOut]; %#ok<AGROW>
        if ~isempty(outlierIdx)
            fprintf('Outlier data sets for channel %d:\n', c);
            for i = 1:numel(cOut)
                fprintf('%s\n', getShortPath(data(cOut(i))));
            end
        end
    end
    if ~isempty(outlierIdx)
        data(outlierIdx) = [];
        lftData(outlierIdx) = [];
        nd = numel(data);
        fprintf('Outliers excluded from intensity cohorts.\n');
    end
end

% loop through data sets, generate cohorts for each
res(1:nd) = struct('cMean', [], 'cSEM', []);

% # data points in cohort (including buffer frames)
iLength = arrayfun(@(c) floor(mean(cohortBounds([c c+1]))/framerate) + 2*b, 1:nc);
% time vectors for cohorts
cT = arrayfun(@(i) (-b:i-b-1)*framerate, iLength, 'UniformOutput', false);

for i = 1:nd
    lifetime_s = lftData(i).lifetime_s([lftData(i).catIdx]==1);
    trackLengths = lftData(i).trackLengths([lftData(i).catIdx]==1);
    
    % scale slave channels relative to master (for visualization only)
    if ip.Results.ScaleChannels
        % scaling of slave channels relative to master: median of end buffer, median of max. intensity
        medianEndBuffer = squeeze(mean(mean(lftData(i).([ip.Results.ScaleChannels 'Buffer_Ia']),2),1));
        medianMax = squeeze(mean(max(lftData(i).intMat_Ia,[],2),1));
        for c = sCh
            lftData(i).intMat_Ia(:,:,c) = (lftData(i).intMat_Ia(:,:,c)-medianEndBuffer(c))/medianMax(c)*medianMax(mCh)+medianEndBuffer(mCh);
            lftData(i).startBuffer_Ia(:,:,c) = (lftData(i).startBuffer_Ia(:,:,c)-medianEndBuffer(c))/medianMax(c)*medianMax(mCh)+medianEndBuffer(mCh);
            lftData(i).endBuffer_Ia(:,:,c) = (lftData(i).endBuffer_Ia(:,:,c)-medianEndBuffer(c))/medianMax(c)*medianMax(mCh)+medianEndBuffer(mCh);
        end
    end
    
    % for intensity threshold in master channel
    maxA = max(lftData(i).intMat_Ia(:,:,mCh), [], 2)';
    
    res(i).cMean = cell(nCh,nc);
    res(i).cSEM = cell(nCh,nc);
    for ch = 1:nCh % channels
        % interpolate tracks to mean cohort length
        for c = 1:nc % cohorts
            % tracks in current cohort (above threshold)
            cidx = find(cohortBounds(c)<=lifetime_s & lifetime_s<cohortBounds(c+1) & maxA > ip.Results.MaxIntensityThreshold);
            nt = numel(cidx);

            interpTracks = zeros(nt,iLength(c));
            sigma_r_Ia = zeros(nt,iLength(c));
            cLengths = trackLengths(cidx);
            % loop through track lengths within cohort
            for t = 1:nt
                A = [lftData(i).startBuffer_Ia(cidx(t),:,ch) lftData(i).intMat_Ia(cidx(t),1:cLengths(t),ch) lftData(i).endBuffer_Ia(cidx(t),:,ch)];
                interpTracks(t,:) = interp1(1:cLengths(t)+2*b, A, linspace(1,cLengths(t)+2*b, iLength(c)), 'cubic');
                %interpTracks(t,:) = binterp(A, linspace(1,cLengths(t)+2*b, iLength));
                bgr = lftData(i).sigma_r_Ia(cidx(t),1:cLengths(t)+2*b,ch);
                sigma_r_Ia(t,:) = interp1(1:cLengths(t)+2*b, bgr, linspace(1,cLengths(t)+2*b, iLength(c)), 'cubic');
            end

            res(i).cMean{ch,c} = mean(interpTracks,1);
            res(i).cSEM{ch,c} = std(interpTracks,[],1)/sqrt(nt);
            res(i).sigma_r{ch,c} = mean(sigma_r_Ia,1);
            res(i).sigma_rSEM{ch,c} = std(sigma_r_Ia,[],1)/sqrt(nt);
            % split as a function of slave channel signal
            if isfield(lftData(i), 'significantSignal')
                sigIdx = lftData(i).significantSignal(2,lftData(i).catIdx==1);
                sigIdx = sigIdx(cidx);
                res(i).cMeanPos{ch,c} = mean(interpTracks(sigIdx==1,:),1);
                res(i).cMeanNeg{ch,c} = mean(interpTracks(sigIdx==0,:),1);
                res(i).cSEMPos{ch,c} = std(interpTracks(sigIdx==1,:),[],1)/sqrt(nt);
                res(i).cSEMNeg{ch,c} = std(interpTracks(sigIdx==0,:),[],1)/sqrt(nt);
                res(i).sigma_rPos{ch,c} = mean(sigma_r_Ia(sigIdx==1,:),1);
                res(i).sigma_rNeg{ch,c} = mean(sigma_r_Ia(sigIdx==0,:),1);
                res(i).sigma_rSEMPos{ch,c} = std(sigma_r_Ia(sigIdx==1,:),[],1)/sqrt(nt);
                res(i).sigma_rSEMNeg{ch,c} = std(sigma_r_Ia(sigIdx==0,:),[],1)/sqrt(nt);
            end
        end
    end
end


% cmap = jet(256);
% w = 256/nc/2;
% cmap = interp1(1:256, cmap, linspace(1+w,256-w,nc));

fset = loadFigureSettings();




if nCh==1
    figure;
    hold on;
    cmap = jet(nc);
    cv = rgb2hsv(cmap);
    cv(:,2) = 0.2;
    cvB = cv;
    cv = hsv2rgb(cv);
    cvB(:,3) = 0.9;
    cvB = hsv2rgb(cvB);
    
    %cmap = ones(nc,3);
    %cmap(:,1) = (nc:-1:1)/nc;  
    %cmap = hsv2rgb(cmap);
    
    for c = nc:-1:1
        if nd>1
            A = arrayfun(@(x) x.cMean{1,c}, res, 'UniformOutput', false);
            A = vertcat(A{:});
            SEM = std(A,[],1)/sqrt(nd);
            A = mean(A,1);
            kLevel = norminv(1-0.05/2, 0, 1);
            sigma_r = arrayfun(@(x) x.sigma_r{1,c}, res, 'UniformOutput', false);
            sigma_r = kLevel*vertcat(sigma_r{:});
            sigma_rSEM = std(sigma_r,[],1)/sqrt(nd);            
            sigma_r = mean(sigma_r,1);
        else
            A = res(1).cMean{1,c};
            SEM = res(1).cSEM{1,c};
        end
        if ip.Results.ShowBackground
            % full background
            %np = numel(sigma_r)-2*b;
            %fill([cT{c} cT{c}(end:-1:1)], [sigma_r zeros(1,np+2*b)], cvB(c,:), 'EdgeColor', 'none');
            %fill([cT{c}(1+b:end-b) cT{c}(end-b:-1:1+b)], [sigma_r(1+b:end-b) zeros(1,np)], cv(c,:), 'EdgeColor', 'none');
            % background � SEM
            fill([cT{c} cT{c}(end:-1:1)], [sigma_r+sigma_rSEM sigma_r(end:-1:1)-sigma_rSEM(end:-1:1)], cvB(c,:), 'EdgeColor', 'none');
            fill([cT{c}(1+b:end-b) cT{c}(end-b:-1:1+b)], [sigma_r(1+b:end-b)+sigma_rSEM(1+b:end-b) sigma_r(end-b:-1:1+b)-sigma_rSEM(end-b:-1:1+b)], cv(c,:), 'EdgeColor', 'none');
            plot(cT{c}, sigma_r, 'Color', cmap(c,:), 'LineWidth', 1);
        end
        if ip.Results.ShowSEM
            fill([cT{c} cT{c}(end:-1:1)], [A-SEM A(end:-1:1)+SEM(end:-1:1)], cv(c,:), 'EdgeColor', cmap(c,:));
        end
        plot(cT{c}, A, 'Color', cmap(c,:), 'LineWidth', 1.5);
    end
    set(gca, fset.axOpts{:}, 'XLim', [-b*framerate cohortBounds(end)]);
    xlabel('Time (s)', fset.lfont{:});
    ylabel('Intensity (A.U.)', fset.lfont{:});

else % multiple channels
    hues = getFluorophoreHues(data(1).markers);
    
    figure('Name', 'Intensity cohorts, all valid tracks');
    hold on;
    for ch = nCh:-1:1
        trackColor = hsv2rgb([hues(ch) 1 0.8]);
        fillLight = hsv2rgb([hues(ch) 0.4 1]);

        for c = nc:-1:1
            if nd>1
                A = arrayfun(@(x) x.cMean{ch,c}, res, 'UniformOutput', false);
                A = vertcat(A{:});
                SEM = std(A,[],1)/sqrt(nd);
                A = mean(A,1);
            else
                A = res(1).cMean{ch,c};
                SEM = res(1).cSEM{ch,c};
            end
            if ip.Results.ShowSEM
                fill([cT{c} cT{c}(end:-1:1)], [A-SEM A(end:-1:1)+SEM(end:-1:1)], fillLight, 'EdgeColor', trackColor);
            end
            plot(cT{c}, A, 'Color', trackColor, 'LineWidth', 1.5);
        end
    end
    set(gca, fset.axOpts{:}, 'XLim', [-b*framerate cohortBounds(end)]);
    xlabel('Time (s)', fset.lfont{:});
    ylabel('Intensity (A.U.)', fset.lfont{:});
    
    if isfield(res(1), 'cMeanPos')
        figure('Name', 'Intensity cohorts, cargo-positive tracks');
        hold on;
        for ch = nCh:-1:1
            trackColor = hsv2rgb([hues(ch) 1 0.8]);
            fillLight = hsv2rgb([hues(ch) 0.4 1]);
            
            for c = nc:-1:1
                if nd>1
                    A = arrayfun(@(x) x.cMeanPos{ch,c}, res, 'UniformOutput', false);
                    A = vertcat(A{:});
                    SEM = std(A,[],1)/sqrt(nd);
                    A = mean(A,1);
                else
                    A = res(1).cMeanPos{ch,c};
                    SEM = res(1).cSEMPos{ch,c};
                end
                if ip.Results.ShowSEM
                    fill([cT{c} cT{c}(end:-1:1)], [A-SEM A(end:-1:1)+SEM(end:-1:1)], fillLight, 'EdgeColor', trackColor);
                end
                plot(cT{c}, A, 'Color', trackColor, 'LineWidth', 1.5);
            end
        end
        set(gca, fset.axOpts{:}, 'XLim', [-b*framerate cohortBounds(end)]);
        xlabel('Time (s)', fset.lfont{:});
        ylabel('Intensity (A.U.)', fset.lfont{:});
        YLim = get(gca, 'Ylim');
        
        figure('Name', 'Intensity cohorts, cargo-negative tracks');
        hold on;
        for ch = nCh:-1:1
            trackColor = hsv2rgb([hues(ch) 1 0.8]);
            fillLight = hsv2rgb([hues(ch) 0.4 1]);
            
            for c = nc:-1:1
                if nd>1
                    A = arrayfun(@(x) x.cMeanNeg{ch,c}, res, 'UniformOutput', false);
                    A = vertcat(A{:});
                    SEM = std(A,[],1)/sqrt(nd);
                    A = mean(A,1);
                else
                    A = res(1).cMeanNeg{ch,c};
                    SEM = res(1).cSEMNeg{ch,c};
                end
                if ip.Results.ShowSEM
                    fill([cT{c} cT{c}(end:-1:1)], [A-SEM A(end:-1:1)+SEM(end:-1:1)], fillLight, 'EdgeColor', trackColor);
                end
                plot(cT{c}, A, 'Color', trackColor, 'LineWidth', 1.5);
            end
        end
        set(gca, fset.axOpts{:}, 'XLim', [-b*framerate cohortBounds(end)], 'YLim', YLim);
        xlabel('Time (s)', fset.lfont{:});
        ylabel('Intensity (A.U.)', fset.lfont{:});
    end
end
