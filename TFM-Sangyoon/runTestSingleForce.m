% runTestSingleForce tests effect of force magnitude and area of force
% application on correctness of displacement tracking and force
% reconstruction.
%% Simulations - initialization  for f and d
nExp = 5;
d_err = zeros(20,10,nExp);
f_err = zeros(20,10,nExp);
dispDetec = zeros(20,10,nExp);
forceDetec = zeros(20,10,nExp);
peakForceRatio = zeros(20,10,nExp);
% kk=0;
%% simulation for f and d
for epm=1:nExp
    p=0;
    ii=0;
    for f=200:200:4000 %Pa
        ii=ii+1;
        jj=0;
        for d=2:2:20
            jj=jj+1;
    %         kk=0;
            for cL = 15%[9 15 21]
                p=p+1;
    %             kk=kk+1;
                dataPath=['/files/.retain-snapshots.d7d-w0d/LCCB/fsm/harvard/analysis/Sangyoon/Bead-tracking/singleForceTesting/f_vs_d/simulations/exp' num2str(epm) 'f' num2str(f) 'd' num2str(d) 'cL' num2str(cL)];
                if p==1
                    [d_err(ii,jj,epm),dispDetec(ii,jj,epm),f_err(ii,jj,epm),peakForceRatio(ii,jj,epm),forceDetec(ii,jj,epm),bead_x, bead_y, Av]=testSingleForce(f,d,cL,dataPath); 
    %                 [d_err(ii,jj,kk),dispDetec(ii,jj,kk),f_err(ii,jj,kk),peakForceRatio(ii,jj,kk),bead_x, bead_y, Av]=testSingleForce(f,d,cL,dataPath); 
                else
                    [d_err(ii,jj,epm),dispDetec(ii,jj,epm),f_err(ii,jj,epm),peakForceRatio(ii,jj,epm),forceDetec(ii,jj,epm),~,~,~]=testSingleForce(f,d,cL,dataPath,bead_x, bead_y, Av);
    %                 [d_err(ii,jj,kk),dispDetec(ii,jj,kk),f_err(ii,jj,kk),peakForceRatio(ii,jj,kk),~,~,~]=testSingleForce(f,d,cL,dataPath,bead_x, bead_y, Av);
                end
            end
        end
    end
end
%% save
save('/files/.retain-snapshots.d7d-w0d/LCCB/fsm/harvard/analysis/Sangyoon/Bead-tracking/singleForceTesting/data.mat')
%% load
load('/files/.retain-snapshots.d7d-w0d/LCCB/fsm/harvard/analysis/Sangyoon/Bead-tracking/singleForceTesting/data.mat')
%% reanalyze for dispDetec
for epm=1%:nExp
    p=0;
    ii=0;
    for f=200:200:4000 %Pa
        ii=ii+1;
        jj=0;
        for d=2:2:20
            jj=jj+1;
    %         kk=0;
            for cL = 15%[9 15 21]
                p=p+1;
    %             kk=kk+1;
                dataPath=['/files/.retain-snapshots.d7d-w0d/LCCB/fsm/harvard/analysis/Sangyoon/Bead-tracking/singleForceTesting/f_vs_d/simulations/exp' num2str(epm) 'f' num2str(f) 'd' num2str(d) 'cL' num2str(cL)];
                [~,dispDetec(ii,jj,epm),~,~,~]=analyzeSingleForceData(f,d,cL,dataPath);
            end
        end
    end
    disp(['epm=' num2str(epm)])
end
%%  visualize (contour)
% load('/files/.retain-snapshots.d7d-w0d/LCCB/fsm/harvard/analysis/Sangyoon/Bead-tracking/singleForceTesting_old/data.mat')
f=200:200:4000;
d=2:2:20;
% dispDetec(:,:,1) = meshgrid(d,f);
% dataPath = '/files/.retain-snapshots.d7d-w0d/LCCB/fsm/harvard/analysis/Sangyoon/Bead-tracking/singleForceTesting/f_vs_d/dispDetec';
% visualizeError(f,d,dispDetec,dataPath)
dataPath = '/files/.retain-snapshots.d7d-w0d/LCCB/fsm/harvard/analysis/Sangyoon/Bead-tracking/singleForceTesting/f_vs_d/forceDetec';
visualizeError(f,d,forceDetec,dataPath,'pcolor_with_level1line')
dataPath = '/files/.retain-snapshots.d7d-w0d/LCCB/fsm/harvard/analysis/Sangyoon/Bead-tracking/singleForceTesting/f_vs_d/peakForceRatio';
visualizeError(f,d,peakForceRatio,dataPath,'contourf')
%% for old trackstackflow
nExp = 10;
d_err_old = zeros(10,nExp);
f_err_old = zeros(10,nExp);
dispDetec_old = zeros(10,nExp);
forceDetec_old = zeros(10,nExp);
peakForceRatio_old = zeros(10,nExp);
beadsOnAdh = zeros(nExp,1);
f=1000;
cL = 15;
for epm=1:nExp
    p=0;
    jj=0;
    tstart = cputime;
    for d=2:2:20
        jj=jj+1;
        p=p+1;
