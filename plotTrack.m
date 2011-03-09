% plotTrack(data, track, trackID, ch, ha, printEPS)
%
% INPUTS:   data : data structure
%          track : track structure
%        trackID : index of the track
%             ch : channel #
%           {ha} : axis handle (optional, for plotting from within GUI)
%       printeps : save the figure as .eps in 'data.source/Figures/'

% Francois Aguet, March 9 2011 (split from trackDisplayGUI)

function plotTrack(data, tracks, trackID, ch, ha, printeps, visible)

if nargin<7
    visible = 'on';
end

if nargin<4 || isempty(ha)
    hfig = figure('visible', visible);
    ha = axes('Position', [0.15 0.15 0.8 0.8]);
    standalone = true;
else
    standalone = false;
end

if nargin<6
    printeps = false;
end

if length(tracks)>1
    track = tracks(trackID);
else
    track = tracks;
end


if isfield(track, 'startBuffer') && ~isempty(track.startBuffer)
    bStart = size(track.startBuffer.A,2);
else
    bStart = 0;
end
if isfield(track, 'endBuffer') && ~isempty(track.endBuffer)
    bEnd = size(track.endBuffer.A,2);
else
    bEnd = 0;
end

hues = assignColorsHSV(data.markers);
trackColor = hsv2rgb([hues(ch) 1 0.8]);
fillLight = hsv2rgb([hues(ch) 0.4 1]);
fillDark = hsv2rgb([hues(ch) 0.2 1]);

fillLightBuffer = hsv2rgb([hues(ch) 0.4 0.85]);
fillDarkBuffer = hsv2rgb([hues(ch) 0.2 0.85]);

% Significance thresholds
% sigmaT = icdf('normal', 1-alpha/2, 0, 1);
sigmaL = icdf('normal', 0.95, 0, 1); % weaker, single-tailed
sigmaH = icdf('normal', 0.99, 0, 1);


% Plot track
lh = NaN(1,9);

A = track.A(ch,:);
c = track.c(ch,:);
%cStd = track.cStd_mask(ch,:);
cStd = track.cStd_res(ch,:);
t = (track.start-1:track.end-1)*data.framerate;

% alpha = 0.05 level
lh(1) = fill([t t(end:-1:1)], [c c(end:-1:1)+sigmaL*cStd(end:-1:1)],...
    fillLight, 'EdgeColor', 'none', 'Parent', ha);
hold(ha, 'on');

% alpha = 0.01 level
fill([t t(end:-1:1)], [c+sigmaL*cStd c(end:-1:1)+sigmaH*cStd(end:-1:1)],...
    fillDark, 'EdgeColor', 'none', 'Parent', ha);

gapIdx = arrayfun(@(x,y) x:y, track.gapStarts, track.gapEnds, 'UniformOutput', false);
gapIdx = [gapIdx{:}];

% plot track
ampl = A+c;
ampl(gapIdx) = NaN;
lh(2) = plot(ha, t, ampl, '.-', 'Color', trackColor, 'LineWidth', 1);

% plot gaps separately
ampl = A+c;
ampl(setdiff(gapIdx, 1:length(ampl))) = NaN;

if ~isempty(gapIdx)
    lh(3) = plot(ha, t, ampl, '--', 'Color', trackColor, 'LineWidth', 1);
    lh(4) = plot(ha, t(gapIdx), A(gapIdx)+c(gapIdx), 'o', 'Color', trackColor, 'MarkerFaceColor', 'w', 'LineWidth', 1);
end

% plot background level
lh(5) = plot(ha, t, c, '-', 'Color', trackColor);




% Plot left buffer
if isfield(track, 'startBuffer') && ~isempty(track.startBuffer)
    A = [track.startBuffer.A(ch,:) track.A(ch,1)];
    c = [track.startBuffer.c(ch,:) track.c(ch,1)];
    %cStd = [track.startBuffer.cStd_mask(ch,:) track.cStd_mask(ch,1)];
    cStd = [track.startBuffer.cStd_res(ch,:) track.cStd_res(ch,1)];
    t = (track.start-bStart-1:track.start-1)*data.framerate;
    
    fill([t t(end:-1:1)], [c c(end:-1:1)+sigmaL*cStd(end:-1:1)], fillLightBuffer, 'EdgeColor', 'none', 'Parent', ha);
    fill([t t(end:-1:1)], [c+sigmaL*cStd c(end:-1:1)+sigmaH*cStd(end:-1:1)], fillDarkBuffer, 'EdgeColor', 'none', 'Parent', ha);
    lh(6) = plot(ha, t, A+c, '.--', 'Color', trackColor, 'LineWidth', 1);
    lh(7) = plot(ha, t, c, '--', 'Color', trackColor);
