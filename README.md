# MIL Debugger Pro

Universal post-run MIL exploration and live debugging framework for MATLAB/Simulink R2024b.

**Vision: Simulate once. Debug everywhere.**

Target: MATLAB/Simulink R2024b, primary .mdl compatibility with .slx supported where the same APIs apply.

## Launch

Open the intended Simulink model and click inside its editor so it is the active Simulink context. Then, from the repository root in MATLAB:

    addpath(genpath(pwd))
    rehash path
    clear classes
    app = MILDebuggerProApp();

The app resolves the model from the active Simulink editor context. It does not select the first arbitrary loaded block diagram.

## Core workflow
1. Resolve the active model from the Simulink editor.
2. Inventory the model hierarchy and signal lines.
3. Snapshot logging configuration.
4. Compile/update the model.
5. Run MIL once.
6. Cache SimulationOutput and derived indexes.
7. Select any block and inspect cached evidence without rerunning.
8. Inspect plots, samples, diagnostics, Stateflow metadata and structural traces.

## If multiple models are open

Click inside the intended Simulink model window, then press **Refresh** in MIL Debugger Pro. If MATLAB does not expose an active model context, the app reports the ambiguity instead of guessing.

## After updating the repository

If MATLAB still has the old class loaded, run:

    clear classes
    rehash path
    close all
    app = MILDebuggerProApp();

## Engineering principles
- Selecting a block never calls sim.
- Original logging configuration can be restored.
- Capture limitations are reported explicitly.
- Static Stateflow metadata is never presented as runtime transition evidence.

See docs/ARCHITECTURE.md, docs/R2024B_API_NOTES.md and docs/USER_GUIDE.md.
