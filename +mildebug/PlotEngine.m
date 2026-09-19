classdef PlotEngine < handle
    methods
        function plotSignal(~,ax,values,name)
            cla(ax);
            try
                plot(ax,values.Time,values.Data);
                grid(ax,'on'); xlabel(ax,'Time'); ylabel(ax,'Value');
                title(ax,name,'Interpreter','none');
            catch ME
                title(ax,['Plot unavailable: ' ME.message],'Interpreter','none');
            end
        end
    end
end
