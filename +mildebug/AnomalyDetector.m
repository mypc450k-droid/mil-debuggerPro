classdef AnomalyDetector < handle
    methods
        function findings=scanSignals(~,session)
            findings=struct('Type',{},'Severity',{},'Signal',{});
            if ~isfield(session,'Signals'), return; end
            for k=1:numel(session.Signals)
                try
                    d=session.Signals(k).Values.Data;
                    if isnumeric(d)
                        if any(isnan(d(:))), findings(end+1)=struct('Type','NaN','Severity','Warning','Signal',session.Signals(k).Name); end %#ok<AGROW>
                        if any(isinf(d(:))), findings(end+1)=struct('Type','Inf','Severity','Warning','Signal',session.Signals(k).Name); end %#ok<AGROW>
                    end
                catch
                end
            end
        end
    end
end