%         dataPath=['/files/.retain-snapshots.d7d-w0d/LCCB/fsm/harvard/analysis/Sangyoon/Bead-tracking/singleForceTesting/f_vs_d/simulations/exp' num2str(epm) 'f' num2str(f) 'd' num2str(d) 'cL' num2str(cL) 'interp'];
        dataPath=['/home/sh268/files/LCCB/fsm/harvard/analysis/Sangyoon/Bead-tracking/singleForceTesting/f_vs_d/simulations/exp' num2str(epm) 'f' num2str(f) 'd' num2str(d) 'cL' num2str(cL) 'interp'];
        if p==1
            [d_err_old(jj,epm),dispDetec_old(jj,epm),f_err_old(jj,epm),peakForceRatio_old(jj,epm),forceDetec_old(jj,epm),beadsOnAdh(epm),bead_x{epm}, bead_y{epm}, Av{epm}]= testSingleForce(f,d,cL,dataPath,[],[],[],'QR');
        else
            [d_err_old(jj,epm),dispDetec_old(jj,epm),f_err_old(jj,epm),peakForceRatio_old(jj,epm),forceDetec_old(jj,epm),~,~,~,~]=testSingleForce(f,d,cL,dataPath,bead_x{epm}, bead_y{epm}, Av{epm},'QR');
        end
    end
    disp(['Experiment ' num2str(epm) ' is done! ' num2str(cputime-tstart) ' is elapsed. ' num2str((cputime-tstart)*(nExp-epm)) ' sec is expected.'])
end
%% for new trackstackflow
% change setting for trackStackFlow
d_err_new = zeros(10,nExp);
f_err_new = zeros(10,nExp);
dispDetec_new = zeros(10,nExp);
forceDetec_new = zeros(10,nExp);
peakForceRatio_new = zeros(10,nExp);
beadsOnAdhnew = zeros(nExp,1);
f=1000;
cL = 15;
for epm=1:nExp
    p=0;
    jj=0;
    for d=2:2:20
        jj=jj+1;
        p=p+1;
%         dataPath=['/files/.retain-snapshots.d7d-w0d/LCCB/fsm/harvard/analysis/Sangyoon/Bead-tracking/singleForceTesting/f_vs_d/simulations/exp' num2str(epm) 'f' num2str(f) 'd' num2str(d) 'cL' num2str(cL) 'interp'];
        dataPath=['/home/sh268/files/LCCB/fsm/harvard/analysis/Sangyoon/Bead-tracking/singleForceTesting/f_vs_d/simulations/exp' num2str(epm) 'f' num2str(f) 'd' num2str(d) 'cL' num2str(cL)];
        [d_err_new(jj,epm),dispDetec_new(jj,epm),f_err_new(jj,epm),peakForceRatio_new(jj,epm),forceDetec_new(jj,epm),beadsOnAdhnew(epm),~,~,~]=testSingleForce(f,d,cL,dataPath,bead_x{epm}, bead_y{epm}, Av{epm},'QR');
    end
end
%% save the data
save('/home/sh268/files/LCCB/fsm/harvard/analysis/Sangyoon/Bead-tracking/singleForceTesting/f_vs_d/forceDetecVsDF1000.mat')
%% d vs forceDetec for f=1000Pa
d=2:2:20;
figure, plot(d,mean(forceDetec(5,:,:),3)), hold on, plot(d,mean(forceDetec_old,2),'r')
figure, plot(d,mean(f_err(5,:,:),3)), hold on, plot(d,mean(f_err_old,2),'r')
figure, plot(d,mean(peakForceRatio(5,:,:),3)), hold on, plot(d,mean(peakForceRatio_old,2),'r')

%% surf
figure, surf(x,y,mean(peakForceRatio(:,:,1:2),3)), title('peak force ratio')
figure, surf(x,y,mean(f_err(:,:,1:2),3)), title('force RMS error')
figure, surf(x,y,mean(d_err(:,:,1:2),3)), title('displacement RMS error')
figure, surf(x,y,mean(dispDetec(:,:,1:2),3)), title('detectability')

