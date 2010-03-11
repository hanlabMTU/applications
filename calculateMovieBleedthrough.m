function movieData = calculateMovieBleedthrough(movieData,varargin)
%CALCULATEMOVIEBLEEDTHROUGH calculates bleedthrough coefficients using the input movie 
% 
% movieData = calculateMovieBleedthrough(movieData)
% 
% movieData =
% calculateMovieBleedthrough(movieData,'OptionName',optionValue,...
% 
% This function calculates average bleedthgough coefficients based on the
% input movie. This movie should have one channel (A) with a fluorophore
% and illumination and filters specific to this fluorophore, and another
% channel (B) imaged with it's own illumination and filters, but with no
% fluorophore. The bleedthrough of the fluorophore in channel A to the
% image in channel B will then be calculated. This allows, in a later
% experiment, the image in channel B to be corrected for this bleedthrough.
% 
% !!NOTE!!: It is strongly recommended that you use dark-current corrected,
% background-subtracted, shade-corrected images for both channels used in
% this calculation!!
%
% Input:
% 
%   movieData - the structure describing the movie, as created with
%   setupMovieData.m
% 
%   'OptionName',optionValue - A string with an option name followed by the
%   value for that option.
% 
%   Possible Option Names:
%
%       ('OptionName' -> possible values)
%
%       ('FluorophoreChannel'->Integer scalar) The index of the channel
%       which has a fluorophore (channel A above) in the input movie. This
%       index is the location of the channel in the field
%       movieData.channelDirectory
%       If not input, the user is asked.
% 
%       ('BleedthroughChannel'->Integer scalar) The index of the channel
%       which has NO fluorophore (channel B above) in the input movie. This
%       index is the location of the channel in the field
%       movieData.channelDirectory
%       If not input, the user is asked.
%
%       ('FluorophoreMaskChannel'->Integer scalar) Thin index of the
%       channel the use masks from for the fluorophore channel.
%
%       ('BleedthroughMaskChannel'->Integer scalar) Thin index of the
%       channel the use masks from for the bleedthrough channel.
% 
%       ('BatchMode' -> True/False) If this option value is set to true,
%       all graphical output and user interaction is suppressed. (No
%       progress bars, no dialogue boxes)
%       Optional. Default is False.
%   
% 
% Output:
% 
%   movieData - the modified structure with the bleedthrough calculation
%   logged in it. 
% 
% Hunter Elliott 
% 2/2010
%

%% -------- Parameters ------- %%

fName = 'bleedthrough_calc';  %File name to save results as
pName = 'bleedthroughCorrection'; %Process name for logging in movieData

%% ---------- Input ---------- %%

movieData = setupMovieData(movieData,pName);

[fChan,bChan,fMaskChan,bMaskChan,batchMode] = parseInput(varargin);

% --- Defaults ---- %

if isempty(fChan)
    fChan = selectMovieChannels(movieData,0,'Please select the channel WITH a fluorophore:');
end
if isempty(bChan)
    bChan = selectMovieChannels(movieData,0,'Please select the channel WITHOUT a fluorophore:');
end
if isempty(fMaskChan)
    fMaskChan = selectMovieChannels(movieData,0,'Select the channel to use masks for fluorohpore channel:');
end
if isempty(bMaskChan)
    bMaskChan = selectMovieChannels(movieData,0,'Select the channel to use masks for bleedthrough channel:');
end
if isempty(batchMode)
    batchMode = [];
end

%% ----- Init ----- %%

%Check the specified mask channels
if ~checkMovieMasks(movieData,[fMaskChan bMaskChan]);
    error('Specified mask channels do not have valid masks! Check channels & masks!')
end

nImages = movieData.nImages(fChan);
if nImages ~= movieData.nImages(bChan) %Make sure the image numbers agree
    error('Fluorophore and bleedthrough channels do not have the same number of images! Check channels/images!');
end

imNames = getMovieImageFileNames(movieData,[fChan bChan]);

mNames = getMovieMaskFileNames(movieData,[fMaskChan bMaskChan]);



%% ----- Bleedthrough Coeficient Calculation ----- %%

%Init arrays for fit results
fitCoef = zeros(nImages,2);
fitStats = struct('R',cell(nImages,1),...
                  'df',cell(nImages,1),...
               'normr',cell(nImages,1),...
               'Rsquared',cell(nImages,1));

%Make figure for showing all lines           
if batchMode
    allFig = figure('visible','off');
else
    allFig = figure;
end
nByn = ceil(sqrt(nImages));%Determine size of sub-plot array


disp(['Calculating bleedthrough of channel "' movieData.channelDirectory{fChan} ...
      '" into channel "' movieData.channelDirectory{bChan} '"..']);

for iImage = 1:nImages
    
    %Load the images and masks
    fImage = double(imread(imNames{1}{iImage}));
    fMask = imread(mNames{1}{iImage});    
    bImage = double(imread(imNames{2}{iImage}));
    bMask = imread(mNames{2}{iImage});    
    
    %Fit a line to the current images
    [fitCoef(iImage,:),tmp] = polyfit(fImage(bMask(:)),...
                                                   bImage(fMask(:)),1);
                                                   
    %Calculate R^2 for this fit
    lFun = @(x)(x * fitCoef(iImage,1) + fitCoef(iImage,2));
    tmp.Rsquared = 1 - sum((bImage(:) - lFun(fImage(:))) .^2) / ...
                       sum((bImage(:) - mean(bImage(:))) .^2);
    
    fitStats(iImage) = tmp; %Allow extra field for Rsquared
    
                                               
                                               
    %switch to the current sub-plot
    subplot(nByn,nByn,iImage)
                                               
    %Plot the values from this image in their own color
    plot(fImage(fMask(:)),bImage(bMask(:)),'.');
    hold on
    title({['Image #' num2str(iImage) ' Y = ' num2str(fitCoef(iImage,1))...
        'x + ' num2str(fitCoef(iImage,2))], ['R Squared = ' num2str(fitStats(iImage).Rsquared)]})        
    xlabel([movieData.channelDirectory{fChan} ' intensity'],'Interpreter','none')
    ylabel([movieData.channelDirectory{bChan} ' intensity'],'Interpreter','none')
   
    %Overlay the line fit
    plot(xlim,xlim .* fitCoef(iImage,1) + fitCoef(iImage,2),'--r')
    
    
                                               
end


%Get the average slope and intercept
avgCoef = mean(fitCoef(:,1)); %#ok<NASGU>
stdCoef = std(fitCoef(:,1)); %#ok<NASGU>



%% ---- Output ----- %%


%Finish and save the figure
figure(allFig)
hgsave(allFig,[movieData.(pName).directory filesep 'bleedthrough plot.fig'])
if batchMode
    close(allFig);
end

%Save the results

%Modify the filename to reflect the channels used.
fName = [fName '_' movieData.channelDirectory{fChan} '_to_' ...
    movieData.channelDirectory{bChan} '.mat'];
save([movieData.(pName).directory filesep fName],'avgCoef','stdCoef','fitCoef','fitStats')


%Update the moviedata
movieData.(pName).status = 1;
movieData.(pName).fileName = fName;
movieData.(pName).dateTime = datestr(now);
movieData.(pName).fluorohporeChannel = fChan;
movieData.(pName).bleedthroughChannel = bChan;
movieData.(pName).fluorMaskChannel = fMaskChan;
movieData.(pName).bleedMaskChannel = bMaskChan;
updateMovieData(movieData);


disp('Finished with bleedthrough calculation!')



function [fChan,bChan,fMaskChan,bMaskChan,batchMode] = parseInput(argArray)



%Init output
batchMode = [];
fChan = [];
bChan = [];
fMaskChan = [];
bMaskChan = [];

if isempty(argArray)
    return
end

nArg = length(argArray);

%Make sure there is an even number of arguments corresponding to
%optionName/value pairs
if mod(nArg,2) ~= 0
    error('Inputs must be as optionName / value pairs!')
end

for i = 1:2:nArg

    switch argArray{i}                     

       case 'BatchMode'
           batchMode = argArray{i+1};

       case 'FluorophoreChannel'
           fChan = argArray{i+1};

       case 'BleedthroughChannel'

           bChan = argArray{i+1};
           
        case 'FluorophoreMaskChannel'
            
            fMaskChan = argArray{i+1};
            
        case 'BleedthroughMaskChannel'
            
            bMaskChan = argArray{i+1};
       
       otherwise

           error(['"' argArray{i} '" is not a valid option name! Please check input!'])
    end    
end
