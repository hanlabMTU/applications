function [] = gefFig7_similarity_RHOA_GEF_Contractility48h_SMIFH10um()

addpath(genpath('/home2/azaritsky/code/applications/monolayer/'));
addpath(genpath('/home2/azaritsky/code/extern/export_fig'));
close all;

followupDname = '/project/bioinformatics/Danuser_lab/GEFscreen/analysis/MetaAnalysis/ProjectAll20160523/dayGeneControlFollowup/';
figDname = '/project/bioinformatics/Danuser_lab/GEFscreen/analysis/Figures/Fig7/similarity_RHOA_GEF_Contractility48h_SMIFH10um/';
validateGenes = {'Y15uMp48','Y20uMp48','Blebbistatin10uMp48','RHOA','ARHGEF18','SMIFH2dose10uM','ARHGEF3','ARHGEF28','ARHGEF11'};%,'Y25uMp48'

outputPrefix = 'RHOA_GEF_Contractility48h_SMIFH10um';

whDayFollowupSimilarities2016(followupDname,validateGenes,figDname,outputPrefix,[6.5,16.5]);

end