function makeFigure4(paths, outputDirectory)

% Chosen frame to display in Panel A
iFrames = [1, 2, 80];
% Size of images in Panel A
imageSize = 400;
% Size of the inset in Panel B
insetSize = 50;
% Location of the crop in Panel A
imagePos = [55, 149; 97, 115; 62, 23];
% Location of the inset in Panel B
insetPos = [200,285; 246, 204; 372, 279];

Z = zeros(imageSize, imageSize, 'uint8');
    
dataD = cell(3, 1);
dataE = cell(3, 1);

for iTM = 1:3
    % Load Movie Data
    fileName = [paths{iTM} filesep 'movieData.mat'];
    if ~exist(fileName, 'file')
        error(['Unable to locate ' fileName]);
    end
    load(fileName);

    %Verify that the labeling has been performed
    if ~checkMovieLabels(movieData)
        error('Must label movie before computing figure 3.');
    end

    % Get the names of the 2 FSM subfolders
    names = cellfun(@fliplr, strtok(cellfun(@fliplr,movieData.fsmDirectory, ...
        'UniformOutput', false), filesep), 'UniformOutput', false);
    % Force channel 2's name to be 'Actin'
    names{2} = 'Actin';
    
    nFrames = movieData.labels.nFrames;
    pixelSize = movieData.pixelSize_nm;
    timeInterval = movieData.timeInterval_s;
    
    % Read the list of label files
    labelPath = movieData.labels.directory;
    labelFiles = dir([labelPath filesep '*.tif']);

    % Read the list of TMs speckles (channel 1)
    s1Path = [movieData.fsmDirectory{1} filesep 'tack' filesep 'locMax'];
    s1Files = dir([s1Path filesep '*.mat']);

    % Read the list of Actin speckles (channel 2)
    s2Path = [movieData.fsmDirectory{2} filesep 'tack' filesep 'locMax'];
    s2Files = dir([s2Path filesep '*.mat']);

    % Read the list of TMs images (channel 1)
    image1Path = [movieData.fsmDirectory{1} filesep 'crop'];
    image1Files = dir([image1Path filesep '*.tif']);
    
    % Read the list of Actin images (channel 2)
    image2Path = [movieData.fsmDirectory{2} filesep 'crop'];
    image2Files = dir([image2Path filesep '*.tif']);
    
    % Read the list of distance transforms
    bwdistPath = movieData.bwdist.directory;
    bwdistFiles = dir([bwdistPath filesep '*.mat']);

    % Load activity map
    fileName = [movieData.protrusion.directory filesep ...
        movieData.protrusion.samples.fileName];
    if ~exist(fileName, 'file')
        error(['Unable to locate ' fileName]);
    end
    load(fileName);
    v = sort(protrusionSamples.averageMagnitude(:));
    val = v(ceil(.01 * numel(v)));
    protMask = protrusionSamples.averageNormalComponent > val;
    retMask = protrusionSamples.averageNormalComponent < -val;
    
    %-----------------------------------------------------------------%
    %                                                                 %
    %                          FIGURE 4 PANEL A                       %
    %                                                                 %
    %-----------------------------------------------------------------%
    
