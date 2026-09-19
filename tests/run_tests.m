function results=run_tests()
%RUN_TESTS Core framework smoke tests.
results=struct();
results.Config=~isempty(mildebug.MILDebuggerProConfig.SupportedRelease);
results.ModelManager=~isempty(mildebug.ModelManager());
results.ModelDiscovery=~isempty(mildebug.ModelDiscovery());
results.LoggingManager=~isempty(mildebug.LoggingManager());
results.SimulationManager=~isempty(mildebug.SimulationManager());
sf=mildebug.StateflowAnalyzer();
p=sf.parseTransitionLabel('[Speed > Threshold && Enable == true]');
results.StateflowParser=all(ismember({'Speed','Threshold','Enable'},p.Variables));
results.AllBasic=all(struct2array(results));
disp(results);
end
