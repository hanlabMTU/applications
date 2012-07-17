classdef CometPostTrackingProcess < PostTrackingProcess
    % A concrete class for classifying comet tracks
    %
    % Sebastien Besson, March 2012
    
    methods (Access = public)
        function obj = CometPostTrackingProcess(owner, varargin)
            % Constructor of the CometDetectionProcess
            
            if nargin == 0
                super_args = {};
            else
                % Input check
                ip = inputParser;
                ip.addRequired('owner',@(x) isa(x,'MovieData'));
                ip.addOptional('outputDir',owner.outputDirectory_,@ischar);
                ip.addOptional('funParams',[],@isstruct);
                ip.parse(owner,varargin{:});
                outputDir = ip.Results.outputDir;
                funParams = ip.Results.funParams;
                
                super_args{1} = owner;
                super_args{2} = CometPostTrackingProcess.getName;
                super_args{3} = @postProcessMovieComets;
                if isempty(funParams)  % Default funParams
                    funParams = CometPostTrackingProcess.getDefaultParams(owner,outputDir);
                end
                super_args{4} = funParams;
            end
            
            obj = obj@PostTrackingProcess(super_args{:});
        end
        function varargout = loadChannelOutput(obj,iChan,varargin)
            
            % Input check
            outputList = {'projData','tracks'};
            ip =inputParser;
            ip.addRequired('iChan',@(x) isscalar(x) && obj.checkChanNum(x));
            ip.addOptional('iFrame',1:obj.owner_.nFrames_,@(x) all(obj.checkFrameNum(x)));
            ip.addParamValue('output',outputList,@(x) all(ismember(x,outputList)));
            ip.parse(iChan,varargin{:})
            iFrame = ip.Results.iFrame;
            output = ip.Results.output;
            if ischar(output),output={output}; end
            
            % Data loading
            s = load(obj.outFilePaths_{1,iChan},'projData');
            for j=1:numel(output)
                if isequal(output{j},'projData')
                    varargout{1}=s.(output{j});
                else
                    
                    trackData=s.projData.nTrack_sF_eF_vMicPerMin_trackType_lifetime_totalDispPix;
                    fullIdx=trackData(:,1);
                    trackType=trackData(:,5);
                    sF=trackData(:,2);
                    [xMat,yMat]=plusTipGetSubtrackCoords(s.projData,[]);
                    
                    correspFullIdx=fullIdx(~isnan(xMat(:,iFrame)));
                    if ~isempty(correspFullIdx) && iFrame>1
                        subtracks2keep=find(ismember(fullIdx,correspFullIdx));
                        varargout{1}.x=xMat(subtracks2keep,1:iFrame);
                        varargout{1}.y=yMat(subtracks2keep,1:iFrame);
                        varargout{1}.fullIdx=fullIdx(subtracks2keep);
                        varargout{1}.trackType=trackType(subtracks2keep);
                        varargout{1}.sF=sF(subtracks2keep);
                    else
                        varargout{1}.x=[];
                        varargout{1}.y=[];
                    end
                end
            end
        end
    end
    methods (Static)
        function output = getDrawableOutput()
            output(1).name='Classified tracks';
            output(1).var='tracks';
            output(1).formatData=[];
            output(1).type='overlay';
            output(1).defaultDisplayMethod=@(x) MTTracksDisplay();
        end
        
        function name = getName()
            name = 'Microtubule dynamics classification';
        end
        function h = GUI()
            h = @cometPostTrackingProcessGUI;
        end
        
        function funParams = getDefaultParams(owner,varargin)
            % Input check
            ip=inputParser;
            ip.addRequired('owner',@(x) isa(x,'MovieData'));
            ip.addOptional('outputDir',owner.outputDirectory_,@ischar);
            ip.parse(owner, varargin{:})
            outputDir=ip.Results.outputDir;
            
            % Set default parameters
            funParams.ChannelIndex = 1 : numel(owner.channels_);
            funParams.OutputDirectory = [outputDir  filesep 'mtTracks'];
            funParams.makeHist = true;
            funParams.remBegEnd = true;
            funParams.fgapReclassScheme = 1;
            funParams.bgapReclassScheme = 1;
        end
        
        function schemes = getFgapReclassificationSchemes()
            
            schemes{1} = 'Local scheme: 2-3 frames before pause';
            schemes{2} = 'Local scheme: FullGrowth Subtrack Velocity';
            schemes{3} = 'Unimodal Thresholding';
            schemes{4} = 'No reclassification';            
        end
        
        function schemes = getBgapReclassificationSchemes()
            schemes{1} = 'bGapThresh = 95th Percentile of fGapVel';
            schemes{2} = 'Unimodal Fgap Thresh: No Correct';
            schemes{3} = 'Unimodal Fgap Thresh: Correct For Comet Latency';
            schemes{4} = 'Fluctuation Radius Displacement Cut-off';
        end
        
    end
end