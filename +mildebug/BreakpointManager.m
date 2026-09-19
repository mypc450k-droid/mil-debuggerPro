classdef BreakpointManager < handle
    properties
        Breakpoints=struct('Type',{},'Target',{},'Expression',{},'Enabled',{})
    end
    methods
        function add(obj,type,target,expression)
            if nargin<4, expression=''; end
            obj.Breakpoints(end+1)=struct('Type',type,'Target',target,'Expression',expression,'Enabled',true);
        end
        function clear(obj)
            obj.Breakpoints=obj.Breakpoints([]);
        end
    end
end