%     % TM (Panel A, column 1)
%     
%     % Read image
%     fileName = [image1Path filesep image1Files(iFrames(iTM)).name];
%     I1 = imread(fileName);
%     % Crop image
%     I1 = I1(imagePos(iTM,1):imagePos(iTM,1)+imageSize-1,...
%         imagePos(iTM,2):imagePos(iTM,2)+imageSize-1);
%     % Save
%     hFig = figure('Visible', 'off');
%     imshow(I1, []);
%     fileName = [outputDirectory filesep 'Fig4_A' num2str(iTM) '1.eps'];
%     print(hFig, '-depsc' , '-painters', fileName);
%     % Close the figure
%     close(hFig);
%     
%     % Actin (Panel A, column 2)
%     
%     % Read image
%     fileName = [image2Path filesep image2Files(iFrames(iTM)).name];
%     I2 = imread(fileName);
%     % Crop image
%     I2 = I2(imagePos(iTM,1):imagePos(iTM,1)+imageSize-1,...
%         imagePos(iTM,2):imagePos(iTM,2)+imageSize-1);
%     % Save
%     hFig = figure('Visible', 'off');
%     imshow(I2, []);
%     fileName = [outputDirectory filesep 'Fig4_A' num2str(iTM) '2.eps'];
%     print(hFig, '-depsc' , '-painters', fileName);
%     % Close the figure
%     close(hFig);
% 
%     % Merge (Panel A, column 3)
%     
%     % Convert to 8bit channel
%     iMin = min(I1(:));
%     iMax = max(I1(:));
%     I1 = uint8((255 / double(iMax - iMin)) * (double(I1) - iMin));
%     iMin = min(I2(:));
%     iMax = max(I2(:));
%     I2 = uint8((255 / double(iMax - iMin)) * (double(I2) - iMin));
%     imageMerge = cat(3, I2, I1, Z);
%     % Save
%     hFig = figure('Visible', 'off');
%     imshow(imageMerge);
%     fileName = [outputDirectory filesep 'Fig4_A' num2str(iTM) '3.eps'];
%     print(hFig, '-depsc' , '-painters', fileName);
%     % Close the figure
%     close(hFig);
    
    %-----------------------------------------------------------------%
    %                                                                 %
    %                          FIGURE 4 PANEL B                       %
    %                                                                 %
    %-----------------------------------------------------------------%

