# MIL Debugger Pro

Universal post-run MIL exploration and live debugging framework for MATLAB/Simulink R2024b.

**Vision: Simulate once. Debug everywhere.**

Target: MATLAB/Simulink R2024b, primary .mdl compatibility with .slx supported where the same APIs apply.

## Launch

Open your Simulink model, then:

    addpath(genpath('mil-debuggerPro'))
    app = MILDebuggerProApp();

## Core workflow
1. Detect the currently open model.
2. Inventory the model hierarchy and signal lines.
3. Snapshot logging configuration.
4. Compile/update the model.
5. Run MIL once.
6. Cache SimulationOutput and derived indexes.
7. Select any block and inspect cached evidence without rerunning.
8. Inspect plots, samples, diagnostics, Stateflow metadata and structural traces.

## Engineering principles
- Selecting a block never calls sim.
- Original logging configuration can be restored.
- Capture limitations are reported explicitly.
- Static Stateflow metadata is never presented as runtime transition evidence.

See docs/ARCHITECTURE.md, docs/R2024B_API_NOTES.md and docs/USER_GUIDE.md.
