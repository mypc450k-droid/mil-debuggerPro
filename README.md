# MIL Debugger Pro

Universal post-run MIL exploration and live debugging framework for MATLAB/Simulink R2024b.

**Vision: Simulate once. Debug everywhere.**

Target: MATLAB/Simulink R2024b, primary .mdl compatibility with .slx supported where the same APIs apply.

## Launch

Open the intended Simulink model and click inside its editor so it is the active Simulink context. From the repository root in MATLAB:

    addpath(genpath(pwd))
    rehash path
    clear classes
    app = MILDebuggerProApp();

The app resolves the model from the active Simulink editor context. It does not select the first arbitrary loaded block diagram.

## Core workflow

1. Resolve the active model.
2. Inventory blocks, signal lines and Stateflow structure.
3. Snapshot the original logging configuration.
4. Compile/update the model.
5. Run MIL once.
6. Cache the `SimulationOutput` and logged-signal index.
7. Select one or many blocks directly in the Simulink canvas with Ctrl+Click.
8. Use **Analyze Block I/O** to show cached inputs and outputs for those selected blocks.
9. Use the Signals & Graph tab when exact signal-level selection is needed.
10. Clear the I/O graph or signal graph and analyze another selection without rerunning MIL.

## Direct Simulink canvas selection

The primary workflow is to select blocks directly in the Simulink Editor. Hold **Ctrl** to select multiple blocks, then click **Use Model Selection** or **Analyze Block I/O**. The app reads the selected blocks from Simulink and maps their captured input and output lines from the cached MIL run.

The structural tree remains available for browsing Stateflow and model hierarchy, but it is not required to decide which block to analyze.

## Graph controls

- **Plot Selected Signals**: plot any number of cached signals together.
- **Select All Logged**: select every cached signal.
- **Clear Graph**: remove only the current plot.
- **Clear Signal Selection**: remove the current analysis selection while preserving the cached MIL session.
- **Time cursor**: inspect the nearest captured sample for the currently selected signals.

Selecting or plotting cached data never invokes `sim`.

## Stateflow

The Stateflow tab shows structural metadata for charts, states, transitions and Stateflow data. Transition condition, trigger, source, destination and variables are exposed where available.

Runtime transition outcomes are not fabricated. They are shown as runtime evidence only when actual simulation evidence has been captured.

## Multiple models

Click inside the intended Simulink model and press **Refresh**. If MATLAB cannot determine a unique active model, the app reports the ambiguity rather than guessing.

## Restore

**Restore** returns the model's original signal-logging configuration captured before MIL.

## After updating the repository

If MATLAB has an older class loaded:

    clear classes
    rehash path
    close all
    app = MILDebuggerProApp();

Verify the loaded class with:

    which MILDebuggerProApp -all

See `docs/USER_GUIDE.md`, `docs/ARCHITECTURE.md` and `docs/R2024B_API_NOTES.md`.
