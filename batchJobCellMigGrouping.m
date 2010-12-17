% browse into the folder that contains all the subfolders and execute this
% script.
clear persistent checkVec;

fid = fopen('fn_E_c.txt');
if fid<3
        [filename, pathname] = uigetfile({'*.*'}, ...
        'Select file containing stiffness information');
    
    if ~ischar(filename) || ~ischar(pathname)
        return;
    end
    fid = fopen(filename);
end

mydata = textscan(fid, '%s %f %s %s','Delimiter','=;, ','MultipleDelimsAsOne',1);
numEntries=size(mydata{1},1);
fclose(fid);

checkVec=strcmp(mydata{4}(:),'');
if sum(checkVec)>0
    % Then these are control cells:
    mydata{4}(checkVec)={'control'};
    fid = fopen('fn_E_c.txt','w');
    for row=1:numEntries
        % print it to the file for later use:
        fprintf(fid, '%s= %s; %s; %s \n', char(mydata{1}(row)), num2str(mydata{2}(row)), char(mydata{3}(row)), char(mydata{4}(row)));
    end
    fclose(fid);
end

% set the folder names:
A = dir();
sizeA = size(A,1);
for k=1:sizeA
    checkVec(k)=(~A(k).isdir || strcmp(A(k).name,'.') || strcmp(A(k).name,'..'));
end
A(checkVec)=[];
% give the list of all valid folders with ID:
sizeA = size(A,1);
for k=1:sizeA
    display(['Folder: ',A(k).name,' = No. ',num2str(k,'%02.0f')]);
end

toDoList=input(['There are: ',num2str(sizeA),' folders. Which do you want to analyze [all]: ']);

if isempty(toDoList)
    toDoList=1:sizeA;
end

try
    load('xGroupedData.mat');
catch exception
    display('Couldnt find grouped data assume that it is the first data set');
    groupData=[];
end

if toDoList==-1
    cellMig_part_3_groupData(groupData,A(1).name,0,0,1);
    break;
end


for i=toDoList
    folderName = A(i,1).name;
       
    checkVec=strcmp(folderName, mydata{1});
    if sum(checkVec)~=1
        display(['Somthing wrong with folder: ',folderName],'! skiped it!');
    else        
        display(['Working on folder: ',folderName]);        
        % execute the migration script
        yModu_kPa = mydata{2}(checkVec);
        cc        = mydata{3}(checkVec);
        cond      = mydata{4}(checkVec);
        
        groupData = cellMig_part_3_groupData(groupData,folderName,yModu_kPa,cc,cond);
    end
    if i~=toDoList(end)
        close all;
    end
end
save('xGroupedData.mat','groupData','-v7.3');