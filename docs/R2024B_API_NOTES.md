# R2024b API notes

The foundation targets documented MATLAB/Simulink R2024b mechanisms.

Discovery uses bdIsLoaded, bdroot, find_system, get_param, set_param and load_system.

Simulation uses sim and Simulink.SimulationOutput.

Post-run signal data is expected through Simulink.SimulationData.Dataset and its logged elements.

Important limitation:
Not every Simulink block exposes a conventional signal object suitable for logsout. Therefore capture is modeled as capabilities rather than a blanket promise that every block is represented by ordinary signal logging.

Stateflow runtime truth is only reported when execution evidence is actually captured. Static transition labels are not treated as runtime truth.

Live debugging is intentionally isolated from cached post-run analysis.
