function fsmCentercb_autoContrast
% fsmCentercb_autoContrast
%
% This function is a callback for the "More Tools" menu in the figure
% opened by the pushImShow_Callback function of fsmCenter
%
% INPUT   img  Image to be stretched in intensity
%              This is only for display purposes, the actual image is not modified.
%
% OUTPUT  none
%
% REMARK  This function automatically enhances the contrast of the displayed image
%
% Aaron Ponti, 11/18/2003

% Retrieve image from figure
children=get(gca,'Children');
if length(children)>1
    children=children(end); % We take the last one, which is the image (first in last out)
end
img=get(children,'CData');

% Display stretched image
set(gca,'CLimMode','manual');
set(gca,'CLim',[min(img(:)) max(img(:))]);
refresh(gcf);
