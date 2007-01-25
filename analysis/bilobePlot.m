function bilobePlot(inputData, dataName)
%BILOBEPLOT is a plotting function for the analysis of bilobe patterns
%
% INPUT inputData either n-by-4 array of [spindleLength, bin#, weight,
%                   movie#] from bilobedDistribution, or a cell array with
%                   {spindleLength, projectedIntensities} from
%                   bilobesGfpKinetochore.
%
%



% triage input
if iscell(inputData)
    % we have intensity measurements
    spindleLength = inputData{1};
    intensities = true;
else
    % we have positions
    spindleLength = inputData(:,1);
    intensities = false;
end

if nargin == 1 || isempty(dataName)
    dataName = ' ';
end

plotSigma = true;
plotTrapezoid = true;

% make 26 bins
xLabels = -1/48:1/24:49/48;

% sample every 25 nanometer spindle length
boundaries = [0.9:0.025:1.9;1.1:0.025:2.1];

meanBoundaries = mean(boundaries,1);
nBoundaries = size(boundaries,2);
nBins = length(xLabels);

xall = repmat(xLabels',1,nBoundaries);

% plotData: data needed for plotting
% plotData(1:3) = struct('xall',[],'yall',[],'zall',[],'yTickLabels',[]);

% plot averages
figureNames = {'asymmetric','a, max=1','symmetric','s, max=1'};
for i=1:4

    yall=zeros(nBins,nBoundaries);
    zall=zeros(nBins,nBoundaries);
    zallS = zeros(nBins,nBoundaries);
    yTickLabels = cell(nBoundaries,1);
    nSpindles = zeros(nBoundaries,1);
    spindleIdx = cell(nBoundaries,1);

    % read and potentially symmetrize data
    if intensities
        pInt = inputData{2};
    else
        % dist: bin, weight, movie
        dist = inputData(:,2:end);
    end
    switch i
        case {1,2}
            % nothing to do
        otherwise
            if intensities
                pInt = (pInt+pInt(end:-1:1,:))/2;
            else
                % reverse bins
                dist(2:2:end,1) = 27-dist(2:2:end,1);
            end

    end

    % figure, hold on
    for ct = 1:nBoundaries,
        spindleIdx{ct} = (spindleLength>boundaries(1,ct) & spindleLength<boundaries(2,ct));
        if any(spindleIdx{ct})
            if intensities
                % make weighted average - points 0.1um away have no weight
                weights = (0.1-abs(spindleLength(spindleIdx{ct})-meanBoundaries(ct)))/0.1;
                [averageMP,dummy,sigmaMP] = weightedStats(pInt(:,spindleIdx{ct})',...
                    weights,'w');
            else
                % for every bin, sum up the weights multiplied by the
                % distance weights

                % calculate all the weights already now - we need it
                % for the calculatio of n later
                weights = (0.1-abs(spindleLength(spindleIdx{ct})-...
                    meanBoundaries(ct)))/0.1 .*...
                    dist(spindleIdx{ct},2);
                for bin = 26:-1:1
                    % "average": sum the weights in each bin
                    averageMP(bin) = sum(weights(dist(spindleIdx{ct},1)==bin));
                    % potentially, we can extract distributions for
                    % individual movies, and average those to get a std in
                    % the future, for now, don't have std
                    sigmaMP = NaN;
                end
            end
            switch i
                case {4,2}
                    sigmaMP = sigmaMP/max(averageMP);
                    averageMP = averageMP/max(averageMP);

                otherwise
                    sigmaMP = sigmaMP/sum(averageMP);
                    averageMP = averageMP/sum(averageMP);

            end
            %plot3(x,ct*ones(size(x)),z),
            nSpindles(ct) = sum(weights);
            %old: nSpindles(ct) = nnz(spindleIdx{ct});

            zall(:,ct)=averageMP;
            zallS(:,ct) = sigmaMP;
        else
            % there are no spindles this long
            zall(:,ct) = NaN;
            zallS(:,ct) = NaN;
        end
        yall(:,ct)=meanBoundaries(ct);
        yTickLabels{ct}=sprintf('%1.1f/%1.2f', ...
            meanBoundaries(ct),nSpindles(ct));

    end

    % check zallS for inf
    zallS(~isfinite(zallS)) = NaN;

    figure('Name',[dataName,' ',figureNames{i}])
    if plotSigma && intensities
        ah = subplot(1,2,1);
    else
        ah = gca;
    end
    % adjust xall if we want to have a trapezoid plot
    if plotTrapezoid
        xFactor = yall;
        xSub = 0.5;
    else
        xFactor = ones(size(xall));
        xSub = 0;
    end
    contourf((xall-xSub).*xFactor,yall,zall,'LineStyle','none','LevelList',linspace(0,nanmax(zall(:)),100));
    %     figure('Name',figureNames{i}),surf(xall,yall,zall,'FaceColor','interp','FaceLighting','phong')
    %     axis tight
    set(ah,'yTick',1:0.1:2,'yTickLabel',yTickLabels(1:4:end),'yGrid','on')

    switch i
        case {4,2}
            set(ah,'CLim',[0,1])
        otherwise
            set(ah,'CLim',[0,nanmax(zall(:))])
    end
    if plotSigma && intensities
        % don't put the colorbar here already
    else
        colorbar('peer',ah)
    end
    if plotTrapezoid
        % no lines yet
    else
        % add lines
        hold on
        for d=0.2:0.2:0.8
            line(d./meanBoundaries(meanBoundaries>=2*d),...
                meanBoundaries(meanBoundaries>=2*d),'Color','k','LineWidth',1);
            line(1-d./meanBoundaries(meanBoundaries>=2*d),...
                meanBoundaries(meanBoundaries>=2*d),'Color','k','LineWidth',1);
        end
    end

    if plotSigma && intensities
        ah = subplot(1,2,2);
        contourf((xall-xSub).*xFactor,yall,zallS,'LineStyle','none','LevelList',linspace(0,nanmax(zall(:)),100));
        %     figure('Name',figureNames{i}),surf(xall,yall,zall,'FaceColor','interp','FaceLighting','phong')
        %     axis tight
        set(ah,'yTick',1:0.1:2,'yTickLabel',yTickLabels(1:4:end),'yGrid','on')

        switch i
            case {4,2}
                set(ah,'CLim',[0,1])
            otherwise
                set(ah,'CLim',[0,nanmax(zall(:))])
        end
        colorbar('peer',ah)
        % add lines
        if plotTrapezoid
            % no lines yet
        else
            hold on
            for d=0.2:0.2:0.8
                line(d./meanBoundaries(meanBoundaries>=2*d),...
                    meanBoundaries(meanBoundaries>=2*d),'Color','k','LineWidth',1);
                line(1-d./meanBoundaries(meanBoundaries>=2*d),...
                    meanBoundaries(meanBoundaries>=2*d),'Color','k','LineWidth',1);
            end
        end
    end


    %     xlim([0,1])
    %     ylim([1,2])
    %view([0 90])
    %     plotData(i).xall = xall;
    %     plotData(i).yall = yall;
    %     plotData(i).zall = zall;
    %     plotData(i).zallS = zallS;
    %     plotData(i).yTickLabels = yTickLabels;
    %     plotData(i).spindleIdx = spindleIdx;


end

if intensities
    % adapt for positions later
    figure('Name',sprintf('%s individual; sum=1',dataName));
    [sortedSpindleLength,sortIdx]=sort(spindleLength);
    int = inputData{2};
    int = int(:,sortIdx)';
    int = int./repmat(sum(int,2),1,size(int,2));
    intSymm = 0.5*(int + int(:,end:-1:1));
    subplot(1,2,1),imshow([int,NaN(size(int,1),1),intSymm],[]),
    colormap jet,
    subplot(1,2,2),
    plot(sortedSpindleLength,length(sortIdx):-1:1,'-+')
end

% loop to make histograms
stages = [1,1.2,1.6,2];

% read data. symmetrize distances
if intensities
    pInt = inputData{2};
else
    % dist: bin, weight, movie
    dist = inputData(:,2:end);
    % reverse bins
    dist(2:2:end,1) = 27-dist(2:2:end,1);
end
% allMP = (allMP+allMP(end:-1:1,:))/2;

for ct = 1:length(stages)-1,
    figure('Name',sprintf('%s %1.1f -> %1.1f',dataName, stages(ct:ct+1)));
    sidx = find(spindleLength>stages(ct) & spindleLength<stages(ct+1));
    if intensities
        averageMP = mean(pInt(:,sidx),2);
    else
        % for every bin, sum up the weights

        % calculate all the weights already now - we need it
        % for the calculatio of n later
        weights = dist(spindleIdx{ct},2);
        for bin = 26:-1:1
            % "average": sum the weights in each bin
            averageMP(i) = sum(weights(dist(spindleIdx{ct},1)==bin));
        end
    end

    samp=sum(averageMP);
    averageMP = averageMP/samp;

    hold on
    if intensities
        for i=1:length(sidx)
            plot(xLabels,pInt(:,sidx(i))/samp,'b');
        end
    else
        % do individual movies later
    end
    plot(xLabels,averageMP,'r','LineWidth',1.5)
end