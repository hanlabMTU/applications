function mainDir=cdBiodata(option)
%change to biodata/home if not in a biodata-dir/home-dir already
%
%SYNOPSIS   mainDir=cdBiodata(option)
%
%INPUT      option: 0 always cd biodata
%                   1 if in a biodata directory: don't do anything
%                   2 if in a biodata directory and if there are r3d-files: move up one level
%
%OUTPUT     BIODATA - directory
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

mainDir=getenv('BIODATA');
if isempty(mainDir)
    mainDir=getenv('HOME');
    if isempty(mainDir)
        h=errordlg('Set environment variables HOME and BIODATA for your matlab home directory and the directory where you store the movies, respectively');
        uiwait(h)
        return
    end
end

oldDir=pwd;

%if there is no option: switch to biodata-main if not already in some
%biodata-subdirectory
if nargin==0|isempty(option)
    option=1;
end

switch option
    case 0
        cd(mainDir);
    case 1
        if isempty(findstr(lower(mainDir),lower(oldDir))) %else we're in a good directory...
            cd(mainDir);
        elseif length(mainDir)>length(oldDir) %...or we are in a parent
            cd(mainDir);
        end 
    case 2
        if isempty(findstr(lower(mainDir),lower(oldDir)))
            cd(mainDir);
        else
            if ~isempty(dir('*.r3*'))
                cd .. %if in a project dir: move up one file to allow easier switching between projects
            end
        end 
end