classdef StateRepository < handle
    methods
        function states=extract(~,simOutput)
            states=struct('Name',{},'Values',{},'Source',{},'Available',{});
            if isempty(simOutput), return; end
            try
                if isprop(simOutput,'xout')
                    states=struct('Name','xout','Values',simOutput.xout,'Source','SimulationOutput','Available',true);
                end
            catch
            end
        end
    end
end
