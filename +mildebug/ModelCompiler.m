classdef ModelCompiler < handle
    methods
        function result=compile(~,modelName)
            t=tic; result=struct('Success',false,'Elapsed',NaN,'ErrorIdentifier','','ErrorMessage','');
            try
                set_param(modelName,'SimulationCommand','update');
                result.Success=true;
            catch ME
                result.ErrorIdentifier=ME.identifier; result.ErrorMessage=ME.message;
            end
            result.Elapsed=toc(t);
        end
        function info=readCompiledPortInfo(~,blockPath)
            info=struct();
            names={'CompiledPortDataTypes','CompiledPortDimensions','CompiledPortWidths','CompiledSampleTime','CompiledPortComplexSignals'};
            for k=1:numel(names)
                try, info.(names{k})=get_param(blockPath,names{k}); catch, info.(names{k})=[]; end
            end
        end
    end
end
