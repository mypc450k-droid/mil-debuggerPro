classdef DebugSessionManager < handle
    properties
        Session = struct()
    end
    methods
        function s=create(obj,modelName,inventory,compileResult,simResult,captureMap)
            if nargin<6, captureMap=struct([]); end
            s=struct('Version',mildebug.MILDebuggerProConfig.SessionVersion,'ModelName',modelName, ...
                'ModelPath',safePath(modelName),'CreatedAt',datetime('now'), ...
                'Inventory',inventory,'CompileResult',compileResult,'Simulation',simResult, ...
                'Valid',simResult.Success,'Signals',struct([]));
            s.Signals=obj.indexSignals(simResult.Output,captureMap);
            obj.Session=s;
        end

        function clear(obj)
            obj.Session=struct();
        end

        function tf=isValid(obj,modelName)
            tf=isfield(obj.Session,'Valid') && obj.Session.Valid && ...
                strcmp(string(obj.Session.ModelName),string(modelName));
        end

        function tf=isSessionReady(obj)
            tf=isfield(obj.Session,'Valid') && obj.Session.Valid;
        end
    end

    methods (Static,Access=private)
        function items=indexSignals(out,captureMap)
            items=struct('Name',{},'Values',{},'BlockPath',{}, ...
                'OriginalName',{},'LineHandle',{},'SrcBlockPath',{}, ...
                'SrcPortNumber',{},'DstBlockPaths',{},'LogName',{});
            if isempty(out), return; end
            try, ds=out.logsout; catch, ds=[]; end
            if ~isa(ds,'Simulink.SimulationData.Dataset'), return; end

            for k=1:ds.numElements
                el=ds{k};
                logName=char(string(safeField(el,'Name','')));
                blockPath=char(string(safeField(el,'PropagatedName','')));
                meta=struct();
                if ~isempty(captureMap)
                    hit=find(strcmp({captureMap.LogName},logName),1);
                    if ~isempty(hit)
                        meta=captureMap(hit);
                    else
                        % Fallback when a block/port rejected custom logging
                        % naming and the dataset retained propagated naming.
                        hit=find(strcmp({captureMap.OriginalName},logName),1);
                        if ~isempty(hit), meta=captureMap(hit); end
                    end
                end

                if isempty(fieldnames(meta))
                    items(end+1)=struct('Name',logName,'Values',safeField(el,'Values',[]), ...
                        'BlockPath',blockPath,'OriginalName',logName,'LineHandle',[], ...
                        'SrcBlockPath',blockPath,'SrcPortNumber',[], ...
                        'DstBlockPaths',{{}},'LogName',logName); %#ok<AGROW>
                else
                    items(end+1)=struct('Name',logName,'Values',safeField(el,'Values',[]), ...
                        'BlockPath',blockPath,'OriginalName',meta.OriginalName, ...
                        'LineHandle',meta.LineHandle,'SrcBlockPath',meta.SrcBlockPath, ...
                        'SrcPortNumber',meta.SrcPortNumber, ...
                        'DstBlockPaths',{meta.DstBlockPaths},'LogName',meta.LogName); %#ok<AGROW>
                end
            end
        end
    end
end

function v=safeField(o,n,d)
try, v=o.(n); catch, v=d; end
end

function p=safePath(m)
try, p=get_param(m,'FileName'); catch, p=''; end
end
