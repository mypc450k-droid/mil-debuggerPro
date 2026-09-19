classdef ExecutionTraceManager < handle
    methods
        function c=capabilities(~)
            c=struct('sldebug',exist('sldebug','file')==2,'probe',exist('probe','file')==2);
        end
        function msg=start(~,modelName)
            msg=sprintf('Live debugger adapter ready for %s. Live commands are intentionally isolated from post-run cached analysis.',modelName);
        end
    end
end
