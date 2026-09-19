classdef MILDebuggerProApp < handle
    %MILDEBUGGERPROAPP Interactive R2024b MIL exploration and analysis app.
    %
    % Workflow:
    %   1) Resolve the active Simulink model.
    %   2) RUN MIL exactly once.
    %   3) Explore blocks, Stateflow objects and logged signals from cache.
    %   4) Select any number of signals and plot them together.
    %   5) Clear the graph and analyze a different selection without rerun.

    properties
        UIFigure matlab.ui.Figure
        ModelField matlab.ui.control.EditField
        RefreshButton matlab.ui.control.Button
        RunButton matlab.ui.control.Button
        RestoreButton matlab.ui.control.Button
        StatusLabel matlab.ui.control.Label
        BlockTree matlab.ui.container.Tree
        SelectedLabel matlab.ui.control.Label
        TabGroup matlab.ui.container.TabGroup
        PlotAxes matlab.ui.control.UIAxes
        SignalList matlab.ui.control.ListBox
        PlotSelectedButton matlab.ui.control.Button
        AnalyzeTreeButton matlab.ui.control.Button
        ClearGraphButton matlab.ui.control.Button
        ClearSelectionButton matlab.ui.control.Button
        SelectAllButton matlab.ui.control.Button
        SelectionInfoLabel matlab.ui.control.Label
        InputTable matlab.ui.control.Table
        OutputTable matlab.ui.control.Table
        StateTable matlab.ui.control.Table
        DiagnosticsTable matlab.ui.control.Table
        DetailsArea matlab.ui.control.TextArea
        TimeSpinner matlab.ui.control.NumericEditField
        SessionLabel matlab.ui.control.Label
    end

    properties (Access=private)
        Core
        ModelName char = ''
        Inventory struct = struct()
        Timer timer
        PreviousSelectedBlock char = ''
        LastDetectionMessage char = ''
        SignalDisplayNames cell = {}
    end

    methods
        function app=MILDebuggerProApp()
            app.Core=app.buildCore();
            app.buildUI();
            app.refreshModel();
            app.Timer=timer('ExecutionMode','fixedSpacing','Period',1.0, ...
                'TimerFcn',@(~,~)app.pollSelection());
            start(app.Timer);
        end

        function delete(app)
            try, stop(app.Timer); delete(app.Timer); catch, end
            try, delete(app.UIFigure); catch, end
        end
    end

    methods (Access=private)
        function c=buildCore(~)
            c=struct();
            c.ModelManager=mildebug.ModelManager();
            c.Discovery=mildebug.ModelDiscovery();
            c.Compiler=mildebug.ModelCompiler();
            c.Logging=mildebug.LoggingManager();
            c.Simulation=mildebug.SimulationManager();
            c.Session=mildebug.DebugSessionManager();
            c.Signals=mildebug.SignalRepository();
            c.Stateflow=mildebug.StateflowAnalyzer();
            c.Diagnostics=mildebug.DiagnosticsManager();
            c.Anomaly=mildebug.AnomalyDetector();
            c.Trace=mildebug.TraceEngine();
            c.Plot=mildebug.PlotEngine();
            c.Report=mildebug.ReportGenerator();
            c.Export=mildebug.ExportManager();
        end

        function buildUI(app)
            app.UIFigure=uifigure('Name','MIL Debugger Pro','Position',[60 40 1540 920]);
            app.UIFigure.CloseRequestFcn=@(~,~)app.closeApp();

            left=uipanel(app.UIFigure,'Position',[10 10 410 900], ...
                'Title','Model Explorer | multi-select with Ctrl+Click');
            top=uipanel(app.UIFigure,'Position',[430 780 1100 130],'Title','MIL Session');

            uilabel(top,'Position',[15 78 85 22],'Text','Active Model');
            app.ModelField=uieditfield(top,'text','Position',[100 78 620 22]);
            app.ModelField.Editable='off';
            app.RefreshButton=uibutton(top,'push','Text','Refresh','Position',[735 78 90 24], ...
                'ButtonPushedFcn',@(~,~)app.refreshModel());
            app.RunButton=uibutton(top,'push','Text','RUN MIL','Position',[835 78 105 24], ...
                'ButtonPushedFcn',@(~,~)app.runMIL());
            app.RestoreButton=uibutton(top,'push','Text','Restore','Position',[950 78 90 24], ...
                'ButtonPushedFcn',@(~,~)app.restoreModel());
            app.StatusLabel=uilabel(top,'Position',[15 45 1060 22],'Text','Ready');
            app.SessionLabel=uilabel(top,'Position',[15 17 1060 22],'Text','No cached MIL session');

            app.BlockTree=uitree(left,'Position',[10 230 390 620], ...
                'Multiselect','on', ...
                'SelectionChangedFcn',@(~,~)app.inspectSelection());
            app.BlockTree.Tooltip=['Ctrl+Click to select multiple blocks/Stateflow elements. ' ...
                'Then use Analyze tree selection.'];
            app.AnalyzeTreeButton=uibutton(left,'push','Text','Analyze Tree Selection', ...
                'Position',[10 190 190 28], ...
                'ButtonPushedFcn',@(~,~)app.analyzeTreeSelection());
            app.ClearGraphButton=uibutton(left,'push','Text','Clear Graph', ...
                'Position',[210 190 90 28], ...
                'ButtonPushedFcn',@(~,~)app.clearGraph());
            app.ClearSelectionButton=uibutton(left,'push','Text','Clear Selection', ...
                'Position',[305 190 95 28], ...
                'ButtonPushedFcn',@(~,~)app.clearAnalysisSelection());
            app.SelectedLabel=uilabel(left,'Position',[10 135 390 45], ...
                'Text','Selected: none','FontWeight','bold','WordWrap','on');
            uilabel(left,'Position',[10 102 390 22], ...
                'Text','Tip: use Ctrl+Click for any number of model elements.');

            app.TabGroup=uitabgroup(app.UIFigure,'Position',[430 10 1100 760]);
            tab1=uitab(app.TabGroup,'Title','Signals & Graph');
            tab2=uitab(app.TabGroup,'Title','Stateflow');
            tab3=uitab(app.TabGroup,'Title','Diagnostics');
            tab4=uitab(app.TabGroup,'Title','Trace');

            app.PlotAxes=uiaxes(tab1,'Position',[15 300 1070 405]);
            app.PlotAxes.XGrid='on'; app.PlotAxes.YGrid='on';
            xlabel(app.PlotAxes,'Time'); ylabel(app.PlotAxes,'Value');
            title(app.PlotAxes,'Select logged signals to plot');

            uilabel(tab1,'Position',[15 268 190 22], ...
                'Text','Cached logged signals');
            app.SelectionInfoLabel=uilabel(tab1,'Position',[215 268 520 22], ...
                'Text','Run MIL to populate the cached signal list.');
            app.SignalList=uilistbox(tab1,'Position',[15 70 1070 190], ...
                'Multiselect','on', ...
                'Items',{},'ItemsData',[], ...
                'ValueChangedFcn',@(~,~)app.updateSignalSelectionInfo());
            app.PlotSelectedButton=uibutton(tab1,'push','Text','Plot Selected Signals', ...
                'Position',[15 25 145 32], ...
                'ButtonPushedFcn',@(~,~)app.plotSelectedSignals());
            app.SelectAllButton=uibutton(tab1,'push','Text','Select All Logged', ...
                'Position',[170 25 125 32], ...
                'ButtonPushedFcn',@(~,~)app.selectAllSignals());
            uibutton(tab1,'push','Text','Clear Graph', ...
                'Position',[305 25 95 32], ...
                'ButtonPushedFcn',@(~,~)app.clearGraph());
            uibutton(tab1,'push','Text','Clear Signal Selection', ...
                'Position',[410 25 145 32], ...
                'ButtonPushedFcn',@(~,~)app.clearAnalysisSelection());
            uilabel(tab1,'Position',[760 38 85 22],'Text','Time cursor');
            app.TimeSpinner=uieditfield(tab1,'numeric','Position',[840 38 110 22], ...
                'Value',0,'ValueChangedFcn',@(~,~)app.updateAtTime());

            app.InputTable=uitable(tab1,'Position',[15 5 500 1], ...
                'ColumnName',{'Signal','Value at cursor'});
            app.OutputTable=uitable(tab1,'Position',[520 5 565 1], ...
                'ColumnName',{'Sample','Value'});

            app.StateTable=uitable(tab2,'Position',[15 55 1070 650], ...
                'ColumnName',{'Type','Path','Condition','Source','Destination','Variables'});
            uibutton(tab2,'push','Text','Refresh Stateflow','Position',[15 15 150 28], ...
                'ButtonPushedFcn',@(~,~)app.inspectStateflow());

            app.DiagnosticsTable=uitable(tab3,'Position',[15 55 1070 650], ...
                'ColumnName',{'Severity','Message','Identifier'});
            uibutton(tab3,'push','Text','Scan cached session','Position',[15 15 160 28], ...
                'ButtonPushedFcn',@(~,~)app.scanDiagnostics());

            app.DetailsArea=uitextarea(tab4,'Position',[15 55 1070 650], ...
                'Editable','off');
            uibutton(tab4,'push','Text','Describe selection','Position',[15 15 150 28], ...
                'ButtonPushedFcn',@(~,~)app.traceSelection());
        end

        function refreshModel(app)
            try
                info=app.Core.ModelManager.detectActiveModelInfo();
                m=info.Model;

                if isempty(m)
                    app.ModelName='';
                    app.Inventory=struct();
                    app.ModelField.Value='';
                    delete(app.BlockTree.Children);
                    app.SessionLabel.Text='No cached MIL session';
                    app.SignalList.Items={};
                    app.SignalList.ItemsData=[];
                    app.SignalList.Value={};
                    app.SignalDisplayNames={};
                    app.setStatus(info.Message);
                    return
                end

                modelChanged=~strcmp(app.ModelName,m);
                app.ModelName=m;
                app.ModelField.Value=m;

                if modelChanged
                    app.Core.Session.clear();
                    app.SessionLabel.Text='No cached MIL session for active model';
                    app.clearGraph();
                    app.clearSignalList();
                end

                app.Inventory=app.Core.Discovery.discover(m);
                app.populateTree();
                app.LastDetectionMessage=info.Message;
                app.setStatus(sprintf('%s | %d blocks | %d signal lines', ...
                    info.Message,app.Inventory.BlockCount,app.Inventory.SignalCount));
            catch ME
                app.setStatus(['Refresh failed: ' ME.message]);
            end
        end

        function populateTree(app)
            delete(app.BlockTree.Children);
            if isempty(app.ModelName), return; end

            root=uitreenode(app.BlockTree,'Text',app.ModelName, ...
                'NodeData',struct('Kind','Model','Path',app.ModelName));
            root.Tag='Model';

            blocksNode=uitreenode(root,'Text',sprintf('Blocks (%d)', ...
                numel(app.Inventory.Blocks)), ...
                'NodeData',struct('Kind','Group','Name','Blocks'));
            blocksNode.Tag='Group';

            for k=1:numel(app.Inventory.Blocks)
                b=app.Inventory.Blocks(k);
                label=sprintf('%s  [%s]',b.Name,b.BlockType);
                n=uitreenode(blocksNode,'Text',label, ...
                    'NodeData',struct('Kind','Block','Path',b.Path, ...
                                      'Name',b.Name,'BlockType',b.BlockType));
                n.Tag=char(string(b.BlockType));
            end

            sf=app.Core.Stateflow.analyze(app.ModelName);
            sfNode=uitreenode(root,'Text',sprintf('Stateflow (%d charts)', ...
                numel(sf.Charts)), ...
                'NodeData',struct('Kind','Group','Name','Stateflow'));
            sfNode.Tag='StateflowGroup';

            for k=1:numel(sf.Charts)
                ch=sf.Charts(k);
                cn=uitreenode(sfNode,'Text',['Chart: ' ch.Name], ...
                    'NodeData',struct('Kind','StateflowChart','Path',ch.Path, ...
                                      'Name',ch.Name,'Id',ch.Id));
                cn.Tag='StateflowChart';

                states=sf.States(strcmp(string({sf.States.ChartPath}),string(ch.Path)));
                for j=1:numel(states)
                    st=states(j);
                    sn=uitreenode(cn,'Text',['State: ' st.Name], ...
                        'NodeData',struct('Kind','StateflowState','Path',st.Path, ...
                                          'Name',st.Name,'Label',st.Label,'Id',st.Id));
                    sn.Tag='StateflowState';
                end

                trs=sf.Transitions(strcmp(string({sf.Transitions.ChartPath}),string(ch.Path)));
                for j=1:numel(trs)
                    tr=trs(j);
                    tn=uitreenode(cn,'Text',sprintf('Transition: %s -> %s', ...
                        tr.Source,tr.Destination), ...
                        'NodeData',struct('Kind','StateflowTransition','Path',tr.Path, ...
                                          'Name',tr.Label,'Condition',tr.Condition, ...
                                          'Source',tr.Source,'Destination',tr.Destination, ...
                                          'Variables',{tr.Variables},'Id',tr.Id));
                    tn.Tag='StateflowTransition';
                end

                data=sf.Data(strcmp(string({sf.Data.ChartPath}),string(ch.Path)));
                if ~isempty(data)
                    dn=uitreenode(cn,'Text',sprintf('Data (%d)',numel(data)), ...
                        'NodeData',struct('Kind','Group','Name','Data'));
                    for j=1:numel(data)
                        d=data(j);
                        uitreenode(dn,'Text',['Data: ' d.Name], ...
                            'NodeData',struct('Kind','StateflowData','Path',d.Path, ...
                                              'Name',d.Name,'Logging',d.Logging,'Id',d.Id));
                    end
                end
            end
            expand(root);
        end

        function runMIL(app)
            if isempty(app.ModelName)
                app.refreshModel();
                if isempty(app.ModelName), return; end
            end

            app.RunButton.Enable='off';
            app.setStatus(['Preparing active model: ' app.ModelName]);
            drawnow;
            cleanup=onCleanup(@()set(app.RunButton,'Enable','on')); %#ok<NASGU>

            try
                active=app.Core.ModelManager.detectActiveModel();
                if isempty(active) || ~strcmp(active,app.ModelName)
                    error('MILDebuggerPro:ActiveModelChanged', ...
                        'The active Simulink model changed. Press Refresh and run MIL again.');
                end

                app.Core.Logging.captureSnapshot(app.ModelName);
                app.Core.Logging.configure(app.ModelName);
                app.setStatus('Compiling model...');
                drawnow;
                cr=app.Core.Compiler.compile(app.ModelName);
                if ~cr.Success
                    error('MILDebuggerPro:Compile',cr.ErrorMessage);
                end

                app.setStatus('Running MIL once...');
                drawnow;
                sr=app.Core.Simulation.runMIL(app.ModelName);
                if ~sr.Success
                    error('MILDebuggerPro:Simulation',sr.ErrorMessage);
                end

                app.Core.Session.create(app.ModelName,app.Inventory,cr,sr);
                app.SessionLabel.Text=sprintf('Cached session: %s | %.3fs | %d signals', ...
                    datestr(app.Core.Session.Session.CreatedAt,'yyyy-mm-dd HH:MM:SS'), ...
                    sr.Elapsed,numel(app.Core.Session.Session.Signals));

                app.refreshSignalList();
                app.setStatus('MIL complete. Select any number of cached signals and plot without rerunning MIL.');
                app.scanDiagnostics();
                app.inspectStateflow();
            catch ME
                app.setStatus(['MIL failed: ' ME.message]);
            end
        end

        function inspectSelection(app)
            nodes=app.BlockTree.SelectedNodes;
            if isempty(nodes)
                app.SelectedLabel.Text='Selected: none';
                return
            end

            desc=cell(1,numel(nodes));
            for k=1:numel(nodes)
                d=nodes(k).NodeData;
                if isstruct(d) && isfield(d,'Kind')
                    desc{k}=app.nodeSummary(d);
                else
                    desc{k}=char(string(nodes(k).Text));
                end
            end
            app.SelectedLabel.Text=sprintf('Selected %d element(s): %s', ...
                numel(nodes),strjoin(desc,' | '));

            % Keep the editor selection synchronized for the first Simulink
            % block only. No simulation is triggered here.
            for k=1:numel(nodes)
                d=nodes(k).NodeData;
                if isstruct(d) && isfield(d,'Kind') && strcmp(d.Kind,'Block')
                    try, app.Core.ModelManager.navigateToBlock(d.Path); catch, end
                    break
                end
            end
        end

        function analyzeTreeSelection(app)
            if isempty(app.BlockTree.SelectedNodes)
                app.setStatus('Select one or more blocks or Stateflow elements with Ctrl+Click first.');
                return
            end
            if ~app.Core.Session.isSessionReady()
                app.setStatus('No cached MIL session. Run MIL once before analysis.');
                return
            end

            idx=[];
            nodes=app.BlockTree.SelectedNodes;
            for k=1:numel(nodes)
                d=nodes(k).NodeData;
                if ~isstruct(d) || ~isfield(d,'Kind'), continue; end
                switch d.Kind
                    case 'Block'
                        idx=[idx app.matchSignalsToText(d.Path,d.Name)]; %#ok<AGROW>
                    case {'StateflowChart','StateflowState','StateflowTransition','StateflowData'}
                        idx=[idx app.matchSignalsToText(safeField(d,'Path',''), ...
                            safeField(d,'Name',''))]; %#ok<AGROW>
                end
            end
            idx=unique(idx,'stable');

            if isempty(idx)
                app.setStatus(['No cached logged signal could be mapped directly to the selected ' ...
                    'element(s). Use the Logged Signals list for exact signal selection.']);
                return
            end

            app.SignalList.Value=idx;
            app.plotSelectedSignals();
        end

        function idx=matchSignalsToText(app,path,name)
            idx=[];
            s=app.Core.Session.Session.Signals;
            for k=1:numel(s)
                bp=char(string(s(k).BlockPath));
                nm=char(string(s(k).Name));
                hit=false;
                if ~isempty(path)
                    hit=contains(bp,path,'IgnoreCase',false);
                end
                if ~hit && ~isempty(name)
                    hit=contains(nm,name,'IgnoreCase',false) || contains(bp,name,'IgnoreCase',false);
                end
                if hit, idx(end+1)=k; end %#ok<AGROW>
            end
        end

        function refreshSignalList(app)
            if ~app.Core.Session.isSessionReady()
                app.clearSignalList();
                return
            end
            s=app.Core.Session.Session.Signals;
            n=numel(s);
            app.SignalDisplayNames=cell(1,n);
            for k=1:n
                nm=char(string(s(k).Name));
                bp=char(string(s(k).BlockPath));
                if isempty(bp), bp='unmapped source'; end
                if isempty(nm), nm=sprintf('Signal %d',k); end
                app.SignalDisplayNames{k}=sprintf('%04d | %s | %s',k,nm,bp);
            end
            app.SignalList.Items=app.SignalDisplayNames;
            app.SignalList.ItemsData=1:n;
            app.SignalList.Value={};
            app.updateSignalSelectionInfo();
        end

        function clearSignalList(app)
            if isempty(app.SignalList) || ~isvalid(app.SignalList), return; end
            app.SignalDisplayNames={};
            app.SignalList.Items={};
            app.SignalList.ItemsData=[];
            app.SignalList.Value={};
            app.SelectionInfoLabel.Text='No cached logged signals.';
        end

        function updateSignalSelectionInfo(app)
            if isempty(app.SignalList.Items)
                app.SelectionInfoLabel.Text='No cached logged signals. Run MIL first.';
                return
            end
            v=app.SignalList.Value;
            if isempty(v)
                app.SelectionInfoLabel.Text=sprintf('%d logged signal(s) available. Select any number with Ctrl+Click.', ...
                    numel(app.SignalList.Items));
            else
                app.SelectionInfoLabel.Text=sprintf('%d signal(s) selected. Click Plot Selected Signals.', ...
                    numel(v));
            end
        end

        function selectAllSignals(app)
            if isempty(app.SignalList.Items), return; end
            app.SignalList.Value=1:numel(app.SignalList.Items);
            app.updateSignalSelectionInfo();
        end

        function clearAnalysisSelection(app)
            if ~isempty(app.SignalList) && isvalid(app.SignalList)
                app.SignalList.Value={};
            end
            if ~isempty(app.BlockTree) && isvalid(app.BlockTree)
                app.BlockTree.SelectedNodes=[];
            end
            app.updateSignalSelectionInfo();
            app.SelectedLabel.Text='Selected: none';
            app.setStatus('Analysis selection cleared. Cached MIL data is still available.');
        end

        function clearGraph(app)
            if ~isempty(app.PlotAxes) && isvalid(app.PlotAxes)
                cla(app.PlotAxes);
                title(app.PlotAxes,'Select logged signals to plot');
                xlabel(app.PlotAxes,'Time');
                ylabel(app.PlotAxes,'Value');
            end
            if ~isempty(app.InputTable) && isvalid(app.InputTable), app.InputTable.Data={}; end
            if ~isempty(app.OutputTable) && isvalid(app.OutputTable), app.OutputTable.Data={}; end
            app.setStatus('Graph cleared. Cached MIL data remains available for a fresh analysis.');
        end

        function plotSelectedSignals(app)
            if ~app.Core.Session.isSessionReady()
                app.setStatus('No cached MIL session. Run MIL once first.');
                return
            end
            selected=app.SignalList.Value;
            if isempty(selected)
                app.setStatus('Select one or more logged signals first.');
                return
            end
            selected=double(selected(:))';

            s=app.Core.Session.Session.Signals;
            cla(app.PlotAxes);
            hold(app.PlotAxes,'on');
            plotted=0;
            legendNames={};
            for q=selected
                if q<1 || q>numel(s), continue; end
                [t,y,ok]=app.extractXY(s(q).Values);
                if ~ok, continue; end
                try
                    plot(app.PlotAxes,t,y,'LineWidth',1.1);
                    plotted=plotted+1;
                    legendNames{end+1}=char(string(s(q).Name)); %#ok<AGROW>
                catch
                    % Skip unsupported logged data types without failing the
                    % rest of the analysis.
                end
            end
            hold(app.PlotAxes,'off');
            grid(app.PlotAxes,'on');
            xlabel(app.PlotAxes,'Time');
            ylabel(app.PlotAxes,'Value');
            if plotted>0
                title(app.PlotAxes,sprintf('%d logged signal(s) - cached MIL data',plotted), ...
                    'Interpreter','none');
                legend(app.PlotAxes,legendNames,'Interpreter','none','Location','best');
                app.populateSampleTable(selected(1));
                app.setStatus(sprintf('Plotted %d selected logged signal(s). No simulation was run.',plotted));
            else
                title(app.PlotAxes,'Selected signals could not be plotted');
                app.setStatus('The selected logged data is not in a directly plottable time-series form.');
            end
        end

        function [t,y,ok]=extractXY(~,values)
            t=[]; y=[]; ok=false;
            try
                t=double(values.Time(:));
                y=values.Data;
                if isempty(t) || isempty(y), return; end
                if isvector(y)
                    y=double(y(:));
                else
                    y=double(y);
                    if size(y,1)==numel(t)
                        % expected orientation
                    elseif size(y,2)==numel(t)
                        y=y.';
                    else
                        y=squeeze(y);
                        if isvector(y), y=double(y(:)); else, return; end
                    end
                end
                ok=true;
            catch
            end
        end

        function populateSampleTable(app,index)
            try
                s=app.Core.Session.Session.Signals(index);
                [t,y,ok]=app.extractXY(s.Values);
                if ~ok, return; end
                if size(y,2)>1, y=y(:,1); end
                n=min(numel(t),numel(y));
                app.OutputTable.Data=[num2cell(t(1:n)),num2cell(y(1:n))];
                app.OutputTable.ColumnName={'Time','First channel/sample'};
            catch
                app.OutputTable.Data={};
            end
        end

        function updateAtTime(app)
            if ~app.Core.Session.isSessionReady(), return; end
            selected=app.SignalList.Value;
            if isempty(selected), return; end
            selected=double(selected(:))';
            t0=app.TimeSpinner.Value;
            s=app.Core.Session.Session.Signals;
            rows={};
            for q=selected
                try
                    [t,y,ok]=app.extractXY(s(q).Values);
                    if ~ok, continue; end
                    [~,i]=min(abs(t-t0));
                    val=y(i,:);
                    rows(end+1,:)={char(string(s(q).Name)),val}; %#ok<AGROW>
                catch
                end
            end
            app.InputTable.Data=rows;
            app.InputTable.ColumnName={'Signal','Value at cursor'};
        end

        function inspectStateflow(app)
            if isempty(app.ModelName), return; end
            r=app.Core.Stateflow.analyze(app.ModelName);
            rows=cell(0,6);
            for k=1:numel(r.Charts)
                ch=r.Charts(k);
                rows(end+1,:)={'Chart',ch.Path,'','','','Static metadata only'}; %#ok<AGROW>
            end
            for k=1:numel(r.States)
                st=r.States(k);
                rows(end+1,:)={'State',st.Path,'',st.Name,'',st.Label}; %#ok<AGROW>
            end
            for k=1:numel(r.Transitions)
                tr=r.Transitions(k);
                rows(end+1,:)={'Transition',tr.Path,tr.Condition,tr.Source,tr.Destination, ...
                    strjoin(tr.Variables,', ')}; %#ok<AGROW>
            end
            for k=1:numel(r.Data)
                d=r.Data(k);
                rows(end+1,:)={'Data',d.Path,sprintf('Logging=%d',d.Logging),'','',''}; %#ok<AGROW>
            end
            app.StateTable.Data=rows;
        end

        function scanDiagnostics(app)
            if ~app.Core.Session.isSessionReady(), return; end
            d=app.Core.Diagnostics.summarizeSimulation(app.Core.Session.Session.Simulation);
            f=app.Core.Anomaly.scanSignals(app.Core.Session.Session);
            rows=cell(0,3);
            for k=1:numel(d)
                rows(end+1,:)={d(k).Severity,d(k).Message,d(k).Identifier}; %#ok<AGROW>
            end
            for k=1:numel(f)
                rows(end+1,:)={f(k).Severity,[f(k).Type ': ' f(k).Signal], ...
                    'MILDebuggerPro:Anomaly'}; %#ok<AGROW>
            end
            app.DiagnosticsTable.Data=rows;
        end

        function traceSelection(app)
            nodes=app.BlockTree.SelectedNodes;
            if isempty(nodes)
                app.DetailsArea.Value={'No model element selected.'};
                return
            end
            lines=cell(1,numel(nodes)+2);
            lines{1}=sprintf('%d model element(s) selected.',numel(nodes));
            lines{2}='Inspection is post-run and cached. This action does not call sim.';
            for k=1:numel(nodes)
                d=nodes(k).NodeData;
                lines{k+2}=app.nodeSummary(d);
            end
            app.DetailsArea.Value=lines;
        end

        function txt=nodeSummary(~,d)
            if ~isstruct(d) || ~isfield(d,'Kind')
                txt=char(string(d));
                return
            end
            switch d.Kind
                case 'Block'
                    txt=['Block: ' char(string(d.Path))];
                case 'StateflowChart'
                    txt=['Stateflow chart: ' char(string(d.Path))];
                case 'StateflowState'
                    txt=['Stateflow state: ' char(string(d.Path))];
                case 'StateflowTransition'
                    txt=['Stateflow transition: ' char(string(d.Path))];
                case 'StateflowData'
                    txt=['Stateflow data: ' char(string(d.Path))];
                otherwise
                    txt=char(string(d.Kind));
            end
        end

        function pollSelection(app)
            if ~isvalid(app.UIFigure), return; end
            try
                active=app.Core.ModelManager.detectActiveModel();
                if ~isempty(active) && ~strcmp(active,app.ModelName)
                    app.refreshModel();
                    return
                end
                p=app.Core.ModelManager.getSelectedBlock(app.ModelName);
                if ~isempty(p) && ~strcmp(p,app.PreviousSelectedBlock)
                    app.PreviousSelectedBlock=p;
                    app.SelectedLabel.Text=['MATLAB selected: ' p];
                end
            catch
            end
        end

        function restoreModel(app)
            if isempty(app.ModelName), return; end
            try
                app.Core.Logging.restore(app.ModelName);
                app.setStatus('Original model logging configuration restored.');
            catch ME
                app.setStatus(['Restore failed: ' ME.message]);
            end
        end

        function setStatus(app,msg)
            if isvalid(app.StatusLabel)
                app.StatusLabel.Text=char(string(msg));
                drawnow limitrate;
            end
        end

        function closeApp(app)
            delete(app);
        end
    end
end

function v=safeField(s,name,default)
try
    if isstruct(s) && isfield(s,name), v=s.(name); else, v=default; end
catch
    v=default;
end
end
