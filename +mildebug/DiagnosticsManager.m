classdef DiagnosticsManager < handle
    methods
        function d=summarizeSimulation(~,r)
            d=struct('Severity',{},'Message',{},'Identifier',{});
            if isempty(r) || r.Success, return; end
            d=struct('Severity','Error','Message',r.ErrorMessage,'Identifier',r.ErrorIdentifier);
        end
    end
end
