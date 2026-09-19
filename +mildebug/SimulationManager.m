classdef SimulationManager < handle
    methods
        function result=runMIL(~,modelName,varargin)
            p=inputParser; addParameter(p,'StopTime',''); parse(p,varargin{:});
            t=tic; result=struct('Success',false,'Elapsed',NaN,'Output',[], ...
                'ErrorIdentifier','','ErrorMessage','','StartedAt',datetime('now'),'FinishedAt',NaT);
            try
                if strlength(string(p.Results.StopTime))>0
                    result.Output=sim(modelName,'StopTime',p.Results.StopTime);
                else
                    result.Output=sim(modelName);
                end
                result.Success=true;
            catch ME
                result.ErrorIdentifier=ME.identifier; result.ErrorMessage=ME.message;
            end
            result.Elapsed=toc(t); result.FinishedAt=datetime('now');
        end
    end
end
