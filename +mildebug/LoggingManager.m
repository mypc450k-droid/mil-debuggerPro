classdef LoggingManager < handle
    %LOGGINGMANAGER Configure broad signal capture and retain line-to-log mapping.
    properties (Access=private)
        Snapshot = struct()
        LineSnapshot = struct('Handle',{},'DataLogging',{},'Name',{}, ...
            'SrcPortHandle',{},'SrcDataLogging',{},'SrcDataLoggingNameMode',{},'SrcDataLoggingName',{})
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
            lines=find_system(modelName,'LookUnderMasks','all','FollowLinks','on', ...
                'FindAll','on','Type','line','SegmentType','trunk');
            for k=1:numel(lines)
                try
                    src=get_param(lines(k),'SrcPortHandle');
                    if isempty(src) || src==-1, src=[]; end
                    if isempty(src), continue; end
                    obj.LineSnapshot(end+1)=struct( ...
                        'Handle',lines(k), ...
                        'DataLogging',safeGet(lines(k),'DataLogging',0), ...
                        'Name',safeGet(lines(k),'Name',''), ...
                        'SrcPortHandle',src, ...
                        'SrcDataLogging',safeGet(src,'DataLogging',0), ...
                        'SrcDataLoggingNameMode',safeGet(src,'DataLoggingNameMode','SignalName'), ...
                        'SrcDataLoggingName',safeGet(src,'DataLoggingName','')); %#ok<AGROW>
                catch
                end
            end
        end

        function plan=discoverLoggableSignals(~,modelName)
            % A signal is represented by its source/output port. MathWorks
            % documents using trunk signal segments to find source ports and
            % enabling DataLogging on that source port. This avoids counting
            % branch segments as separate signals and avoids missing signals
            % whose branch segments have no SrcPortHandle.
            lines=find_system(modelName,'LookUnderMasks','all','FollowLinks','on', ...
                'FindAll','on','Type','line','SegmentType','trunk');
            plan=struct('Count',numel(lines),'Handles',lines,'Candidates',{{}},'Unsupported',{{}});
            c={}; u={};
            seenPorts=[];
            for k=1:numel(lines)
                try
                    src=get_param(lines(k),'SrcPortHandle');
                    if isempty(src) || any(double(src)==-1), continue; end
                    src=double(src(1));
                    if any(seenPorts==src), continue; end
                    seenPorts(end+1)=src; %#ok<AGROW>
                    c{end+1}=struct('Handle',lines(k),'Name',safeGet(lines(k),'Name',''), ...
                        'SrcPortHandle',src); %#ok<AGROW>
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

                    % Use the supported signal-logging API rather than
                    % depending only on raw DataLogging properties. This marks
                    % the signal represented by this source port for logging.
                    % The Dataset entry is mapped later by source block + port.
                    Simulink.sdi.markSignalForStreaming(src,'on');

                    % Keep DataLogging enabled as a compatibility fallback for
                    % models/block types that expose the instrumentation flag.
                    try, set_param(src,'DataLogging',1); catch, end
                    try, set_param(h,'DataLogging',1); catch, end

                    % Custom names are useful for diagnostics, but are NOT
                    % required for mapping. Dataset BlockPath + PortIndex is
                    % the authoritative identity after simulation.
                    try
                        set_param(src,'DataLoggingNameMode','Custom');
                        set_param(src,'DataLoggingName',logName);
                    catch
                    end

                    srcBlock=safeGet(src,'Parent','');
                    srcPort=safeGet(src,'PortNumber',k);
                    dstBlocks=collectDestBlocks(h);
                    if isempty(dstBlocks)
                        % For unusual line objects, fall back to the direct
                        % destination handle.
                        try
                            dst=get_param(h,'DstPortHandle');
                            for j=1:numel(dst)
                                if dst(j)~=-1
                                    dstBlocks{end+1}=safeGet(dst(j),'Parent',''); %#ok<AGROW>
                                end
                            end
                        catch
                        end
                    end
                    dstBlocks=unique(dstBlocks,'stable');

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
                src=obj.LineSnapshot(k).SrcPortHandle;
                try, if ~isempty(src), set_param(src,'DataLogging',obj.LineSnapshot(k).SrcDataLogging); end, catch, end
                try, if ~isempty(src), set_param(src,'DataLoggingNameMode',obj.LineSnapshot(k).SrcDataLoggingNameMode); end, catch, end
                try, if ~isempty(src), set_param(src,'DataLoggingName',obj.LineSnapshot(k).SrcDataLoggingName); end, catch, end
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

function dstBlocks=collectDestBlocks(lineHandle)
dstBlocks={};
try
    dst=get_param(lineHandle,'DstPortHandle');
    for k=1:numel(dst)
        if dst(k)~=-1
            p=safeGet(dst(k),'Parent','');
            if ~isempty(p), dstBlocks{end+1}=char(string(p)); end %#ok<AGROW>
        end
    end
catch
end
try
    kids=get_param(lineHandle,'LineChildren');
    for k=1:numel(kids)
        childDst=collectDestBlocks(kids(k));
        dstBlocks=[dstBlocks childDst]; %#ok<AGROW>
    end
catch
end
dstBlocks=unique(dstBlocks,'stable');
end
