classdef TraceEngine < handle
    methods
        function result=traceUpstream(~,modelName,signalHandle)
            result=struct('Model',modelName,'SignalHandle',signalHandle,'Path',{{}});
            try
                src=get_param(signalHandle,'SrcPortHandle');
                if ~isempty(src) && all(src~=-1), result.Path={getfullname(src)}; end
            catch
            end
        end
    end
end
