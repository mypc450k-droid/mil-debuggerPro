classdef SignalRepository < handle
    methods
        function signal=findByName(~,session,name)
            signal=[];
            if ~isfield(session,'Signals'), return; end
            for k=1:numel(session.Signals)
                if strcmp(session.Signals(k).Name,name), signal=session.Signals(k); return; end
            end
        end
        function [t,y]=samples(~,signal)
            t=[]; y=[];
            if isempty(signal), return; end
            try, t=signal.Values.Time; y=signal.Values.Data; catch, end
        end
    end
end
