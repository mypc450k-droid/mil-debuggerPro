classdef ModelManager < handle
    %MODELMANAGER Resolve the Simulink model that is actually active in MATLAB.
    %
    % The previous implementation used find_system(..., Type, block_diagram)
    % and selected the first result. That is not an "active model" query:
    % MATLAB can have several models loaded, so the first result may be an
    % unrelated model or library.
    %
    % Detection priority:
    %   1) Current Simulink system (gcs)
    %   2) Current Simulink block (gcb) -> bdroot
    %   3) MATLAB's current block-diagram root, when available
    %   4) A loaded, non-library model only as a last-resort fallback
    %
    % Never use the first arbitrary block diagram as the active model.

    methods
        function modelName = detectActiveModel(~)
            modelName = '';

            % 1. The system currently active in the Simulink editor.
            candidate = '';
            try
                candidate = gcs;
            catch
            end
            candidate = localRoot(candidate);
            if localIsUsableModel(candidate)
                modelName = candidate;
                return
            end

            % 2. The block currently selected/active in Simulink.
            candidate = '';
            try
                candidate = gcb;
            catch
            end
            candidate = localRoot(candidate);
            if localIsUsableModel(candidate)
                modelName = candidate;
                return
            end

            % 3. Ask the Simulink root for the current system if supported.
            candidate = '';
            try
                currentSystem = get_param(0,'CurrentSystem');
                candidate = localRoot(currentSystem);
            catch
            end
            if localIsUsableModel(candidate)
                modelName = candidate;
                return
            end

            % 4. Last-resort fallback. Do NOT assume the first block diagram
            % is active. Only return a single usable non-library model when
            % MATLAB has exactly one such candidate.
            candidates = {};
            try
                roots = find_system(0,'SearchDepth',0,'Type','block_diagram');
                for k = 1:numel(roots)
                    root = localRoot(roots{k});
                    if localIsUsableModel(root)
                        if ~any(strcmp(candidates,root))
                            candidates{end+1} = root; %#ok<AGROW>
                        end
                    end
                end
            catch
            end

            if numel(candidates) == 1
                modelName = candidates{1};
            end
        end

        function info = detectActiveModelInfo(obj)
            % Return diagnostics so the UI can explain why a model was chosen.
            info = struct('Model','', ...
                          'Source','', ...
                          'LoadedModels',{{}}, ...
                          'Message','');

            info.Model = obj.detectActiveModel();

            try
                roots = find_system(0,'SearchDepth',0,'Type','block_diagram');
                loaded = {};
                for k = 1:numel(roots)
                    root = localRoot(roots{k});
                    if localIsUsableModel(root) && ~any(strcmp(loaded,root))
                        loaded{end+1} = root; %#ok<AGROW>
                    end
                end
                info.LoadedModels = loaded;
            catch
            end

            if isempty(info.Model)
                info.Source = 'none';
                if isempty(info.LoadedModels)
                    info.Message = 'No active Simulink model detected. Open the model in the Simulink editor.';
                elseif numel(info.LoadedModels) > 1
                    info.Message = sprintf(['Multiple Simulink models are loaded (%d), but MATLAB did not report ' ...
                        'which one is active. Click inside the intended model window and press Refresh.'], ...
                        numel(info.LoadedModels));
                else
                    info.Message = 'A model is loaded, but MATLAB did not expose it as the active Simulink editor model.';
                end
            else
                info.Source = 'Simulink editor context';
                info.Message = sprintf('Using active Simulink model: %s',info.Model);
            end
        end

        function ensureLoaded(~,modelName)
            if isempty(modelName)
                error('MILDebuggerPro:Model','Model name is empty.');
            end
            if ~bdIsLoaded(modelName)
                load_system(modelName);
            end
        end

        function blockPath = getSelectedBlock(~,modelName)
            blockPath = '';
            if isempty(modelName) || ~bdIsLoaded(modelName)
                return
            end
            try
                h = get_param(modelName,'Handle');
                selected = find_system(h,'LookUnderMasks','all', ...
                    'FollowLinks','on','Selected','on');
                selected = selected(~strcmp(selected,modelName));
                if ~isempty(selected)
                    blockPath = selected{1};
                end
            catch
            end
        end

        function navigateToBlock(~,blockPath)
            if isempty(blockPath)
                return
            end
            try, load_system(bdroot(blockPath)); catch, end
            try, open_system(get_param(blockPath,'Parent')); catch, end
            try, set_param(blockPath,'Selected','on'); catch, end
            try, hilite_system(blockPath,'find'); catch, end
        end
    end
end

function root = localRoot(systemPath)
    root = '';
    if isempty(systemPath)
        return
    end
    try
        root = char(string(bdroot(char(systemPath))));
    catch
        try
            root = char(string(systemPath));
        catch
            root = '';
        end
    end
end

function tf = localIsUsableModel(root)
    tf = false;
    if isempty(root)
        return
    end
    try
        if ~bdIsLoaded(root)
            return
        end
    catch
        return
    end

    % Simulink itself is not a model.
    if strcmp(root,'Simulink')
        return
    end

    % Libraries are loaded block diagrams but are not executable MIL models.
    try
        if bdIsLibrary(root)
            return
        end
    catch
        % If bdIsLibrary is unavailable, continue with the other checks.
    end

    % A real model root must expose a file name or be an in-memory model.
    % Avoid rejecting unsaved models, because they are valid MIL targets.
    tf = true;
end
