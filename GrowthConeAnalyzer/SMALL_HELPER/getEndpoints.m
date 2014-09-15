
function [coords,vect] = getEndpoints(pixIdx,size,checkSingletons,getVector)
% checkSingletons input added for maintaining functionality with
% skel2Graph4OutGrowthMetric - here need to just get coordinates of
%
% getVector: logical 1 or 0 if 1 this will get the local vector from
% towards the endpoint: need to determine if 
if nargin<3 
    checkSingletons = 0; 
end 

if nargin<4 
    getVector = 0; 
end 
     
singleFlag = 0 ;

if checkSingletons == 1
    if length(pixIdx) == 1
        singleFlag = 1;
        
    end
% singletons as well even though not technically an end point. 
end

if singleFlag == 1
    
    % it is a singtlton
    [ye,xe]  = ind2sub(size,pixIdx);
    vect = [nan nan]; 
else
    
    %
    maskC = zeros(size);
    maskC(pixIdx)=1;
    sumKernel = [1 1 1];
    % find endpoints of the floating candidates to attach (note in the
    % future might want to prune so that the closest end to the
    % body is the only one to be re-attatched: this will avoid double connections)
    endpoints = double((maskC.* (conv2(sumKernel, sumKernel', padarrayXT(maskC, [1 1]), 'valid')-1))==1);
    [ye,xe] = find(endpoints~=0);
    
    
    if getVector == 1
        for iPoint = 1:2
            dist = bwdistgeodesic(logical(maskC),xe(iPoint),ye(iPoint));
            % get the index of the 3rd pixel from the end point
            [y3Back,x3Back] = ind2sub(size,find(dist == 3));
            % calculate the vector in the direction toward the endpoint.
            
            
            vectX = (xe(iPoint)-x3Back);
            vectY = (ye(iPoint)-y3Back);
            
            distC = sqrt(vectX^2 + vectY^2);
             vect(iPoint,1) = vectX/distC; % make it a unit vector 
            vect(iPoint,2) = vectY/distC;
        end
       
    end  
    
    sanityCheck = 0; 
if sanityCheck == 1
    figure
    imshow(maskC); 
    
    hold on 
    
    arrayfun(@(i) quiver(xe(i),ye(i),vect(i,1),vect(i,2),10),1:2); 
end 
    
    
    
    
end 
    coords(:,1) = xe;
    coords(:,2) = ye;
    if getVector == 1;
       coords = [coords vect] ;% add the vector coordinates 
    end
end



