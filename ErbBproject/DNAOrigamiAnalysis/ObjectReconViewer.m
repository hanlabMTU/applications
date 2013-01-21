function handles = ObjectReconViewer(ReconObject, varargin)
% ObjectReconViewer creates an instance of an interactive GUI for examning the results of fourEdgeWrapepr or lineWrapper
%
% inputs: 
%       ReconObject  -> a cell array containing structures
%                       with a .counts field that will be displayed.
%
% outputs: 
%       handles  -> a structure that contains all of the object handles of
%                   the gui
%
% Last Update: 2013_01_21
% Jeffrey L Werbin
% Harvard Medical School

ip=inputParser;
ip.CaseSensitive=false;
ip.StructExpand=true;

ip.addRequired('ReconObject',@iscell);
%ip.addOptional('NA',1.49,@isscalar);
ip.parse(ReconObject,varargin{:});


% makes object for figure
f = figure;
a = axes;
a = get(f,'Children');
s = uicontrol('Style','slider','Min',1,'Max',numel(ReconObject), ...
              'Value',1,'Position',[10,10,80,30],'Callback',{@slideradjust});
t = uicontrol('Style','text','Position',[10,40,80,20],'String', 'N = 1');

%set state variables
state = 1; %starting position for display

%set gui data for object usage
silder = struct('a',a,'t',t,'i',state);
silder.data = ReconObject;
setappdata(s,'slider',silder);

%creates output structure;
handles = struct('figure', f,'axes',a,'slider',s, 'text',t);

%itialize plot
axes(a);
imshow(ReconObject{state}.counts,[0,8]);
colormap('hot');
end


function slideradjust(hObject, eventData, handles)
    %get data stored in slider
    st = getappdata(hObject,'slider'); 
    st.i = fix(get(hObject,'Value'));
    axes(st.a);
    imshow(st.data{st.i}.counts,[0,8]);
    colormap('hot');
    set(st.t,'String',['N = ',num2str(st.i,'%u')]);
    %update data stored in slider
    setappdata(hObject,'silder',st);
end