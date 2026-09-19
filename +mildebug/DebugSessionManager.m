classdef DebugSessionManager < handle
    properties
        Session = struct()
    end
    methods
        function s=create(obj,modelName,inventory,compileResult,simResult)
            s=struct('Version',MILDebuggerProConfig.SessionVersion,'ModelName',modelName, ...
                'ModelPath',safePath(modelName),'CreatedAt',datetime('now'), ...
                'Inventory',inventory,'CompileResult',compileResult,'Simulation',simResult, ...
                'Valid',simResult.Success,'Signals',struct([]));
            s.Signals=obj.indexSignals(simResult.Output);
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
        function items=indexSignals(out)
            items=struct('Name',{},'Values',{},'BlockPath',{});
            if isempty(out), return; end
            try, ds=out.logsout; catch, ds=[]; end
            if isa(ds,'Simulink.SimulationData.Dataset')
                for k=1:ds.numElements
                    el=ds{k};
                    items(end+1)=struct('Name',safeField(el,'Name',''), ...
                        'Values',safeField(el,'Values',[]),'BlockPath',safeField(el,'PropagatedName','')); %#ok<AGROW>
                end
            end
        end
    end
end
function v=safeField(o,n,d), try, v=o.(n); catch, v=d; end, end
function p=safePath(m), try, p=get_param(m,'FileName'); catch, p=''; end, end
