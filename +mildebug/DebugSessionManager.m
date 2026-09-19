classdef DebugSessionManager < handle
    properties
        Session = struct()
    end
    methods
        function s=create(obj,modelName,inventory,compileResult,simResult,signalMap)
            if nargin<6, signalMap=struct([]); end
            s=struct('Version',mildebug.MILDebuggerProConfig.SessionVersion,'ModelName',modelName, ...
                'ModelPath',safePath(modelName),'CreatedAt',datetime('now'), ...
                'Inventory',inventory,'CompileResult',compileResult,'Simulation',simResult, ...
                'Valid',simResult.Success,'Signals',struct([]),'SignalMap',signalMap);
            s.Signals=obj.indexSignals(simResult.Output,signalMap);
            obj.Session=s;
        end
        function clear(obj)
            %CLEAR Discard cached data when the active model changes.
            obj.Session=struct();
        end
        function tf=isValid(obj,modelName)
            tf=isfield(obj.Session,'Valid') && obj.Session.Valid && strcmp(string(obj.Session.ModelName),string(modelName));
        end
        function tf=isSessionReady(obj)
            tf=isfield(obj.Session,'Valid') && obj.Session.Valid;
        end
    end
    methods (Static,Access=private)
        function items=indexSignals(out,signalMap)
            items=struct('Name',{},'Values',{},'BlockPath',{},'SourceBlockPath',{},'SourceBlockName',{},'SourcePortIndex',{},'SourcePortHandle',{},'SourceLineHandle',{},'DestinationBlocks',{},'RawLogName',{});
            if nargin<2, signalMap=struct([]); end
            if isempty(out), return; end
            try, ds=out.logsout; catch, ds=[]; end
            if isa(ds,'Simulink.SimulationData.Dataset')
                for k=1:ds.numElements
                    el=ds{k};
                    rawName=char(string(safeField(el,'Name','')));
                    meta=matchMeta(rawName,signalMap);
                    items(end+1)=struct( ...
                        'Name',displayName(rawName,meta,el), ...
                        'Values',safeField(el,'Values',[]), ...
                        'BlockPath',safeField(el,'PropagatedName',''), ...
                        'SourceBlockPath',safeField(meta,'SourceBlockPath',''), ...
                        'SourceBlockName',safeField(meta,'SourceBlockName',''), ...
                        'SourcePortIndex',safeField(meta,'SourcePortIndex',0), ...
                        'SourcePortHandle',safeField(meta,'SourcePortHandle',NaN), ...
                        'SourceLineHandle',safeField(meta,'SourceLineHandle',NaN), ...
                        'DestinationBlocks',{safeGetCell(meta,'DestinationBlocks',{})}, ...
                        'RawLogName',rawName); %#ok<AGROW>
                end
            end
        end
    end
end
function v=safeField(o,n,d), try, v=o.(n); catch, v=d; end, end
function meta=matchMeta(rawName,signalMap)
meta=struct();
if isempty(signalMap), return; end
for k=1:numel(signalMap)
    try
        if strcmp(char(string(signalMap(k).LogName)),rawName)
            meta=signalMap(k); return
        end
    catch
    end
end
end

function n=displayName(rawName,meta,el)
p=safeField(meta,'SourceBlockPath','');
if ~isempty(p)
    pi=safeField(meta,'SourcePortIndex',0);
    sn=safeField(meta,'SignalName','');
    if isempty(sn), sn=safeField(el,'Name',''); end
    n=sprintf('%s | OUT%d | %s',char(string(p)),double(pi),char(string(sn)));
else
    n=rawName;
end
end

function v=safeGetCell(s,n,d)
try
    if isstruct(s) && isfield(s,n)
        v=s.(n);
        if isempty(v), v=d; end
    else
        v=d;
    end
catch
    v=d;
end
end

function p=safePath(m), try, p=get_param(m,'FileName'); catch, p=''; end, end
