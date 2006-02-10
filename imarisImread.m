function [movie,movieSize,movieName,moviePath,movieProperties,imarisHandle,loadStruct] = imarisImread(multiArgument,pathName,cropIdx,maxSize)
%IMARISIMREAD will launch imaris to read a movie (or any parts of it) from disk
%
% SYNOPSIS [movie,movieSize,movieName,moviePath,movieProperties,imarisHandle,loadStruct] = imarisImread(multiArgument,pathName,cropIdx,maxSize)
%
% INPUT    multiArgument      : (opt) either the name of the movie, or an
%                                 list of indices pointing to the formats
%                                 (see below), or a handle to an imaris
%                                 that has already loaded a movie, or a
%                                 loadStruct (see below)
%                               - If no fileName or handle is given, the program will
%                                 launch a GUI for file selection
%                               - If a handle is given, the program will
%                                 load from the already loaded movie
%                               - If you supply a loadStruct, the program
%                                 will load the next batch of frames of a
%                                 movie.
%          pathName           : (opt) pathName. If no pathName is given,
%                                 pwd is used
%          cropIdx            : (opt) 2x5 array with [startIdx;endIdx] how
%                                 to crop the movie. If no cropping in a
%                                 dimension, use zeros.
%                                 Example: [5,5,0,0,2;10,0,0,0,2] will only
%                                 take voxels from 5 to 10 in x, 5:end in
%                                 y, all in z, all colors, and only
%                                 timepoint # 2
%
%                                 Currently, the full movie is loaded into
%                                 imaris, so that it is possible to ask for
%                                 additional parts of the same movie later
%                                 without having to load it first
%
%          maxSize         : (opt) Scalar with the maximum movie size (in
%                                 bytes) If you supply maxSize, a
%                                 loadStruct will be returned to load
%                                 further chunks of the movie (see below).
%                                 If you supply both cropIdx and maxSize,
%                                 the cropping in x,y,z, and c will be
%                                 taken into account. The movie will be
%                                 split along z.
%
% OUTPUT   movie              : the image file
%          movieSize          : original size of movie [x y z c t]
%          movieName          : fileName
%          moviePath          : pathName ending with a filesep
%          movieProperties    : additional info on the movie (not supported yet)
%          imarisHandle       : handle to the imaris program that has
%                               loaded the movie. If you do not request
%                               this output argument, imaris will close
%                               after the movie has been loaded.
%          loadStruct         : structure with fields
%                                 .maxSize : size you originally supplied
%                                 .frames2Load : cell with cropIdx for
%                                       every batch of frames to load. If
%                                       empty, no more frames will be
%                                       loaded (loop through parts of movie
%                                       with
%                                 "while ~isempty(loadStruct.frames2load)"
%                                 .loadedFrames : vector of all frames
%                                       that have been loaded
%                                 .imarisHandle : handle to the imaris
%                                       program
%
%
% REMARKS: Imaris does not close after having been launched
%
%     FILTERLIST
%     #   filter          filterName
%     1    '*.*',          'All Files (auto format detection) (*.*)',
%     2    '*.ims',        'Imaris 3 (*.ims)',
%     3    '*.ims',        'Imaris Classic (*.ims)',
%     4    '*.ics;*.ids',  'ICS file (*.ics;*.ids)',
%     5    '*.lsm',        'Zeiss: LSM510 (*.lsm)',
%     6    '*.tif;*.tiff', 'Zeiss: LSM410,LSM310 (*.tif;*.tiff)',
%     7    '*.zvi',        'Zeiss: AxioVision (*.zvi)',
%     8    '*.tif;*.tiff', 'Leica: TCS-NT (*.tif;*.tiff)',
%     9    '*.tif;*.tiff', 'Leica: Series (*.tif;*.tiff)',
%    10    '*.tif;*.tiff', 'Leica: LCS (*.tif;*.tiff)',
%    11    '*.pic',        'Biorad: MRC 1024,600 (series) (*.pic)',
%    12    '*.rbinf',      'TILLvisION (*.rbinf)',
%    13     '*.stk',        'Universal Imaging: MetaMorph STK (*.stk)',
%    14    '*.r3d;*.dv',   'Delta Vision (*.r3d;*.dv)',
%    15    '*.tif;*.tiff', 'Olympus: FluoView TIFF (*.tif;*.tiff)',
%    16    '*.tif;*.tiff', 'Olympus: cell^R (*.tif;*.tiff)',
%    17    '*.ome',        'Open Microscopy Environment Xml (*.ome)',
%    18    '*.tif;*.tiff', 'Tiff (adjustable file series) (*.tif;*.tiff)',
%    19    '*.tif;*.tiff', 'Tiff (series) (*.tif;*.tiff)',
%    20    '*.bmp',        'BMP (series) (*.bmp)',
%
%
% c: jonas 05/04
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%=================
% TEST INPUT
%=================

% define defaults
filterList = {'*.*',    'All Files (auto format detection) (*.*)',      'reader=''All Formats''';...
    '*.ims',        'Imaris 3 (*.ims)',                             'reader=''Imaris3''';...
    '*.ims',        'Imaris Classic (*.ims)',                       'reader=''Imaris''';...
    '*.ics;*.ids',  'ICS file (*.ics;*.ids)',                       'reader=''ICS''';...
    '*.lsm',        'Zeiss: LSM510 (*.lsm)',                        'reader=''LSM510''';...
    '*.tif;*.tiff', 'Zeiss: LSM410,LSM310 (*.tif;*.tiff)',          'reader=''LSM410''';...
    '*.zvi',        'Zeiss: AxioVision (*.zvi)',                    'reader=''AxioVision''';...
    '*.tif;*.tiff', 'Leica: TCS-NT (*.tif;*.tiff)',                 'reader=''LeicaSingle''';...
    '*.tif;*.tiff', 'Leica: Series (*.tif;*.tiff)',                 'reader=''LeicaSeries''';...
    '*.tif;*.tiff', 'Leica: LCS (*.tif;*.tiff)',                    'reader=''LeicaVista''';...
    '*.pic',        'Biorad: MRC 1024,600 (series) (*.pic)',        'reader=''Biorad''';...
    '*.rbinf',      'TILLvisION (*.rbinf)',                         'reader=''TILLvisION''';...
    '*.stk',        'Universal Imaging: MetaMorph STK (*.stk)',     'reader=''MetamorphSTK''';... %#13
    '*.r3d;*.dv',   'Delta Vision (*.r3d;*.dv)',                    'reader=''DeltaVision''';...
    '*.tif;*.tiff', 'Olympus: FluoView TIFF (*.tif;*.tiff)',        'reader=''Olympus''';...
    '*.tif;*.tiff', 'Olympus: cell^R (*.tif;*.tiff)',               'reader=''OlympusCellR''';...
    '*.ome',        'Open Microscopy Environment Xml (*.ome)',      'reader=''OmeXml''';...
    '*.tif;*.tiff', 'Tiff (adjustable file series) (*.tif;*.tiff)', 'reader=''SeriesAdjustable''';...
    '*.tif;*.tiff', 'Tiff (series) (*.tif;*.tiff)',                 'reader=''TiffSeries''';...
    '*.bmp',        'BMP (series) (*.bmp)',                         'reader=''BmpSeries'''};
numFilters   = size(filterList,1);
filterChoice = [1:numFilters];
launchGUI    = 1;
launchImaris = 1;
checkSize = 0;



% first argument
if nargin == 0 | isempty(multiArgument)

    % no first argument, so all is normal

elseif isnumeric(multiArgument)
    % filterIdx

    % make sure we have reasonable filter choices
    if max(multiArgument) <= numFilters & min(multiArgument) > 0
        filterChoice = multiArgument;
    else
        error(['there are only' num2str(numFilters) 'possible choices for filters, starting at 1'])
    end

    filterChoice = multiArgument;

elseif isstr(multiArgument)
    % fileName

    launchGUI = 0;

    movieName = multiArgument;

    if any(findstr(movieName,filesep))
        error('Please specify the path in the second input argument')
    end

elseif strcmp(class(multiArgument),'COM.Imaris_Application')
    % imarisHandle

    launchImaris = 0;
    launchGUI    = 0;
    vImarisApplication = multiArgument;
    % in the future, we could test here whether a movie has been loaded

elseif isstruct(multiArgument)
    % assign loadStruct
    loadStruct = multiArgument;

    % check whether there is anything to be loaded still
    if isempty(loadStruct.frames2load)
        movie = [];
        movieSize = [];
        movieName =[];
        moviePath = [];
        movieProperties = [];
        imarisHandle = [];
        loadStruct = [];
        return
    end

    % we don't need GUI etc.
    launchImaris = 0;
    launchGUI = 0;
    vImarisApplication = loadStruct.imarisHandle;

    checkSize = 1;

else
    error('invalid first input argument')
end

% second argument
if nargin < 2 | isempty(pathName)

    if ~launchGUI
        % only get pathName if we have to
        moviePath = pwd;
    else
        moviePath = [];
    end

else
    moviePath = pathName;
end

if ~ isempty(moviePath) & ~strcmp(moviePath(end),filesep)
    moviePath = [moviePath,filesep];
end

% third argument
if nargin < 3 | isempty(cropIdx)

    % no crop
    cropIdx = [];

else
    % cropIdx will be tested once we know the size of the movie
    if ~all(size(cropIdx)==[2 5])
        error('Please specify cropIdx as 2x5 array')
    end

end

% fourth argument
if nargin < 4 || isempty(maxSize)
% nothing
else
    checkSize = 1;
    % initialize loadStruct
    loadStruct = [];
end

%=============================


%==============================
% INITIALIZE
%==============================

if launchImaris
    % get handle to imaris or launch, if necessary
    vImarisApplication = actxserver('Imaris.Application');
end

% select filterchoice from list
filterList = filterList(filterChoice,:);

%==========================
% LOAD MOVIE INTO IMARIS
%==========================

if launchGUI

    % ask for movieName, moviePath
    [movieName,moviePath,filterIdx] = uigetfile(filterList(:,1:2),'Please select an image file');

    % handle user cancel
    if isequal(movieName,0)
        error('no movie loaded - User abort')
    end

else
    filterIdx = 1;
end

if launchImaris
    % load movie into imaris
    vImarisApplication.FileOpen([moviePath movieName], filterList{filterIdx,3});
end

% and get all the corresponding properties
vImarisDataSet = vImarisApplication.mDataSet;
movieSize = [vImarisDataSet.mSizeX,...
    vImarisDataSet.mSizeY,...
    vImarisDataSet.mSizeZ,...
    vImarisDataSet.mSizeC,...
    vImarisDataSet.mSizeT];

if ~all(movieSize)
    error('Problem loading movie into Imaris')
end

%==========================
% CHECK SIZE
%==========================

if checkSize
    % check loadStruct: If it's complete already, we just have to take the
    % right cropIdx
    if isempty(loadStruct)
        % calculate frameSizeBytes (8 bytes per pixel). Find how many we
        % can fit into maxSize to see how many movie-chunks have. First
        % check whether we are using a cropped movie, though.
        includeArray = [ones(1,5); movieSize];

        if ~isempty(cropIdx)
            % check start indices
            sIdx = find(cropIdx(1,1:4));
            newStart = cropIdx(1,sIdx);

            if any(newStart < 1)
                error('crop-indices have to start at 1!')
            end

            % put in newStart
            includeArray(1,sIdx) = newStart;

            % check end indices
            eIdx = find(cropIdx(2,1:4));
            newEnd = cropIdx(2,eIdx);

            if any(newEnd > movieSize(eIdx))
                error('crop-indices can not be outside of the movie!')
            end

            % put in newStart
            includeArray(2,eIdx) = newEnd;
        end

        % now calculate size of frame
        frameSizeBytes = 8 * prod(diff(includeArray(:,1:4),1,1)+1);

        % calculate number of frames per chunk
        numFramesPerChunk = floor(maxSize/frameSizeBytes);

        if numFramesPerChunk == 0
            warning('less than one frame fits into max chunk size - trying to load one');
            numFramesPerChunk = 1;
        end

        % do this quick and dirty - it's one of those Fridays again
        numChunks = ceil(movieSize(end)/numFramesPerChunk);
        startIdx = [1:numFramesPerChunk:movieSize(end)];
        endIdx  = unique(...
            [numFramesPerChunk:numFramesPerChunk:movieSize(end),movieSize(end)]);
        for iChunk = numChunks:-1:1
            includeArray(:,5) = [startIdx(iChunk);endIdx(iChunk)];
            frames2load{iChunk,1} = includeArray;
        end

        % fill loadStruct
        loadStruct.maxSize = maxSize;
        loadStruct.frames2load = frames2load;
        loadStruct.loadedFrames = [];
        loadStruct.imarisHandle = vImarisApplication;
        loadStruct.movieName = movieName;
        loadStruct.moviePath = moviePath;
    end

    % now that we have loadStruct either from input or from just being
    % created, take cropIdx, update frames2load and loadedFrames
    cropIdx = loadStruct.frames2load{1};
    loadStruct.frames2load(1) = [];
    loadStruct.loadedFrames = cropIdx(1,5):cropIdx(2,5);
    movieName = loadStruct.movieName;
    moviePath = loadStruct.moviePath;



else
    % just in case the user wants that
    loadStruct.maxSize = NaN;
    loadStruct.frames2Load = {};
    if isempty(cropIdx) || all(cropIdx(:,5)==0)
        loadStruct.loadedFrames = 1:movieSize(5);
    else
        loadStruct.loadedFrames = cropIdx(1,5):cropIdx(2,5);
    end
    loadStruct.imarisHandle = vImarisApplication;
    loadStruct.movieName = movieName;
end


%==========================
% READ MOVIE FROM IMARIS
%==========================

% crop: define includeArray
% [xStart,yStart,zStart,cStart,tStart;xEnd,yEnd,zEnd,cEnd,tEnd], then
% adapt via cropIdx
includeArray = [ones(1,5); movieSize];

if ~isempty(cropIdx)
    % check start indices
    sIdx = find(cropIdx(1,:));
    newStart = cropIdx(1,sIdx);

    if any(newStart < 1)
        error('crop-indices have to start at 1!')
    end

    % put in newStart
    includeArray(1,sIdx) = newStart;

    % check end indices
    eIdx = find(cropIdx(2,:));
    newEnd = cropIdx(2,eIdx);

    if any(newEnd > movieSize(eIdx))
        error('crop-indices can not be outside of the movie!')
    end

    % put in newStart
    includeArray(2,eIdx) = newEnd;
end


% now read the whole movie from imaris
movie = zeros(diff(includeArray,1,1)+1);
for t = 1:includeArray(2,5)-includeArray(1,5)+1
    for c = 1:includeArray(2,4)-includeArray(1,4)+1
        for z = 1:includeArray(2,3)-includeArray(1,3)+1
            % tmpSlice: read from includeArray, which we have to get.
            % if we start with, say, tp 5, then we have to read #4 in
            % imaris, but t will be 1, so we have to subtract 2.
            tmpSlice = vImarisDataSet.GetDataSlice(...
                includeArray(1,3)+z-2,...
                includeArray(1,4)+c-2,...
                includeArray(1,5)+t-2);
            movie(:,:,z,c,t) = tmpSlice(includeArray(1,1):includeArray(2,1),includeArray(1,2):includeArray(2,2));
        end
    end
end


%=======================

%========================
% MOVIE PROPERTIES
%========================

% read according to manufacturer.
% so far, use field names you would get from readr3dheader
movieType = vImarisApplication.mDataSet.GetParameter('Image','ManufactorString');
switch movieType
    case 'MetaMorph'
        movieProperties.pixelX= str2double(...
            vImarisApplication.mDataSet.GetParameter('Metamorph STK','XCalibration'));
        movieProperties.pixelY= str2double(...
            vImarisApplication.mDataSet.GetParameter('Metamorph STK','YCalibration'));
        movieProperties.pixelZ = str2double(...
            vImarisApplication.mDataSet.GetParameter('Metamorph STK','DeltaZ'));
        movieProperties.lensID = 0;
        movieProperties.numCols = movieSize(2);
        movieProperties.numRows = movieSize(1);
        movieProperties.numZSlices = movieSize(3);
        movieProperties.numTimepoints = movieSize(5);
        movieProperties.numWvs = movieSize(4);
        % wvl in um!!
        movieProperties.wvl = str2double(...
            vImarisApplication.mDataSet.GetParameter('Metamorph STK','WaveLength'))/1000;
    otherwise
        warning('no property reader defined for %s',movieType);
        movieProperties = [];
end
        


%=========================

% assign output
imarisHandle = vImarisApplication;


