function frameIntersections = runFunction(xCoords,yCoords,startFrames,endFrames,...
    segStartFrames,segEndFrames,maskSub,minTrackLength)

frameIntersections = parcellfun_progress(@(xCoords,yCoords,startFrames,...
    endFrames,segStartFrames,segEndFrames) ...
    trackPartitionInner(xCoords,yCoords,startFrames,endFrames,...
    segStartFrames,segEndFrames,maskSub,minTrackLength),...
    xCoords,yCoords,startFrames,endFrames,segStartFrames,segEndFrames,...
    'UniformOutput',false);

end

