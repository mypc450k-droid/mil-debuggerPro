classdef StateflowAnalyzer < handle
    methods
        function result=analyze(~,modelName)
            result=struct('Charts',{{}},'States',{{}},'Transitions',{{}},'RuntimeEvidenceAvailable',false);
            try
                result.Charts=find_system(modelName,'LookUnderMasks','all','FollowLinks','on','BlockType','SubSystem','MaskType','Stateflow');
            catch
            end
        end
        function c=parseTransitionLabel(~,label)
            c=struct('Raw',label,'Variables',{{}});
            if isempty(label), return; end
            toks=regexp(label,'[A-Za-z_]\w*','match');
            keywords={'true','false','if','else','AND','OR','NOT'};
            toks=toks(~ismember(lower(toks),lower(keywords)));
            c.Variables=unique(toks,'stable');
        end
    end
end
