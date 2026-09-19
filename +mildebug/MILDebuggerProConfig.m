classdef MILDebuggerProConfig
    properties (Constant)
        SupportedRelease = 'R2024b'
        AppTitle = 'MIL Debugger Pro'
        SessionVersion = 1
    end
    methods (Static)
        function tf = isSupportedRelease()
            tf = strcmpi(version('-release'),'2024b');
        end
    end
end
