classdef LoggingManager < handle
    %LOGGINGMANAGER Configure broad signal capture and retain line-to-log mapping.
    properties (Access=private)
        Snapshot = struct()
        LineSnapshot = struct('Handle',{},'DataLogging',{},'Name',{}, ...
            'DataLoggingNameMode',{},'DataLoggingName',{})
        CaptureMap = struct('LineHandle',{},'LogName',{},'OriginalName',{}, ...
            'SrcPortHandle',{},'SrcBlockPath',{},'SrcPortNumber',{}, ...
            'DstBlockPaths',{})
        Coverage = struct('TotalLines',0,'Requested',0,'Enabled',0,'Failed',0,'Failures',{{}})
    end
    methods
        function captureSnapshot(obj,modelName)
            obj.Snapshot=struct();
            fields={'SignalLogging','SignalLoggingName','SaveOutput','OutputSaveName', ...
                'SaveState','StateSaveName','DSMLogging','ReturnWorkspaceOutputs'};
            for k=1:numel(fields)
                try, obj.Snapshot.(fields{k})=get_param(modelName,fields{k}); catch, obj.Snapshot.(fields{k})=[]; end
            end
            obj.LineSnapshot=obj.LineSnapshot([]);
            obj.CaptureMap=obj.CaptureMap([]);
            lines=find_system(modelName,'FindAll','on','Type','line');
            for k=1:numel(lines)
                try
                    obj.LineSnapshot(end+1)=struct( ...
                        'Handle',lines(k), ...
                        'DataLogging',get_param(lines(k),'DataLogging'), ...
                        'Name',safeGet(lines(k),'Name',''), ...
                        'DataLoggingNameMode',safeGet(lines(k),'DataLoggingNameMode','SignalName'), ...
                        'DataLoggingName',safeGet(lines(k),'DataLoggingName','')); %#ok<AGROW>
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
                        c{end+1}=struct('Handle',lines(k),'Name',safeGet(lines(k),'Name',''), ...
                            'SrcPortHandle',src); %#ok<AGROW>
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
            obj.CaptureMap=obj.CaptureMap([]);

            for k=1:numel(plan.Candidates)
                c=plan.Candidates{k};
                h=c.Handle;
                try
                    src=c.SrcPortHandle(1);
                    logName=sprintf('MILDP_S%06d',k);
                    set_param(h,'DataLogging',1);
                    % Give every captured line a unique logging name so the
                    % post-run dataset can be mapped back to this exact line.
                    try
                        set_param(src,'DataLoggingNameMode','Custom');
                        set_param(src,'DataLoggingName',logName);
                    catch
                        % Some port types do not expose custom naming. The
                        % line remains logged and is still recoverable by path.
                    end

                    srcBlock=safeGet(src,'Parent','');
                    srcPort=safeGet(src,'PortNumber',k);
                    dstBlocks={};
                    try
                        dst=get_param(h,'DstPortHandle');
                        for j=1:numel(dst)
                            if dst(j)~=-1
                                dstBlocks{end+1}=safeGet(dst(j),'Parent',''); %#ok<AGROW>
                            end
                        end
                    catch
                    end

                    obj.CaptureMap(end+1)=struct( ...
                        'LineHandle',h,'LogName',logName, ...
                        'OriginalName',c.Name,'SrcPortHandle',src, ...
                        'SrcBlockPath',char(string(srcBlock)), ...
                        'SrcPortNumber',double(srcPort), ...
                        'DstBlockPaths',{dstBlocks}); %#ok<AGROW>
                    obj.Coverage.Enabled=obj.Coverage.Enabled+1;
                catch ME
                    obj.Coverage.Failed=obj.Coverage.Failed+1;
                    obj.Coverage.Failures{end+1}=struct('Handle',h,'Reason',ME.message); %#ok<AGROW>
                end
            end
        end

        function m=getCaptureMap(obj)
            m=obj.CaptureMap;
        end

        function coverage=getCoverage(obj)
            coverage=obj.Coverage;
        end

        function restore(obj,modelName)
            for k=1:numel(obj.LineSnapshot)
                h=obj.LineSnapshot(k).Handle;
                try, set_param(h,'DataLogging',obj.LineSnapshot(k).DataLogging); catch, end
                try, set_param(h,'DataLoggingNameMode',obj.LineSnapshot(k).DataLoggingNameMode); catch, end
                try, set_param(h,'DataLoggingName',obj.LineSnapshot(k).DataLoggingName); catch, end
            end
            if isempty(fieldnames(obj.Snapshot)), return; end
            names=fieldnames(obj.Snapshot);
            for k=1:numel(names)
                try, set_param(modelName,names{k},obj.Snapshot.(names{k})); catch, end
            end
        end
    end
end

function v=safeGet(o,n,d)
try
    v=get_param(o,n);
catch
    v=d;
end
end
