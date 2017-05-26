%Script to compare target and probe intermediate statistics data througth
%the calculation of Mahalanobis distance and pvalue. s and pValue matrix 
% will be saved in same directory of the data in a file caled Results
%
% The outputs of this script are the sMatrix and pMatrix. They are 3D
% matrices where the rows are receptor densities, the colums are association probability
% and the third dimension is the label ratio.
%
%Luciana de Oliveira, July 2016.

resultsDirectory='/project/biophysics/jaqaman_lab/interKinetics/ldeoliveira/20170403/results/targetIS_sT25_dT0p1';


sourceRootTarget='/project/biophysics/jaqaman_lab/interKinetics/ldeoliveira/20170403/analysis/targetIS_sT25_dT0p1';

%Define strings for directory hierarchy as needed
 rDtarget = {'rD12'};%,'rD60','rD80','rD120','rD140','rD160'};
 aPtarget = {'aP0p6'};%'aP0p2','aP0p3','aP0p4','aP0p5','aP0p6','aP0p7','aP0p8'
lRtarget= {'lR0p2'};%,'lR0p3','lR0p4','lR0p5'};

for rDTarIndx = 1 : length(rDtarget)
    
    for aPTarIndx = 1 : length(aPtarget)
        
        for lRTarIndx = 1 : length(lRtarget)
% load ratesAndDensity that has the paramMatrix 
currDir=[sourceRootTarget,filesep,rDtarget{rDTarIndx},filesep,...
                aPtarget{aPTarIndx},filesep,lRtarget{lRTarIndx}];
tmp = load(fullfile(currDir,filesep,'ratesAndDensityComb_dt0p1_T10.mat'));

% call paramMatrix and determine target cluster sizes

paramMatrixTarget=tmp.paramMatrix;
clusterSizeTargetOnRate=size(tmp.rateOnPerClust,1);
clusterSizeTargetOffRate=size(tmp.rateOffPerClust,1);
clusterSizeTargetDensity=size(tmp.densityPerClust,1);

%probes
sourceRootProbe ='/project/biophysics/jaqaman_lab/interKinetics/ldeoliveira/2016/12/20161201/analysis/probeIS_sT25_dT0p1';
%Define strings for directory hierarchy as needed
rDDir = {'rD4','rD6','rD8','rD10','rD12','rD14','rD16'};%,'rD8','rD10','rD12','rD14','rD16'};
aPDir = {'aP0p2','aP0p3','aP0p4','aP0p5','aP0p6','aP0p7','aP0p8'};%'aP0p2','aP0p3','aP0p4','aP0p5','aP0p6','aP0p7','aP0p8'
lRDir = {'lR0p1','lR0p2','lR0p3','lR0p4','lR0p5','lR0p6'};%,'aP0p4','aP0p5','aP0p6','aP0p7','aP0p8'};
%,'rD6','rD8','rD10','rD12','rD14','rD16'};%,'rD4','rD6','rD8','rD10','rD12','rD14','rD16'};

fprintf('\n===============================================================');

        
%The top level directory is that of receptor density
for lRDirIndx = 1 : length(lRDir)
    
    
    tic
    %Iterate through association probability values per density
    for aPDirIndx = 1 : length(aPDir)
        
     
        
        %iterate through the different labeling ratios
        for rDDirIndx = 1 : length(rDDir)
            
               fprintf('\nProcessing lR = %s, aP = %s ',rDDir{rDDirIndx},aPDir{aPDirIndx});
            
            %name of current directory
            currDir = [sourceRootProbe,filesep,rDDir{rDDirIndx},filesep,...
                aPDir{aPDirIndx},filesep,lRDir{lRDirIndx}];
            
            %load ratesAndDensity that has the paramMatrix 
            tmp = load(fullfile(currDir,'ratesAndDensityComb_dt0p1_T10.mat'));
           
%           call paramMatrix and determine probe cluster sizes
            paramMatrixProbe=tmp.paramMatrix;
            clusterSizeProbeOnRate=size(tmp.rateOnPerClust,1);
            clusterSizeProbeOffRate=size(tmp.rateOffPerClust,1);
            clusterSizeProbeDensity=size(tmp.densityPerClust,1);    

             
                     
%call function to compare target and probe data
[sMatrix(rDDirIndx,aPDirIndx,lRDirIndx),pMatrix(rDDirIndx,aPDirIndx,lRDirIndx)]=calculationMahalonobisDistanceandPvalue(paramMatrixTarget,paramMatrixProbe);      

       end
    end
end
%save s and p matrix
%make a directory
resultsDir=[resultsDirectory,filesep,rDtarget{rDTarIndx},aPtarget{aPTarIndx},lRtarget{lRTarIndx}];
 mkdir(resultsDir)
          save([resultsDir,filesep,'sMatrix.mat'],'sMatrix','-v7.3');
                        save([resultsDir,filesep,'pMatrix.mat'],'pMatrix','-v7.3');
                        
        end 
    end
end