%     % Read the distance transform
%     fileName = [bwdistPath filesep bwdistFiles(iFrames(iTM)).name];
%     load(fileName);
%     distToEdge = distToEdge * (pixelSize / 1000);
%     % Load TM speckles
%     fileName = [s1Path filesep s1Files(iFrames(iTM)).name];
%     load(fileName);
%     loc1 = locMax;
%     % Load Actin speckles
%     fileName = [s2Path filesep s2Files(iFrames(iTM)).name];
%     load(fileName);
%     loc2 = locMax;
%         
%     % TM Channel + Actin & TM Speckles (Panel B, column 1)
%     
%     % Crop distance transform
%     imageD = distToEdge(imagePos(iTM,1):imagePos(iTM,1)+imageSize-1,...
%         imagePos(iTM,2):imagePos(iTM,2)+imageSize-1);
%     
%     % Crop TM speckles
%     idxLoc1 = find(loc1(imagePos(iTM,1):imagePos(iTM,1)+imageSize-1,...
%         imagePos(iTM,2):imagePos(iTM,2)+imageSize-1) ~= 0 & imageD < 5);
%     
%     % Crop Actin speckles
%     idxLoc2 = find(loc2(imagePos(iTM,1):imagePos(iTM,1)+imageSize-1,...
%         imagePos(iTM,2):imagePos(iTM,2)+imageSize-1) ~= 0 & imageD < 5);
%         
%     % Create a figure
%     hFig = figure('Visible', 'off');
%     % Draw image
%     imshow(I1);
%     % Draw TM speckles
%     [y x] = ind2sub(size(imageD), idxLoc1);    
%     line(x, y,'LineStyle', 'none', 'Marker', '.', 'Color', 'g','MarkerSize',6);
%     % Drw Actin speckles
%     [y x] = ind2sub(size(imageD), idxLoc2);
%     line(x, y,'LineStyle', 'none', 'Marker', '.', 'Color', 'r','MarkerSize',6);
%     % Draw iso-contours at 0 and 5 microns
%     c = contourc(double(imageD), [0, 5]);
%     n = c(2, 1);
%     line(c(1, 2:n+1), c(2, 2:n+1), 'Color', 'w', 'Linewidth', 2);
%     line(c(1, n+3:end), c(2, n+3:end), 'Color', 'w', 'Linewidth', 2);
%     % Draw the inset box
%     p = insetPos(iTM, :) - imagePos(iTM, :);
%     line([p(2), p(2) + insetSize, p(2) + insetSize, p(2), p(2)], ...
%         [p(1), p(1), p(1) + insetSize, p(1) + insetSize, p(1)], ...
%         'Color', 'w', 'Linewidth', 2);
%     % Save input
%     set(gcf, 'InvertHardCopy', 'off');
%     fileName = [outputDirectory filesep 'Fig4_B' num2str(iTM) '1.eps'];
%     print(hFig, '-depsc' , '-painters', fileName);
%     fixEpsFile(fileName);
%     % Close the figure
%     close(hFig);
%     
%     % TM Inset + Speckles (Panel B, column 2)
%     
%     % Crop image
%     p = insetPos(iTM, :) - imagePos(iTM, :);
%     insetMerge = I1(p(1):p(1)+insetSize-1, p(2):p(2)+insetSize-1);
%     
%     % Crop distance transform
%     insetD = distToEdge(insetPos(iTM,1):insetPos(iTM,1)+insetSize-1,...
%         insetPos(iTM,2):insetPos(iTM,2)+insetSize-1);
%     
%     % Crop TM speckles
%     idxLoc1 = find(loc1(insetPos(iTM,1):insetPos(iTM,1)+insetSize-1,...
%         insetPos(iTM,2):insetPos(iTM,2)+insetSize-1) ~= 0 & insetD < 5);
%     
%     % Create a figure
%     hFig = figure('Visible', 'off');
%     % Draw image
%     imshow(imresize(insetMerge, 8, 'nearest'), ...
%         1.5 * [min(insetMerge(:)) max(insetMerge(:))]);
%     % Draw TM speckles
%     [y x] = ind2sub(size(insetD), idxLoc1);
%     line(8*x, 8*y,'LineStyle', 'none', 'Marker', '.', 'Color', 'g', 'MarkerSize',20);
%     % Draw only the iso-contour at 0 micron
%     c = contourc(double(insetD), [0, 0]);
%     line(8*c(1, 2:end), 8*c(2, 2:end), 'Color', 'w', 'Linewidth', 3);
%     % Save input
%     set(gcf, 'InvertHardCopy', 'off');
%     fileName =  [outputDirectory filesep 'Fig4_B' num2str(iTM) '2.eps'];
%     print(hFig, '-depsc' , fileName);
%     fixEpsFile(fileName);
%     % Close the figure
%     close(hFig);
%  
%     % Actin Inset + Speckles (Panel B, column 3)
%     insetMerge = I2(p(1):p(1)+insetSize-1, p(2):p(2)+insetSize-1);
%     
%     % Crop Actin speckles
%     idxLoc2 = find(loc2(insetPos(iTM,1):insetPos(iTM,1)+insetSize-1,...
%         insetPos(iTM,2):insetPos(iTM,2)+insetSize-1) ~= 0 & insetD < 5);
%     
%     % Create a figure
%     hFig = figure('Visible', 'off');
%     % Draw image
%     imshow(imresize(insetMerge, 8, 'nearest'), ...
%         1.5 * [min(insetMerge(:)) max(insetMerge(:))]);
%     % Draw Actin speckles
%     [y x] = ind2sub(size(insetD), idxLoc2);
%     line(8*x, 8*y,'LineStyle', 'none', 'Marker', '.', 'Color', 'r','MarkerSize',20);
%     % Draw only the iso-contour at 0 micron
%     c = contourc(double(insetD), [0, 0]);
%     line(8*c(1, 2:end), 8*c(2, 2:end), 'Color', 'w', 'Linewidth', 3);
%     % Save input
%     set(gcf, 'InvertHardCopy', 'off');
%     fileName =  [outputDirectory filesep 'Fig4_B' num2str(iTM) '3.eps'];
%     print(hFig, '-depsc' , fileName);
%     fixEpsFile(fileName);
%     % Close the figure
%     close(hFig);
    
    %-----------------------------------------------------------------%
    %                                                                 %
    %                          FIGURE 4 PANEL C                       %
    %                                                                 %
    %-----------------------------------------------------------------%

    data = zeros(2, nFrames-1);
    timeScale = 0:timeInterval:(nFrames-2)*timeInterval;
    
    for iFrame = 1:nFrames-1
        % Load label
        L = imread([labelPath filesep labelFiles(iFrame).name]);
        
        % Load TM speckles (channel 1)
        load([s1Path filesep s1Files(iFrame).name]);
        locMax1 = locMax;
        idxS1 = (locMax1 .* (L ~= 0)) ~= 0;
        
        % Load Actin speckles (channel 2)
        load([s2Path filesep s2Files(iFrame).name]);
        locMax2 = locMax;
        idxS2 = (locMax2 .* (L ~= 0)) ~= 0;
        
        % Read the distance transform
        fileName = [bwdistPath filesep bwdistFiles(iFrame).name];
        load(fileName);
        distToEdge = distToEdge * (pixelSize / 1000); % in microns
    
        data(1,iFrame) = mean(distToEdge(idxS1));
        data(2,iFrame) = mean(distToEdge(idxS2));
        
        % We store these data as well for Panel D (Protrusion):
        Lprot = ismember(L, find(protMask(:, iFrame) == 1));
        
        idxS1 = locMax1 .* Lprot ~= 0;
        idxS2 = locMax2 .* Lprot ~= 0;
        
        dataD{iTM} = cat(1, dataD{iTM}, mean(distToEdge(idxS1)) - mean(distToEdge(idxS2)));
        
        % ... and the same for Panel E (Retraction):
        Lret = ismember(L, find(retMask(:, iFrame) == 1));
        
        idxS1 = locMax1 .* Lret ~= 0;
        idxS2 = locMax2 .* Lret ~= 0;
        
        dataE{iTM} = cat(1, dataE{iTM}, mean(distToEdge(idxS1)) - mean(distToEdge(idxS2)));
    end
    
    hFig = figure('Visible', 'off');    
    set(gca, 'FontName', 'Helvetica', 'FontSize', 20);
    set(gcf, 'Position', [680 678 560 400], 'PaperPositionMode', 'auto');
    plot(gca, timeScale, data(1,:), 'Color', [.4 .8 .2], 'LineStyle', '-', ...
        'LineWidth', 1.5); hold on;
    plot(gca, timeScale, data(2,:), 'Color', [.6 .2 .2], 'LineStyle', '-', ...
        'LineWidth', 1.5); hold off;
    % These settings are adapted to the 3 movies. Change this when you
    % change to other movies.
    yRange  = 1.8:.2:3.4;
    axis([0, max(timeScale), yRange(1), yRange(end)]);
    set(gca,'YTick', yRange);
    set(gca,'YTickLabel',arrayfun(@(x) num2str(x, '%3.1f'), yRange, ...
        'UniformOutput', false));
    xlabel('Time (s)');
    if iTM == 1
        ylabel(['Distance to Edge (' char(181) 'm)']);
    end
    legend(names);
    fileName = [outputDirectory filesep 'Fig4_C' num2str(iTM) '.eps'];
    print(hFig, '-depsc', fileName);
    fixEpsFile(fileName);
    close(hFig);    
