classdef ModelDiscovery < handle
    properties (Access=private)
        Cache struct = struct()
    end
    methods
        function inventory = discover(obj,modelName)
            if ~bdIsLoaded(modelName), load_system(modelName); end
            blocks = find_system(modelName,'LookUnderMasks','all','FollowLinks','on','Type','Block');
            lines = find_system(modelName,'LookUnderMasks','all','FollowLinks','on','FindAll','on','Type','line');
            info = repmat(obj.blockTemplate(),numel(blocks),1);
            for k=1:numel(blocks)
                p=blocks{k};
                info(k).ID=sprintf('B%06d',k);
                info(k).Path=p;
                info(k).Name=get_param(p,'Name');
                info(k).BlockType=safeGet(p,'BlockType','');
                info(k).Parent=safeGet(p,'Parent','');
                info(k).Handle=safeGet(p,'Handle',NaN);
                info(k).Ports=safeGet(p,'Ports',[]);
                info(k).MaskType=safeGet(p,'MaskType','');
            end
            sig = repmat(obj.signalTemplate(),numel(lines),1);
            for k=1:numel(lines)
                h=lines(k);
                sig(k).ID=sprintf('S%06d',k);
                sig(k).Handle=h;
                sig(k).Name=safeGet(h,'Name','');
                sig(k).SrcPortHandle=safeGet(h,'SrcPortHandle',[]);
                sig(k).DstPortHandle=safeGet(h,'DstPortHandle',[]);
            end
            inventory=struct('ModelName',modelName,'Blocks',info,'Signals',sig, ...
                'BlockCount',numel(info),'SignalCount',numel(sig),'CreatedAt',datetime('now'));
            obj.Cache.(matlab.lang.makeValidName(modelName))=inventory;
        end
        function inventory = cached(obj,modelName)
            key=matlab.lang.makeValidName(modelName);
            if isfield(obj.Cache,key), inventory=obj.Cache.(key); else, inventory=obj.discover(modelName); end
        end
    end
    methods (Static, Access=private)
        function s=blockTemplate()
            s=struct('ID','','Path','','Name','','BlockType','','Parent','','Handle',NaN,'Ports',[],'MaskType','');
        end
        function s=signalTemplate()
            s=struct('ID','','Handle',NaN,'Name','','SrcPortHandle',[],'DstPortHandle',[]);
        end
    end
end
function v=safeGet(o,n,d)
try, v=get_param(o,n); catch, v=d; end
end
