function group = groupingLAP(fileName,dirName)

% pass the TRACKS struct as input
nbFrames = 125;
LifeTime = 4; %4

MaxTimeSpan = 15;
coneAngPos = cos(pi/4);%45
coneAngNeg = cos(pi/18);%10
trackAng = cos(pi/3);%60
constVel = 1; %debug100
duConst = 1000000;

if nargin == 0
    [fileName,dirName] = uigetfile('*.mat','Choose a .mat file');
    load([dirName,filesep,fileName]);
end
%check wether the "groups" subdirectory exists or not 
[success, msg, msgID] = mkdir(dirName(1:end-13), 'groups');

if (success ~= 1)
    error(msgID, msg); 
elseif (~isempty(msg))
    fprintf('Directory "groups" already exists.\n');
else
    fprintf('Directory "groups" has been created.\n');
end

indx = find( [tracks.len] >= LifeTime);
TimeSpan = min(max([tracks.len]),MaxTimeSpan); 
traj = tracks(indx);
leIndx = length(indx);

% calculate trajectory information
for i = 1:leIndx
    traj(i).endID = traj(i).startID + traj(i).len - 1;
    dY = traj(i).points(end,1) - traj(i).points(1,1);
    dX = traj(i).points(end,2) - traj(i).points(1,2);
    traj(i).vec = [dX; dY];
    traj(i).vel = sqrt(dY^2+dX^2)/traj(i).len;
end
% exclude tracks with NO motion
traj = traj(find([traj.vel]>0)); % SOME DONT MOVE!?
leIndx = length(traj);

% get start & end points of all tracks for distance matrix calculation
for i = 1:leIndx
    E(i,:)=traj(i).points(end,1:2);
    B(i,:)=traj(i).points(1,1:2);
end

[listStartID,indxStartID] = sort([traj.startID]);
M = sparse(leIndx,leIndx); % angle multiplication matrix
C = sparse(leIndx,leIndx); % distance cut-off matrix

progressText(0,'First FOR-loop') % Create text
for i = 1:leIndx
    if TimeSpan > nbFrames-traj(i).endID
        T = nbFrames-traj(i).endID;
    else
        T = TimeSpan;
    end
    if (traj(i).endID < (nbFrames - LifeTime))

        aux1 = find(listStartID>(traj(i).endID+1));
        firstIndx =  aux1(1);

        aux2 = find(listStartID>(traj(i).endID+T+1));
        if ~isempty(aux2)
            finalIndx =  aux2(1)-1;
        else
            finalIndx = length(listStartID);
        end

        a = indxStartID(firstIndx:finalIndx);

        magTrajVec = sqrt(sum(traj(i).vec.^2,1));
        magTrajA = sqrt(sum([traj(a).vec]'.^2,2));
        cos_trackAng = ([traj(a).vec]'*traj(i).vec)./(magTrajA*magTrajVec);
        
        listA = find(cos_trackAng>trackAng);
        aa = a(listA);
        cos_trA = cos_trackAng(listA);
   
        if ~isempty(aa)
            dxCo = []; dyCo = [];
            for j = 1:length(aa)
                dyCo(j) = traj(aa(j)).points(1,1) - traj(i).points(end,1); % get it out of the loop - to the other loop up
                dxCo(j) = traj(aa(j)).points(1,2) - traj(i).points(end,2);
            end
            aVecs = ([dxCo; dyCo])';

            magAvecs = sqrt(sum(aVecs.^2,2));
            magAvecs(find(magAvecs==0)) = 0.001; % some new/t+4 traj begin where an old/t one ended
            cos_coneAng = (aVecs*traj(i).vec)./(magAvecs*magTrajVec);

            posC = find(cos_coneAng>coneAngPos);
            negC = find(cos_coneAng<-coneAngNeg);

            if ~isempty(posC)
                C(i,aa(posC)) = traj(i).vel * sqrt([traj(aa(posC)).startID]-traj(i).endID) ;%* constVel;
                M(i,aa(posC)) = abs(cos_trA(posC) - cos_coneAng(posC));
            end
            if ~isempty(negC)
                C(i,aa(negC)) = traj(i).vel * sqrt([traj(aa(negC)).startID]-traj(i).endID) ;%* constVel;
                M(i,aa(negC)) = abs(cos_trA(negC) - abs(cos_coneAng(negC)));
            end
        end
    end
    progressText(i/leIndx);
end

R = max(C(:));
D=createSparseDistanceMatrix(E,B,R); % dimentions - leIndx
radIndx = find(D<=C);
C(radIndx) = D(radIndx).*M(radIndx); % overwrite old cut-off matrix to generate cost matrix

[links12, links21] = lap(C,-1,0,1);
lnk = links12(1:leIndx);

lnkIndx = find(lnk<=leIndx);
leLnkIndx = length(lnkIndx);
group=struct('list',[]);
assocTracks = zeros(leIndx,1);
grNb = 0; 

progressText(0,'Second FOR-loop') % Create text
for i = 1:leLnkIndx
    k = lnkIndx(i);
    if assocTracks(k) == 0
        if assocTracks(lnk(k)) == 0
            grNb = grNb + 1;
            assocTracks(k) = grNb;
            assocTracks(lnk(k)) = grNb;
            group(grNb).list = [k lnk(k)];
            traj(k).next = lnk(k);
            traj(lnk(k)).prev = k;
            traj(k).g_nb = grNb;
            traj(lnk(k)).g_nb = grNb;
        else
            assocTracks(k) = assocTracks(lnk(k));
            group(assocTracks(lnk(k))).list = [k,group(assocTracks(lnk(k))).list];
            traj(k).next = lnk(k);
            traj(lnk(k)).prev = k;
            traj(k).g_nb = assocTracks(lnk(k));
        end
    else
        if assocTracks(lnk(k)) == 0
            assocTracks(lnk(k)) = assocTracks(k);
            group(assocTracks(k)).list = [group(assocTracks(k)).list,lnk(k)];
            traj(k).next = lnk(k);
            traj(lnk(k)).prev = k;
            traj(lnk(k)).g_nb = assocTracks(k);
        else
            % there are two groups to be linked together
            group(assocTracks(k)).list = [group(assocTracks(k)).list,group(assocTracks(link(k))).list];
            % update all members of group(assocTracks(link(k))).list in
            % traj
            group(assocTracks(link(k))).list = [];
    end
    progressText(i/leLnkIndx);
end
save([dirName(1:end-13),'\groups\group'],'group')

plotGroup(traj,group)

% changes so that you can handle abandoned groups