end

%-----------------------------------------------------------------%
%                                                                 %
%                          FIGURE 4 PANEL D                       %
%                                                                 %
%-----------------------------------------------------------------%

% Y(1, :) = TM2 (TM, Actin)
% Y(2, :) = TM4 (TM, Actin)
% Y(3, :) = TM5NM1 (TM, Actin)
Y = [(3:3:9)', (1:3)'];

% E(1, :) = TM2 (TM, Actin)
% E(2, :) = TM4 (TM, Actin)
% E(3, :) = TM5NM1 (TM, Actin)
E = ones(3, 2) * .6;

hFig = figure('Visible', 'off');
set(gca, 'FontName', 'Helvetica', 'FontSize', 20);
set(gcf, 'Position', [680 678 560 400], 'PaperPositionMode', 'auto');
h = bar(gca, Y, 'group'); hold on;
% Get the central position over the bars
X = cell2mat(arrayfun(@(i) mean(get(get(h(i), 'Children'), 'XData'))', ...
    1:2, 'UniformOutput', false));
errorbar(X(:),Y(:),E(:),'xk'); hold off;
set(h(1), 'FaceColor', [.4 .8 .2]); % TMs
set(h(2), 'FaceColor', [.6 .2 .2]); % Actin
legend({'TM', 'Actin', 'Diff'});
title('During Protrusion');
set(gca, 'XTickLabel', {'TM2', 'TM4', 'TM5NM1'});
ylabel(['Distance to Edge (' char(181) 'm)']);

