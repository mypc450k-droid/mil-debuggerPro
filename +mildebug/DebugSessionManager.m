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
                'SrcPortNumber',{},'DstBlockPaths',{},'LogName',{},'LoggedBlockPath',{},'LoggedPortIndex',{});
            if isempty(out), return; end
            try, ds=out.logsout; catch, ds=[]; end
            if ~isa(ds,'Simulink.SimulationData.Dataset'), return; end

            for k=1:ds.numElements
                el=ds{k};
                logName=char(string(safeField(el,'Name','')));
                blockPath=char(string(safeField(el,'PropagatedName','')));
                loggedBlockPath=extractLoggedBlockPath(el);
                if isempty(loggedBlockPath), loggedBlockPath=blockPath; end
                loggedPortIndex=safeField(el,'PortIndex',[]);
                meta=struct();

                if ~isempty(captureMap)
                    % Primary identity: actual simulation Dataset BlockPath +
                    % output port index. This survives custom-name rejection.
                    hit=[];
                    if ~isempty(loggedBlockPath) && ~isempty(loggedPortIndex)
                        for q=1:numel(captureMap)
                            if strcmp(char(string(captureMap(q).SrcBlockPath)),loggedBlockPath) && ...
                                    isequal(double(captureMap(q).SrcPortNumber),double(loggedPortIndex))
                                hit=q; break
                            end
                        end
                    end

                    % Secondary identity: generated logging name.
                    if isempty(hit)
                        hit=find(strcmp({captureMap.LogName},logName),1);
                    end

                    % Last fallback: original signal label.
                    if isempty(hit)
                        hit=find(strcmp({captureMap.OriginalName},logName),1);
                    end
                    if ~isempty(hit), meta=captureMap(hit); end
                end

                if isempty(fieldnames(meta))
                    items(end+1)=struct('Name',logName,'Values',safeField(el,'Values',[]), ...
                        'BlockPath',blockPath,'OriginalName',logName,'LineHandle',[], ...
                        'SrcBlockPath',loggedBlockPath,'SrcPortNumber',loggedPortIndex, ...
                        'DstBlockPaths',{{}},'LogName',logName, ...
                        'LoggedBlockPath',loggedBlockPath,'LoggedPortIndex',loggedPortIndex); %#ok<AGROW>
                else
                    items(end+1)=struct('Name',logName,'Values',safeField(el,'Values',[]), ...
                        'BlockPath',blockPath,'OriginalName',meta.OriginalName, ...
                        'LineHandle',meta.LineHandle,'SrcBlockPath',meta.SrcBlockPath, ...
                        'SrcPortNumber',meta.SrcPortNumber, ...
                        'DstBlockPaths',{meta.DstBlockPaths},'LogName',meta.LogName, ...
                        'LoggedBlockPath',loggedBlockPath,'LoggedPortIndex',loggedPortIndex); %#ok<AGROW>
                end
            end
        end
    end
end

function p=extractLoggedBlockPath(el)
p='';
try
    bp=el.BlockPath;
    if isa(bp,'Simulink.SimulationData.BlockPath')
        cells=bp.convertToCell();
        if ~isempty(cells)
            p=char(string(cells{end}));
        end
    elseif isa(bp,'Simulink.BlockPath')
        cells=bp.convertToCell();
        if ~isempty(cells)
            p=char(string(cells{end}));
        end
    end
catch
    try, p=char(string(el.BlockPath)); catch, p=''; end
end
end

function v=safeField(o,n,d)
try, v=o.(n); catch, v=d; end
end

function p=safePath(m)
try, p=get_param(m,'FileName'); catch, p=''; end
end