%% template size on force error, using L2 0th with a new method
nExp = 10;
f=2000;
d=6;
d_err_tsQRnew = zeros(19,nExp);
f_err_tsQRnew = zeros(19,nExp);
dispDetec_tsQRnew = zeros(19,nExp);
forceDetec_tsQRnew = zeros(19,nExp);
peakForceRatio_tsQRnew = zeros(19,nExp);
for epm=1:nExp
    p=0;
    for cL = 7:2:43
        p=p+1;
        dataPath=['/home/sh268/files/LCCB/fsm/harvard/analysis/Sangyoon/Bead-tracking/singleForceTesting/f_vs_d/simulations/exp' num2str(epm) 'f' num2str(f) 'd' num2str(d) 'cL' num2str(cL)];
        [d_err_tsQRnew(p,epm),dispDetec_tsQRnew(p,epm),f_err_tsQRnew(p,epm),peakForceRatio_tsQRnew(p,epm),forceDetec_tsQRnew(p,epm),~,~,~,~]=testSingleForce(f,d,cL,dataPath,bead_x{epm}, bead_y{epm}, Av{epm},'QR');
    end
end
% %% reanalyze for d_err
% f=2000;
% d=14;
% p=0;
% 
% d_err_ts = zeros(17,1);
% for cL = 9:2:41
%     p=p+1;
%     dataPath=['/files/.retain-snapshots.d7d-w0d/LCCB/fsm/harvard/analysis/Sangyoon/Bead-tracking/singleForceTesting/cL_effect/simulations/f' num2str(f) 'd' num2str(d) 'cL' num2str(cL)];
%     [d_err_ts(p)]=analyzeSingleForceData(f,d,cL,dataPath);
% end
%% save
save('/files/.retain-snapshots.d7d-w0d/LCCB/fsm/harvard/analysis/Sangyoon/Bead-tracking/singleForceTesting/cL_effect/data.mat')
%% plotting cL vs. force error
cL= 9:2:43;
figure, plot(cL,f_err_tsQRnew)
figure, plot(cL,peakForceRatio_tsQRnew)
figure, plot(cL,forceDetec_tsQRnew)
figure, plot(cL,d_err_tsQRnew)
hold on
plot(cL,mean(d_err_tsQRnew,2),'k','LineWidth',2)
%% showing displacement maps for each condition
for cL = 9:2:41
    dataPath=['/files/.retain-snapshots.d7d-w0d/LCCB/fsm/harvard/analysis/Sangyoon/Bead-tracking/singleForceTesting/cL_effect/simulations/f' num2str(f) 'd' num2str(d) 'cL' num2str(cL)];
    displPath = [dataPath filesep 'TFMPackage/displacementField'];
    displFile = [dataPath filesep 'TFMPackage/displacementField/displField.mat'];
    load(displFile)
    generateHeatmapFromField(displField,displPath,3.7);
end
%% get the original displacement field
resultPath = [dataPath filesep 'Original' filesep 'data.mat'];
load(resultPath,'x_mat_u','y_mat_u','ux','uy')
generateHeatmapFromGridData(x_mat_u,y_mat_u,ux,uy,dataPath)

%% showing force maps for each condition
for cL = 9:2:41
    dataPath=['/files/.retain-snapshots.d7d-w0d/LCCB/fsm/harvard/analysis/Sangyoon/Bead-tracking/singleForceTesting/cL_effect/simulations/f' num2str(f) 'd' num2str(d) 'cL' num2str(cL)];
    generateHeatmapFromTFMPackage(dataPath,16,false,2000)
end
resultPath = [dataPath filesep 'Original' filesep 'data.mat'];
load(resultPath,'x_mat_u','y_mat_u','force_x','force_y')
generateHeatmapFromGridData(x_mat_u,y_mat_u,force_x,force_y,dataPath)

