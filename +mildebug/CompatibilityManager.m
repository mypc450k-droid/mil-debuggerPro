classdef CompatibilityManager < handle
    methods
        function report=check(~)
            report=struct('Target','R2024b','CurrentRelease',version('-release'), ...
                'Supported',strcmpi(version('-release'),'2024b'));
        end
    end
end
