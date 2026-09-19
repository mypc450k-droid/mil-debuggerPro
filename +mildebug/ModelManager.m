classdef ModelManager < handle
    methods
        function modelName = detectActiveModel(~)
            modelName = '';
            try
                roots = find_system('SearchDepth',0,'Type','block_diagram');
                roots = roots(~strcmp(roots,'Simulink'));
                if ~isempty(roots), modelName = roots{1}; end
            catch
                try, modelName = bdroot; catch, modelName = ''; end
            end
        end
        function ensureLoaded(~,modelName)
            if ~bdIsLoaded(modelName), load_system(modelName); end
        end
        function blockPath = getSelectedBlock(~,modelName)
            blockPath = '';
            try
                h = get_param(modelName,'Handle');
                selected = find_system(h,'LookUnderMasks','all','FollowLinks','on','Selected','on');
                selected = selected(~strcmp(selected,modelName));
                if ~isempty(selected), blockPath = selected{1}; end
            catch
            end
        end
        function navigateToBlock(~,blockPath)
            try, load_system(bdroot(blockPath)); catch, end
            try, open_system(get_param(blockPath,'Parent')); catch, end
            try, set_param(blockPath,'Selected','on'); catch, end
            try, hilite_system(blockPath,'find'); catch, end
        end
    end
end