%% force error
% figure,surf(x,y,newf_err(:,:,2))
f_err_interp   = csapi({200:200:4000,10:-1:1},newf_err(:,:,2));
% figure, fnplt( f_err_interp )
fu = 200:4000;
du = 1:.1:10;
figure,[Cf,hf]=contour(fu,du,fnval(f_err_interp,{fu,du}).',10);
view(-90,90)
set(gca,'ydir','reverse');
colormap jet;

%% original displacementfield when d is small
epm=2; f=600; d=4; cL=15;
% dataPath=['/files/.retain-snapshots.d7d-w0d/LCCB/fsm/harvard/analysis/Sangyoon/Bead-tracking/singleForceTesting/f_vs_d/simulations/exp' num2str(epm) 'f' num2str(f) 'd' num2str(d) 'cL' num2str(cL) 'interp'];
% dataPath=['/files/.retain-snapshots.d7d-w0d/LCCB/fsm/harvard/analysis/Sangyoon/Bead-tracking/singleForceTesting/f_vs_d/simulations/exp' num2str(epm) 'f' num2str(f) 'd' num2str(d) 'cL' num2str(cL)];
dataPath=['/home/sh268/files/LCCB/fsm/harvard/analysis/Sangyoon/Bead-tracking/singleForceTesting/f_vs_d/simulations/exp' num2str(epm) 'f' num2str(f) 'd' num2str(d) 'cL' num2str(cL)];
[d_err_small,dispDetec_small,f_err_small,peakForceRatio_small,forceDetec_small,bead_x, bead_y, Av]= testSingleForce(f,d,cL,dataPath,[],[],[],'QR');
            
%% get the original displacement field
resultPath = [dataPath filesep 'Original' filesep 'data.mat'];
load(resultPath,'x_mat_u','y_mat_u','ux','uy')
generateHeatmapFromGridData(x_mat_u,y_mat_u,ux,uy,dataPath,100)
%% show original force field
load(resultPath,'force_x','force_y')
generateHeatmapFromGridData(x_mat_u,y_mat_u,force_x,force_y,[dataPath '/Original forcefield'],1000,140,220)
%% measured displacementfield when d is small
% get the measured displacement field
displPath = [dataPath filesep 'TFMPackage/displacementField'];
displFile = [dataPath filesep 'TFMPackage/displacementField/displField.mat'];
load(displFile)
generateHeatmapFromField(displField,displPath,0.2,'uDefinedRYG',140,220);
% generateHeatmapFromField(displField,displPath,0.25,'cool');
%% measured forcemap when d is small
forcePath = [dataPath filesep 'TFMPackage/forceField'];
forceFile = [dataPath filesep 'TFMPackage/forceField/forceField.mat'];
load(forceFile)
generateHeatmapFromField(forceField,forcePath,100,'jet',140,220);

%% original displacementfield when d is large
epm=2; f=1000; d=20; cL=15;
% dataPath=['/files/.retain-snapshots.d7d-w0d/LCCB/fsm/harvard/analysis/Sangyoon/Bead-tracking/singleForceTesting/f_vs_d/simulations/exp' num2str(epm) 'f' num2str(f) 'd' num2str(d) 'cL' num2str(cL) 'interp'];
dataPath=['/files/.retain-snapshots.d7d-w0d/LCCB/fsm/harvard/analysis/Sangyoon/Bead-tracking/singleForceTesting/f_vs_d/simulations/exp' num2str(epm) 'f' num2str(f) 'd' num2str(d) 'cL' num2str(cL)];
dataPath=['/home/sh268/files/LCCB/fsm/harvard/analysis/Sangyoon/Bead-tracking/singleForceTesting/f_vs_d/simulations/exp' num2str(epm) 'f' num2str(f) 'd' num2str(d) 'cL' num2str(cL) 'interp'];
[d_err_large,dispDetec_large,f_err_large,peakForceRatio_large,forceDetec_large]= testSingleForce(f,d,cL,dataPath,[],[],[],'QR');
%% show original force field
resultPath = [dataPath filesep 'Original' filesep 'data.mat'];
load(resultPath,'x_mat_u','y_mat_u','ux','uy','force_x','force_y')
generateHeatmapFromGridData(x_mat_u,y_mat_u,force_x,force_y,[dataPath '/Original forcefield'])
%% get the original displacement field
resultPath = [dataPath filesep 'Original' filesep 'data.mat'];
load(resultPath,'x_mat_u','y_mat_u','ux','uy')
generateHeatmapFromGridData(x_mat_u,y_mat_u,ux,uy,dataPath)
%% measured displacementfield when d is large
% get the measured displacement field
displPath = [dataPath filesep 'TFMPackage/displacementField'];
displFile = [dataPath filesep 'TFMPackage/displacementField/displField.mat'];
load(displFile)
generateHeatmapFromField(displField,displPath,2.8,'uDefinedRYG',140,220);
% generateHeatmapFromField(displField,displPath,2.6);
%% measured forcemap when d is large
forcePath = [dataPath filesep 'TFMPackage/forceField'];
forceFile = [dataPath filesep 'TFMPackage/forceField/forceField.mat'];
load(forceFile)
generateHeatmapFromField(forceField,forcePath,1000,'jet',140,220);

%% Bead tracking test with identical image stack
f=0; d=10; cL=21;
dataPath=['/files/.retain-snapshots.d7d-w0d/LCCB/fsm/harvard/analysis/Sangyoon/Bead-tracking/singleForceTesting/f' num2str(f) 'd' num2str(d) 'cL' num2str(cL)];
dataPath=['/Users/joshua2/Documents/PostdocResearch/Traction Force/corrTrackContWind/f' num2str(f) 'd' num2str(d) 'cL' num2str(cL)];
[derr0f, ferr0f] = testSingleForce(f,d,cL,dataPath); 
%% measured displacementfield for zero force
% get the measured displacement field
displPath = [dataPath filesep 'TFMPackage/displacementField'];
displFile = [dataPath filesep 'TFMPackage/displacementField/displField.mat'];
load(displFile)
generateHeatmapFromField(displField,displPath,.15)
