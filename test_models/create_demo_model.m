function modelName=create_demo_model()
%CREATE_DEMO_MODEL Create a small model for MIL Debugger Pro validation.
modelName='MILDebuggerDemo';
if bdIsLoaded(modelName), close_system(modelName,0); end
new_system(modelName); open_system(modelName);
add_block('simulink/Sources/Sine Wave',[modelName '/Input']);
add_block('simulink/Math Operations/Gain',[modelName '/Gain'],'Gain','2');
add_block('simulink/Math Operations/Sum',[modelName '/Sum']);
add_block('simulink/Sinks/Scope',[modelName '/Scope']);
add_line(modelName,'Input/1','Gain/1');
add_line(modelName,'Gain/1','Sum/1');
add_line(modelName,'Gain/1','Sum/2');
add_line(modelName,'Sum/1','Scope/1');
set_param(modelName,'StopTime','1');
end
