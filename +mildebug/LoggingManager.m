classdef LoggingManager < handle
    %LOGGINGMANAGER Capture signal logging with stable block/port metadata.
    %
    % The logger instruments source output ports rather than relying only on
    % line DataLogging. This gives the post-run debugger a stable association
    % between each logged signal and the block output port that produced it.

    properties (Access=private)
        Snapshot = struct()
        LineSnapshot = struct('Handle',{},'DataLogging',{})
        PortSnapshot = struct('Handle',{},'DataLogging',{}, ...
            'DataLoggingNameMode',{},'DataLoggingName',{})
        SignalMap = struct('Key',{},'LogName',{},'SourcePortHandle',{}, ...
            'SourceBlockPath',{},'SourceBlockName',{},'SourcePortIndex',{}, ...
            'SourceLineHandle',{},'DestinationBlocks',{},'SignalName',{})
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
            lines=find_system(modelName,'FindAll','on','Type','line');
            for k=1:numel(lines)
                try
                    obj.LineSnapshot(end+1)=struct('Handle',lines(k), ...
                        'DataLogging',get_param(lines(k),'DataLogging')); %#ok<AGROW>
                catch
                end
            end
            obj.PortSnapshot=obj.PortSnapshot([]);
            obj.SignalMap=obj.SignalMap([]);
        end

        function plan=discoverLoggableSignals(obj,modelName)
            lines=find_system(modelName,'FindAll','on','Type','line');
            plan=struct('Count',numel(lines),'Handles',lines,'Candidates',{{}},'Unsupported',{{}});
            c={}; u={}; seen=[];
            for k=1:numel(lines)
                h=lines(k);
                try
                    src=get_param(h,'SrcPortHandle');
                    if isempty(src) || any(src==-1), continue; end
                    src=src(1);
                    if any(seen==src), continue; end
                    seen(end+1)=src; %#ok<AGROW>

                    srcBlock=get_param(src,'Parent');
                    srcPortIndex=safePortIndex(src);
                    srcName=safeGet(src,'Name','');
                    lineName=safeGet(h,'Name','');
                    dest=get_param(h,'DstPortHandle');
                    destBlocks=destinationBlocks(dest);

                    key=sprintf('P%010.0f',src);
                    logName=sprintf('MILDBG__%s',key);

                    c{end+1}=struct('Handle',h,'LineHandle',h, ...
                        'SrcPortHandle',src,'SourceBlockPath',char(string(srcBlock)), ...
                        'SourceBlockName',char(string(safeGet(srcBlock,'Name',''))), ...
                        'SourcePortIndex',srcPortIndex,'SignalName',char(string(srcName)), ...
                        'DestinationBlocks',{destBlocks},'Key',key,'LogName',logName); %#ok<AGROW>
                catch ME
                    u{end+1}=struct('Handle',h,'Reason',ME.message); %#ok<AGROW>
                end
            end
            plan.Candidates=c;
            plan.Unsupported=u;
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
            obj.SignalMap=obj.SignalMap([]);

            for k=1:numel(plan.Candidates)
                c=plan.Candidates{k};
                src=c.SrcPortHandle;
                try
                    obj.savePortSnapshot(src);
                    set_param(src,'DataLogging','on');
                    set_param(src,'DataLoggingNameMode','Custom');
                    set_param(src,'DataLoggingName',c.LogName);

                    obj.Coverage.Enabled=obj.Coverage.Enabled+1;
                    obj.SignalMap(end+1)=struct( ...
                        'Key',c.Key,'LogName',c.LogName, ...
                        'SourcePortHandle',src, ...
                        'SourceBlockPath',c.SourceBlockPath, ...
                        'SourceBlockName',c.SourceBlockName, ...
                        'SourcePortIndex',c.SourcePortIndex, ...
                        'SourceLineHandle',c.LineHandle, ...
                        'DestinationBlocks',{c.DestinationBlocks}, ...
                        'SignalName',c.SignalName); %#ok<AGROW>
                catch ME
                    obj.Coverage.Failed=obj.Coverage.Failed+1;
                    obj.Coverage.Failures{end+1}=struct('Handle',src,'Reason',ME.message); %#ok<AGROW>
                end
            end
        end

        function map=getSignalMap(obj)
            map=obj.SignalMap;
        end

        function coverage=getCoverage(obj)
            coverage=obj.Coverage;
        end

        function restore(obj,modelName)
            for k=1:numel(obj.PortSnapshot)
                p=obj.PortSnapshot(k);
                try, set_param(p.Handle,'DataLogging',p.DataLogging); catch, end
                try, set_param(p.Handle,'DataLoggingNameMode',p.DataLoggingNameMode); catch, end
                try, set_param(p.Handle,'DataLoggingName',p.DataLoggingName); catch, end
            end
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

    methods (Access=private)
        function savePortSnapshot(obj,src)
            if any(arrayfun(@(x)x.Handle==src,obj.PortSnapshot)), return; end
            obj.PortSnapshot(end+1)=struct( ...
                'Handle',src, ...
                'DataLogging',safeGet(src,'DataLogging','off'), ...
                'DataLoggingNameMode',safeGet(src,'DataLoggingNameMode','SignalName'), ...
                'DataLoggingName',safeGet(src,'DataLoggingName','')); %#ok<AGROW>
        end
    end
end

function v=safeGet(o,n,d)
try, v=get_param(o,n); catch, v=d; end
end

function idx=safePortIndex(port)
idx=0;
try
    idx=double(get_param(port,'PortNumber'));
catch
end
end

function blocks=destinationBlocks(dst)
blocks={};
if isempty(dst), return; end
for k=1:numel(dst)
    try
        blocks{end+1}=char(string(get_param(dst(k),'Parent'))); %#ok<AGROW>
    catch
    end
end
blocks=unique(blocks,'stable');
end
