%Script to plot p values: it takes the pmatrix and plot in a 2D graphic
%where y is the receptor density and x is the association probability. 
% It generates 5 different figures corresponding to the label ratio and
% saves them in the current file.

% directory with pValue matrix
currDir = '/project/biophysics/jaqaman_lab/interKinetics/ldeoliveira/20161028/target/results/S_PMatrix_dT0p1';% the name until target
% title of the figure will consider the infos that are filled here for the
% name of the target
    rDtarget = {'rD20'};%;'rD6';'rD8';'rD10';'rD12';'rD14';'rD16'}; 
    aPtarget = {'aP0p5'};
    lRtarget = {'lR0p04'};
    
   % values of rD, aP and lR of probe
    rDvals = [20;40;60;80;100;120;140;160];
    aPvals = [0.2;0.3;0.4;0.5;0.6;0.7;0.8];
    lRStr = {'lR0p01';'lR0p02';'lR0p03';'lR0p04';'lR0p05'};
    
    
 %figures   
 for lRindx=1:length(lRStr)
    %load pvalue matrix
 temp= load([currDir,filesep,rDtarget{1},aPtarget{1},lRtarget{1},filesep,'pMatrix.mat']);
 pMatrix=temp.pMatrix;

%plot the figure

 imagesc(aPvals,rDvals,pMatrix(:,:,lRindx));
 colorbar
 
 % configurations to have the graphic ploted in the "normal" direction.
        axH = gca; %ax = gca returns the handle to the current axes for the
% current figure. If an axes does not exist, then gca creates an axes and 
% returns its handle. You can use the axes handle to query and modify axes
% properties. 
        set(axH,'YDir','normal');
        set(axH,'FontSize',15);
% label info        
%         xlabel(axH,'Association probability','FontSize',16);        
%         ylabel(axH,'Receptor Density','FontSize',16);
        caxis([0 1]) %limits for the colorbar
       h = colorbar;
       ylabel(h, 'p-value','FontSize',15) 
%title        
%title        
        title(axH,['target:',rDtarget{1},filesep,aPtarget{1},filesep,lRtarget{1} ' and Probe:',lRStr{lRindx}],'FontSize',12);
        
%Save figure
        figH = gcf;
        set(figH,'Name',lRStr{lRindx});
        outFile = [currDir,filesep,rDtarget{1},aPtarget{1},lRtarget{1},filesep,'pMatrix_',lRStr{lRindx},'_plot_1'];
        saveas(figH,outFile,'png');
        saveas(figH,outFile,'fig');
        
        fprintf('\nFigures saved in %s.\n',outFile);
        
  end