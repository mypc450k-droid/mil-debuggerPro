classdef ReportGenerator < handle
    methods
        function html=generate(~,session)
            model=''; blocks=0; signals=0;
            if isfield(session,'ModelName'), model=session.ModelName; end
            if isfield(session,'Inventory')
                blocks=session.Inventory.BlockCount; signals=session.Inventory.SignalCount;
            end
            html=sprintf('<html><body><h1>MIL Debugger Pro Report</h1><p>Model: %s</p><p>Blocks: %d | Signals: %d</p></body></html>', ...
                escape(model),blocks,signals);
        end
    end
end
function s=escape(x)
s=char(string(x));
s=strrep(s,'&','&amp;'); s=strrep(s,'<','&lt;'); s=strrep(s,'>','&gt;');
end
