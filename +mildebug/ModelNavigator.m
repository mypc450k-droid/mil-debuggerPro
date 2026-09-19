classdef ModelNavigator < handle
    methods
        function goToBlock(~,blockPath)
            mildebug.ModelManager().navigateToBlock(blockPath);
        end
    end
end
