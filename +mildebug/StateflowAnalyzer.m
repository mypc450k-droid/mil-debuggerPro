classdef StateflowAnalyzer < handle
    %STATEFLOWANALYZER Read-only Stateflow structural metadata for MIL analysis.
    %
    % Runtime transition outcomes are deliberately reported as unavailable
    % unless they are present in captured simulation evidence.

    methods
        function result=analyze(~,modelName)
            result=struct( ...
                'Charts',struct('Path',{},'Name',{},'Id',{}), ...
                'States',struct('ChartPath',{},'Path',{},'Name',{},'Label',{},'Id',{}), ...
                'Transitions',struct('ChartPath',{},'Path',{},'Label',{},'Condition',{}, ...
                                      'Trigger',{},'Source',{},'Destination',{},'Variables',{},'Id',{}), ...
                'Data',struct('ChartPath',{},'Path',{},'Name',{},'Logging',{},'Id',{}), ...
                'Events',struct('ChartPath',{},'Path',{},'Name',{},'Id',{}), ...
                'RuntimeEvidenceAvailable',false);
            try
                rt=sfroot;
                charts=find(rt,"-isa","Stateflow.Chart");
                for k=1:numel(charts)
                    ch=charts(k);
                    p=safeProp(ch,'Path','');
                    if ~startsWith(string(p),string(modelName)+"/") && ~strcmp(string(p),string(modelName))
                        continue
                    end
                    result.Charts(end+1)=struct( ...
                        'Path',char(string(p)), ...
                        'Name',char(string(safeProp(ch,'Name','Chart'))), ...
                        'Id',safeNumeric(ch,'SSIdNumber',safeNumeric(ch,'Id',k))); %#ok<AGROW>

                    states=find(ch,"-isa","Stateflow.State");
                    for j=1:numel(states)
                        st=states(j);
                        result.States(end+1)=struct( ...
                            'ChartPath',char(string(p)), ...
                            'Path',char(string(safeProp(st,'Path',p))), ...
                            'Name',char(string(safeProp(st,'Name','State'))), ...
                            'Label',char(string(safeProp(st,'LabelString',''))), ...
                            'Id',safeNumeric(st,'SSIdNumber',safeNumeric(st,'Id',j))); %#ok<AGROW>
                    end

                    trs=find(ch,"-isa","Stateflow.Transition");
                    for j=1:numel(trs)
                        tr=trs(j);
                        label=char(string(safeProp(tr,'LabelString','')));
                        cond=char(string(safeProp(tr,'Condition','')));
                        trigger=char(string(safeProp(tr,'Trigger','')));
                        srcName=safeObjectName(safeProp(tr,'Source',[]));
                        dstName=safeObjectName(safeProp(tr,'Destination',[]));
                        parsed=parseLabelStatic(label);
                        result.Transitions(end+1)=struct( ...
                            'ChartPath',char(string(p)), ...
                            'Path',char(string(safeProp(tr,'Path',p))), ...
                            'Label',label, ...
                            'Condition',cond, ...
                            'Trigger',trigger, ...
                            'Source',srcName, ...
                            'Destination',dstName, ...
                            'Variables',{parsed.Variables}, ...
                            'Id',safeNumeric(tr,'SSIdNumber',safeNumeric(tr,'Id',j))); %#ok<AGROW>
                    end

                    data=find(ch,"-isa","Stateflow.Data");
                    for j=1:numel(data)
                        d=data(j);
                        logging=false;
                        try, logging=logical(d.LoggingInfo.DataLogging); catch, end
                        result.Data(end+1)=struct( ...
                            'ChartPath',char(string(p)), ...
                            'Path',char(string(safeProp(d,'Path',p))), ...
                            'Name',char(string(safeProp(d,'Name','Data'))), ...
                            'Logging',logging, ...
                            'Id',safeNumeric(d,'SSIdNumber',safeNumeric(d,'Id',j))); %#ok<AGROW>
                    end

                    events=find(ch,"-isa","Stateflow.Event");
                    for j=1:numel(events)
                        ev=events(j);
                        result.Events(end+1)=struct( ...
                            'ChartPath',char(string(p)), ...
                            'Path',char(string(safeProp(ev,'Path',p))), ...
                            'Name',char(string(safeProp(ev,'Name','Event'))), ...
                            'Id',safeNumeric(ev,'SSIdNumber',safeNumeric(ev,'Id',j))); %#ok<AGROW>
                    end
                end
            catch
                % Stateflow may be unavailable for a model/session. Return
                % empty structural evidence rather than failing MIL.
            end
        end

        function c=parseTransitionLabel(~,label)
            c=parseLabelStatic(label);
        end
    end
end

function v=safeProp(obj,name,default)
try
    v=obj.(name);
catch
    v=default;
end
end

function v=safeNumeric(obj,name,default)
try
    x=obj.(name);
    if isempty(x), v=default; else, v=double(x); end
catch
    v=default;
end
end

function name=safeObjectName(obj)
name='';
try
    if ~isempty(obj), name=char(string(obj.Name)); end
catch
end
end

function c=parseLabelStatic(label)
c=struct('Raw',label,'Variables',{{}});
if isempty(label), return; end
toks=regexp(label,'[A-Za-z_]\w*','match');
keywords={'true','false','if','else','AND','OR','NOT'};
toks=toks(~ismember(lower(toks),lower(keywords)));
c.Variables=unique(toks,'stable');
end
