classdef MILDebuggerProApp < handle
    %MILDEBUGGERPROAPP Interactive R2024b MIL exploration app.
    %
    % Run:
    %   app = MILDebuggerProApp();
    %
    % Model selection is tied to the Simulink editor's active context.
    % The app never chooses the first arbitrary loaded block diagram.

    properties
        UIFigure matlab.ui.Figure
        ModelField matlab.ui.control.EditField
        RefreshButton matlab.ui.control.Button
        RunButton matlab.ui.control.Button
        RestoreButton matlab.ui.control.Button
        StatusLabel matlab.ui.control.Label
        BlockTree matlab.ui.container.Tree
        TabGroup matlab.ui.container.TabGroup
        PlotAxes matlab.ui.control.UIAxes
        InputTable matlab.ui.control.Table
        OutputTable matlab.ui.control.Table
        StateTable matlab.ui.control.Table
        DiagnosticsTable matlab.ui.control.Table
        DetailsArea matlab.ui.control.TextArea
        TimeSpinner matlab.ui.control.NumericEditField
        SelectedLabel matlab.ui.control.Label
        SessionLabel matlab.ui.control.Label
    end

    properties (Access=private)
        Core
        ModelName char = ''
        Inventory struct = struct()
        Timer timer
        PreviousSelectedBlock char = ''
        LastDetectionMessage char = ''
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
            app.UIFigure=uifigure('Name','MIL Debugger Pro','Position',[80 60 1500 900]);
            app.UIFigure.CloseRequestFcn=@(~,~)app.closeApp();

            left=uipanel(app.UIFigure,'Position',[10 10 390 880],'Title','Model Explorer');
            top=uipanel(app.UIFigure,'Position',[410 760 1080 130],'Title','MIL Session');

            uilabel(top,'Position',[15 75 80 22],'Text','Active Model');
            app.ModelField=uieditfield(top,'text','Position',[95 75 620 22]);
            app.ModelField.Editable='off';
            app.RefreshButton=uibutton(top,'push','Text','Refresh','Position',[730 75 90 22], ...
                'ButtonPushedFcn',@(~,~)app.refreshModel());
            app.RunButton=uibutton(top,'push','Text','RUN MIL','Position',[830 75 105 22], ...
                'ButtonPushedFcn',@(~,~)app.runMIL());
            app.RestoreButton=uibutton(top,'push','Text','Restore','Position',[945 75 90 22], ...
                'ButtonPushedFcn',@(~,~)app.restoreModel());
            app.StatusLabel=uilabel(top,'Position',[15 42 1020 22],'Text','Ready');
            app.SessionLabel=uilabel(top,'Position',[15 15 1020 22],'Text','No cached MIL session');

            app.BlockTree=uitree(left,'Position',[10 70 370 760], ...
                'SelectionChangedFcn',@(~,~)app.inspectSelection());
            % TreeNode itself has no Tooltip property in R2024b. Keep the
            % tree-level tooltip for guidance and store block type in Tag.
            app.BlockTree.Tooltip='Click a block to inspect it. Block type is stored in each node Tag.';
            app.SelectedLabel=uilabel(left,'Position',[10 25 370 30],'Text','Selected: none','FontWeight','bold');

            app.TabGroup=uitabgroup(app.UIFigure,'Position',[410 10 1080 735]);
            tab1=uitab(app.TabGroup,'Title','Signals');
            tab2=uitab(app.TabGroup,'Title','Stateflow');
            tab3=uitab(app.TabGroup,'Title','Diagnostics');
            tab4=uitab(app.TabGroup,'Title','Trace');

            app.PlotAxes=uiaxes(tab1,'Position',[15 245 1045 440]);
            app.PlotAxes.XGrid='on'; app.PlotAxes.YGrid='on';
            app.InputTable=uitable(tab1,'Position',[15 15 500 210],'ColumnName',{'Time','Value'});
            app.OutputTable=uitable(tab1,'Position',[555 15 500 210],'ColumnName',{'Time','Value'});
            uilabel(tab1,'Position',[15 710 110 22],'Text','Time cursor');
            app.TimeSpinner=uieditfield(tab1,'numeric','Position',[90 710 120 22],'Value',0, ...
                'ValueChangedFcn',@(~,~)app.updateAtTime());

            app.StateTable=uitable(tab2,'Position',[15 15 1045 650], ...
                'ColumnName',{'Type','Path','Condition','Variables','Runtime evidence'});
            uibutton(tab2,'push','Text','Refresh Stateflow','Position',[15 680 150 28], ...
                'ButtonPushedFcn',@(~,~)app.inspectStateflow());

            app.DiagnosticsTable=uitable(tab3,'Position',[15 15 1045 650], ...
                'ColumnName',{'Severity','Message','Identifier'});
            uibutton(tab3,'push','Text','Scan cached session','Position',[15 680 160 28], ...
                'ButtonPushedFcn',@(~,~)app.scanDiagnostics());

            app.DetailsArea=uitextarea(tab4,'Position',[15 15 1045 650],'Editable','off');
            uibutton(tab4,'push','Text','Trace selected block','Position',[15 680 170 28], ...
                'ButtonPushedFcn',@(~,~)app.traceSelection());
        end

        function refreshModel(app)
            try
                info=app.Core.ModelManager.detectActiveModelInfo();
                m=info.Model;

                if isempty(m)
                    % Do not keep a stale model after the user switches to
                    % another Simulink window or closes the previous model.
                    app.ModelName='';
                    app.Inventory=struct();
                    app.ModelField.Value='';
                    delete(app.BlockTree.Children);
                    app.SessionLabel.Text='No cached MIL session';
                    app.setStatus(info.Message);
                    return
                end

                % If MATLAB reports a different active model, invalidate the
                % previous inventory/session. The user must explicitly RUN
                % MIL for the newly active model.
                modelChanged=~strcmp(app.ModelName,m);
                app.ModelName=m;
                app.ModelField.Value=m;

                if modelChanged
                    app.Core.Session.clear();
                    app.SessionLabel.Text='No cached MIL session for active model';
                    cla(app.PlotAxes);
                    app.InputTable.Data={};
                    app.OutputTable.Data={};
                    app.DiagnosticsTable.Data={};
                    app.StateTable.Data={};
                end

                app.Inventory=app.Core.Discovery.discover(m);
                try
                    app.populateTree();
                catch treeME
                    % A UI tree rendering problem must not hide the detected
                    % model. Keep the active model visible and report the
                    % rendering problem explicitly.
                    app.setStatus(['Model detected, but tree population failed: ' treeME.message]);
                    return
                end
                app.LastDetectionMessage=info.Message;
                app.setStatus(sprintf('%s | %d blocks | %d signal lines',info.Message, ...
                    app.Inventory.BlockCount,app.Inventory.SignalCount));
            catch ME
                app.setStatus(['Refresh failed: ' ME.message]);
            end
        end

        function populateTree(app)
            delete(app.BlockTree.Children);
            if isempty(app.ModelName), return; end
            root=uitreenode(app.BlockTree,'Text',app.ModelName,'NodeData',app.ModelName);
            root.Tag='Model';
            for k=1:numel(app.Inventory.Blocks)
                b=app.Inventory.Blocks(k);
                n=uitreenode(root,'Text',b.Name,'NodeData',b.Path);
                % R2024b TreeNode supports Tag, not Tooltip.
                n.Tag=char(string(b.BlockType));
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
                % Revalidate the active editor model immediately before
                % changing logging or starting a simulation.
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
                if ~cr.Success, error('MILDebuggerPro:Compile',cr.ErrorMessage); end
                app.setStatus('Running MIL once...');
                drawnow;
                sr=app.Core.Simulation.runMIL(app.ModelName);
                if ~sr.Success, error('MILDebuggerPro:Simulation',sr.ErrorMessage); end
                app.Core.Session.create(app.ModelName,app.Inventory,cr,sr);
                app.SessionLabel.Text=sprintf('Cached session: %s | %.3fs | %d signals', ...
                    datestr(app.Core.Session.Session.CreatedAt,'yyyy-mm-dd HH:MM:SS'), ...
                    sr.Elapsed,numel(app.Core.Session.Session.Signals));
                app.setStatus('MIL complete. Block inspection uses cached data and will not rerun simulation.');
                app.scanDiagnostics();
                app.inspectStateflow();
            catch ME
                app.setStatus(['MIL failed: ' ME.message]);
            end
        end

        function inspectSelection(app)
            if isempty(app.BlockTree.SelectedNodes), return; end
            path=app.BlockTree.SelectedNodes(1).NodeData;
            if isempty(path) || strcmp(path,app.ModelName), return; end
            app.SelectedLabel.Text=['Selected: ' path];
            app.Core.ModelManager.navigateToBlock(path);
            if ~app.Core.Session.isSessionReady()
                app.setStatus('No cached MIL session for this model. Run MIL first.');
                return
            end
            app.showCachedBlock(path);
        end

        function showCachedBlock(app,path)
            s=app.Core.Session.Session.Signals;
            match=[];
            for k=1:numel(s)
                if contains(string(s(k).BlockPath),string(path),'IgnoreCase',false) || ...
                        contains(string(s(k).Name),string(get_param(path,'Name')))
                    match=s(k); break
                end
            end
            if isempty(match)
                app.setStatus(['No directly associated logged signal found for ' path '. Capture coverage may be partial for this block type.']);
                cla(app.PlotAxes);
                return
            end
            app.Core.Plot.plotSignal(app.PlotAxes,match.Values,match.Name);
            try
                t=match.Values.Time; y=match.Values.Data;
                app.OutputTable.Data=[num2cell(t(:)),num2cell(y(:))];
            catch
                app.OutputTable.Data={};
            end
            app.InputTable.Data={};
            app.setStatus(['Showing cached data for ' path]);
        end

        function pollSelection(app)
            if ~isvalid(app.UIFigure), return; end
            try
                % Detect a model switch without opening or selecting an
                % arbitrary loaded file. This keeps the GUI synchronized
                % with the Simulink editor.
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

        function updateAtTime(app)
            if ~app.Core.Session.isSessionReady(), return; end
            t0=app.TimeSpinner.Value;
            s=app.Core.Session.Session.Signals;
            rows={};
            for k=1:numel(s)
                try
                    t=s(k).Values.Time; y=s(k).Values.Data;
                    [~,i]=min(abs(double(t)-t0));
                    rows(end+1,:)={s(k).Name,y(i)}; %#ok<AGROW>
                catch
                end
            end
            app.InputTable.Data=rows;
            app.InputTable.ColumnName={'Signal','Value at cursor'};
        end

        function inspectStateflow(app)
            if isempty(app.ModelName), return; end
            r=app.Core.Stateflow.analyze(app.ModelName);
            rows=cell(numel(r.Charts),5);
            for k=1:numel(r.Charts)
                rows(k,:)={'Chart',r.Charts{k},'', '',logical(r.RuntimeEvidenceAvailable)};
            end
            app.StateTable.Data=rows;
        end

        function scanDiagnostics(app)
            if ~app.Core.Session.isSessionReady(), return; end
            d=app.Core.Diagnostics.summarizeSimulation(app.Core.Session.Session.Simulation);
            f=app.Core.Anomaly.scanSignals(app.Core.Session.Session);
            rows=cell(0,3);
            for k=1:numel(d), rows(end+1,:)={d(k).Severity,d(k).Message,d(k).Identifier}; end %#ok<AGROW>
            for k=1:numel(f), rows(end+1,:)={f(k).Severity,[f(k).Type ': ' f(k).Signal],'MILDebuggerPro:Anomaly'}; end %#ok<AGROW>
            app.DiagnosticsTable.Data=rows;
        end

        function traceSelection(app)
            if isempty(app.BlockTree.SelectedNodes), return; end
            p=app.BlockTree.SelectedNodes(1).NodeData;
            app.DetailsArea.Value={['Selected: ' p], ...
                'Post-run trace is structural and evidence based.', ...
                'Live execution tracing is isolated behind ExecutionTraceManager.'};
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
            if isvalid(app.StatusLabel), app.StatusLabel.Text=char(string(msg)); drawnow limitrate; end
        end

        function closeApp(app)
            delete(app);
        end
    end
end
