classdef LoggingManager < handle
    properties (Access=private)
        Snapshot = struct()
    end
    methods
        function captureSnapshot(obj,modelName)
            obj.Snapshot=struct();
            fields={'SignalLogging','SignalLoggingName','SaveOutput','OutputSaveName','SaveState','StateSaveName','DSMLogging','ReturnWorkspaceOutputs'};
            for k=1:numel(fields)
                try, obj.Snapshot.(fields{k})=get_param(modelName,fields{k}); catch, obj.Snapshot.(fields{k})=[]; end
            end
        end
        function plan=discoverLoggableSignals(~,modelName)
            lines=find_system(modelName,'FindAll','on','Type','line');
            plan=struct('Count',numel(lines),'Handles',lines,'Candidates',{{}});
            c={};
            for k=1:numel(lines)
                try
                    src=get_param(lines(k),'SrcPortHandle');
                    if ~isempty(src) && all(src~=-1)
                        c{end+1}=struct('Handle',lines(k),'Name',safeGet(lines(k),'Name',''),'SrcPortHandle',src); %#ok<AGROW>
                    end
                catch
                end
            end
            plan.Candidates=c;
        end
        function configure(~,modelName)
            set_param(modelName,'SignalLogging','on');
            set_param(modelName,'SignalLoggingName','logsout');
        end
        function restore(obj,modelName)
            if isempty(fieldnames(obj.Snapshot)), return; end
            names=fieldnames(obj.Snapshot);
            for k=1:numel(names)
                try, set_param(modelName,names{k},obj.Snapshot.(names{k})); catch, end
            end
        end
    end
end
function v=safeGet(o,n,d), try, v=get_param(o,n); catch, v=d; end, end
