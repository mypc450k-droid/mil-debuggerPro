classdef LoggingManager < handle
    properties (Access=private)
        Snapshot = struct()
        LineSnapshot = struct('Handle',{},'DataLogging',{})
        Coverage = struct('TotalLines',0,'Requested',0,'Enabled',0,'Failed',0,'Failures',{{}})
    end
    methods
        function captureSnapshot(obj,modelName)
            obj.Snapshot=struct();
            fields={'SignalLogging','SignalLoggingName','SaveOutput','OutputSaveName','SaveState','StateSaveName','DSMLogging','ReturnWorkspaceOutputs'};
            for k=1:numel(fields)
                try, obj.Snapshot.(fields{k})=get_param(modelName,fields{k}); catch, obj.Snapshot.(fields{k})=[]; end
            end
            obj.LineSnapshot=obj.LineSnapshot([]);
            lines=find_system(modelName,'FindAll','on','Type','line');
            for k=1:numel(lines)
                try
                    obj.LineSnapshot(end+1)=struct('Handle',lines(k),'DataLogging',get_param(lines(k),'DataLogging')); %#ok<AGROW>
                catch
                end
            end
        end
        function plan=discoverLoggableSignals(~,modelName)
            lines=find_system(modelName,'FindAll','on','Type','line');
            plan=struct('Count',numel(lines),'Handles',lines,'Candidates',{{}},'Unsupported',{{}});
            c={}; u={};
            for k=1:numel(lines)
                try
                    src=get_param(lines(k),'SrcPortHandle');
                    if ~isempty(src) && all(src~=-1)
                        c{end+1}=struct('Handle',lines(k),'Name',safeGet(lines(k),'Name',''),'SrcPortHandle',src); %#ok<AGROW>
                    end
                catch ME
                    u{end+1}=struct('Handle',lines(k),'Reason',ME.message); %#ok<AGROW>
                end
            end
            plan.Candidates=c; plan.Unsupported=u;
        end
        function plan=configure(obj,modelName)
            set_param(modelName,'SignalLogging','on');
            set_param(modelName,'SignalLoggingName','logsout');
            plan=obj.discoverLoggableSignals(modelName);
            obj.Coverage.TotalLines=plan.Count;
            obj.Coverage.Requested=numel(plan.Candidates);
            obj.Coverage.Enabled=0;
            obj.Coverage.Failed=0;
            obj.Coverage.Failures={};
            for k=1:numel(plan.Candidates)
                h=plan.Candidates{k}.Handle;
                try
                    set_param(h,'DataLogging',1);
                    obj.Coverage.Enabled=obj.Coverage.Enabled+1;
                catch ME
                    obj.Coverage.Failed=obj.Coverage.Failed+1;
                    obj.Coverage.Failures{end+1}=struct('Handle',h,'Reason',ME.message); %#ok<AGROW>
                end
            end
        end
        function coverage=getCoverage(obj)
            coverage=obj.Coverage;
        end
        function restore(obj,modelName)
            for k=1:numel(obj.LineSnapshot)
                try, set_param(obj.LineSnapshot(k).Handle,'DataLogging',obj.LineSnapshot(k).DataLogging); catch, end
            end
            if isempty(fieldnames(obj.Snapshot)), return; end
            names=fieldnames(obj.Snapshot);
            for k=1:numel(names)
                try, set_param(modelName,names{k},obj.Snapshot.(names{k})); catch, end
            end
        end
    end
end
function v=safeGet(o,n,d), try, v=get_param(o,n); catch, v=d; end, end