fileName = [outputDirectory filesep 'Fig4_D.eps'];
print(hFig, '-depsc', fileName);
fixEpsFile(fileName);
close(hFig);

%-----------------------------------------------------------------%
%                                                                 %
%                          FIGURE 4 PANEL E                       %
%                                                                 %
%-----------------------------------------------------------------%

hFig = figure('Visible', 'off');
set(gca, 'FontName', 'Helvetica', 'FontSize', 20);
set(gcf, 'Position', [680 678 560 400], 'PaperPositionMode', 'auto');
xRange = cellfun(@(x) min(x):.1:max(x), dataD, 'UniformOutput', false);
n = arrayfun(@(i) hist(dataD{i}, xRange{i}), 1:3, 'UniformOutput', false);
n = cellfun(@(x) x / sum(x), n, 'UniformOutput', false);
bar(xRange{1}, n{1}, 'FaceColor', [.2 0 1], 'EdgeColor', [.1 .1 .1]); hold on;
bar(xRange{2}, n{2}, 'FaceColor', [0 .8 .5], 'EdgeColor', [.1 .1 .1]);
bar(xRange{3}, n{3}, 'FaceColor', [1 0 .2], 'EdgeColor', [.1 .1 .1]); hold off;
legend({'TM2', 'TM4', 'TM5NM1'});
axis([min(cat(2,xRange{:})) max(cat(2,xRange{:})) 0 max(cat(2,n{:},.4))]);
title('During Protrusion');
xlabel(['Distance to Actin Front (' char(181) 'm)']);

fileName = [outputDirectory filesep 'Fig4_E.eps'];
print(hFig, '-depsc', fileName);
fixEpsFile(fileName);
close(hFig);
   
%-----------------------------------------------------------------%
%                                                                 %
%                          FIGURE 4 PANEL F                       %
%                                                                 %
%-----------------------------------------------------------------%

hFig = figure('Visible', 'off');
set(gca, 'FontName', 'Helvetica', 'FontSize', 20);
set(gcf, 'Position', [680 678 560 400], 'PaperPositionMode', 'auto');
xRange = cellfun(@(x) min(x):.1:max(x), dataE, 'UniformOutput', false);
n = arrayfun(@(i) hist(dataE{i}, xRange{i}), 1:3, 'UniformOutput', false);
n = cellfun(@(x) x / sum(x), n, 'UniformOutput', false);
bar(xRange{1}, n{1}, 'FaceColor', [.2 0 1], 'EdgeColor', [.1 .1 .1]); hold on;
bar(xRange{2}, n{2}, 'FaceColor', [0 .8 .5], 'EdgeColor', [.1 .1 .1]);
bar(xRange{3}, n{3}, 'FaceColor', [1 0 .2], 'EdgeColor', [.1 .1 .1]); hold off;
legend({'TM2', 'TM4', 'TM5NM1'});
axis([min(cat(2,xRange{:})) max(cat(2,xRange{:})) 0 max(cat(2,n{:},.4))]);
title('During Retraction');
xlabel(['Distance to Actin Front (' char(181) 'm)']);
fileName = [outputDirectory filesep 'Fig4_F.eps'];
print(hFig, '-depsc', fileName);
fixEpsFile(fileName);
close(hFig);

end