end

% Plot right buffer
if isfield(track, 'endBuffer') && ~isempty(track.endBuffer)
    A = [track.A(ch,end) track.endBuffer.A(ch,:)];
    c = [track.c(ch,end) track.endBuffer.c(ch,:)];
    %cStd = [track.cStd_mask(ch,end) track.endBuffer.cStd_mask(ch,:)];
    cStd = [track.cStd_res(ch,end) track.endBuffer.cStd_res(ch,:)];
    t = (track.end-1:track.end+bEnd-1)*data.framerate;
    
    fill([t t(end:-1:1)], [c c(end:-1:1)+sigmaL*cStd(end:-1:1)], fillLightBuffer, 'EdgeColor', 'none', 'Parent', ha);
    fill([t t(end:-1:1)], [c+sigmaL*cStd c(end:-1:1)+sigmaH*cStd(end:-1:1)], fillDarkBuffer, 'EdgeColor', 'none', 'Parent', ha);
    lh(8) = plot(ha, t, A+c, '.--', 'Color', trackColor, 'LineWidth', 1);
    lh(9) = plot(ha, t, c, '--', 'Color', trackColor);
end


l = legend(lh([2 5 1]), ['Amplitude ch. ' num2str(ch)], ['Background ch. ' num2str(ch)], '\alpha = 0.95 level');
tlength = track.end+bEnd - track.start-bStart + 1;
set(ha, 'XLim', ([track.start-bStart-0.1*tlength track.end+bEnd+0.1*tlength]-1)*data.framerate);




if standalone
    tfont = {'FontName', 'Helvetica', 'FontSize', 14};
    sfont = {'FontName', 'Helvetica', 'FontSize', 18};
    lfont = {'FontName', 'Helvetica', 'FontSize', 22};
    
    set(l, tfont{:});
    
    set(gca, 'LineWidth', 1.5, sfont{:});
    xlabel('Time (s)', lfont{:})
    ylabel('Intensity (A.U.)', lfont{:});

    for k = lh([2 3 5 6:9])
        if ~isnan(k)
            set(k, 'LineWidth', 2);
        end
    end
    
    for k = lh([2 6 8])
        if ~isnan(k)
            set(k, 'MarkerSize', 21);
        end
    end
    
    if ~isnan(lh(4))
        set(lh(4), 'MarkerSize', 7, 'LineWidth', 2);
    end
end

if printeps
    fpath = [data.source 'Figures' filesep];
    if ~(exist(fpath, 'dir')==7)
        mkdir(fpath);
    end
    print(hfig, '-depsc2', '-r300', [fpath 'track_' num2str(trackID) '_ch' num2str(ch) '.eps']);
end

if strcmp(visible, 'off')
    close(hfig);
end



function colors = assignColorsHSV(markers)

hue = arrayfun(@(x) rgb2hsv(wavelength2rgb(name2wavelength(x))), markers, 'UniformOutput', false);
hue = vertcat(hue{:});
hue = hue(:,1);

[hue, sortIdx] = sort(hue, 'descend');

N = length(markers);

switch N
    case {1,2}
        hueV = [120 0]/360;
        D = (hue(1)-hueV).^2;
        [~,idx] = sort(D);
        colors = arrayfun(@(x) hueV(x), idx);
    case {3,4}
        colors = NaN(1,N);
        hueIdx = 1:N;
        % first assign green and red, then remaining hues
        D = (hue-1/3).^2;
        i = find(D==min(D));
        colors(hueIdx(i)) = 1/3; % green
        hueIdx(i) = [];
        hue(i) = [];
        
        D = hue.^2;
        i = find(D==min(D));
        colors(hueIdx(i)) = 0; % red
        hueIdx(i) = [];
        hue(i) = [];
                
        hueV = [240 180 60 30]/360; % blue cyan yellow orange
        D = (hue(1)-hueV).^2;
        colors(hueIdx(1)) = hueV(D==min(D));
        if N==4
            D = (hue(2)-hueV).^2;
            colors(hueIdx(2)) = hueV(D==min(D));
        end
    otherwise
        error('Unsupported number of colors.');
end        

colors = colors(sortIdx);
