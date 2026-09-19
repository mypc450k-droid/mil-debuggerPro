function app=MILDebuggerPro()
%MILDEBUGGERPRO Launch MIL Debugger Pro services.
% The production App Designer UI is being built incrementally around these
% tested services. This entry point initializes the complete service graph.

app=struct();
app.Title=mildebug.MILDebuggerProConfig.AppTitle;
app.Version='0.1.0';
app.ModelManager=mildebug.ModelManager();
app.Discovery=mildebug.ModelDiscovery();
app.Compiler=mildebug.ModelCompiler();
app.Logging=mildebug.LoggingManager();
app.Simulation=mildebug.SimulationManager();
app.SessionManager=mildebug.DebugSessionManager();
app.SignalRepository=mildebug.SignalRepository();
app.StateRepository=mildebug.StateRepository();
app.StateflowAnalyzer=mildebug.StateflowAnalyzer();
app.ExecutionTrace=mildebug.ExecutionTraceManager();
app.Breakpoints=mildebug.BreakpointManager();
app.Diagnostics=mildebug.DiagnosticsManager();
app.Comparison=mildebug.ComparisonEngine();
app.AnomalyDetector=mildebug.AnomalyDetector();
app.Trace=mildebug.TraceEngine();
app.Plot=mildebug.PlotEngine();
app.Navigator=mildebug.ModelNavigator();
app.Report=mildebug.ReportGenerator();
app.Export=mildebug.ExportManager();
app.Compatibility=mildebug.CompatibilityManager();

fprintf('\n%s %s\n',app.Title,app.Version);
r=app.Compatibility.check();
fprintf('Target: %s | Current: %s | Supported target: %d\n',r.Target,r.CurrentRelease,r.Supported);
model=app.ModelManager.detectActiveModel();
if isempty(model)
    fprintf('No active Simulink model detected. Open a model and call MILDebuggerPro again.\n');
else
    fprintf('Active model: %s\n',model);
end
end
