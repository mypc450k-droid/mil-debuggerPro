# MIL Debugger Pro - User Guide

## MATLAB R2024b quick start

From the repository root:

    addpath(genpath(pwd))
    rehash path
    clear classes

Open the intended Simulink model and click inside its editor. Then launch:

    app = MILDebuggerProApp();

If MATLAB still resolves an older copy:

    which MILDebuggerProApp -all

The first result should point to this repository.

## One-run MIL workflow

1. Click **RUN MIL**.
2. MIL Debugger Pro resolves the active Simulink model, configures capture, compiles/updates it and runs MIL once.
3. The resulting `SimulationOutput` and signal index are cached in the session.
4. Selecting blocks or Stateflow elements does not call `sim`.
5. Switching models invalidates the old session. Run MIL again for the new model.

## Selecting multiple model elements

The left **Model Explorer** is a standard R2024b tree with multi-selection.

- Hold **Ctrl** and click multiple blocks.
- Expand **Stateflow** to see charts, states, transitions and logged-data metadata.
- Select as many elements as needed.
- Click **Analyze Tree Selection** to map selected elements to cached logged signals.
- If an element cannot be mapped automatically, use the exact **Cached logged signals** list in the Signals & Graph tab.

The tree selection is an analysis selection. It does not rerun the model.

## Selecting and plotting logged signals

After MIL completes, the **Signals & Graph** tab lists every signal found in the cached `logsout` dataset.

- Hold **Ctrl** and select any number of signals.
- **Plot Selected Signals** overlays the selected signals on one graph.
- **Select All Logged** selects every cached signal.
- **Clear Graph** removes the current plot only. Cached MIL data remains.
- **Clear Signal Selection** removes the current signal/model selection so a new analysis can be started.
- The **Time cursor** field shows the selected signals' values at the nearest captured sample.

This is the most reliable path for exact signal selection because the list comes directly from the cached simulation output.

## Stateflow

The Stateflow tab exposes static chart/state/transition metadata from the Stateflow API, including transition condition, trigger, source, destination and variables extracted from labels.

Runtime transition outcomes are not claimed unless runtime evidence was actually captured. The current MIL capture path does not fabricate a transition timeline.

## Restore

Click **Restore** after analysis to restore the model's original signal-logging configuration captured before MIL.

## Important limitation

The current logger is best-effort across Simulink block types. A model element can exist in the explorer without having a directly associated logged signal. In that case the app says so and keeps the exact cached signal list available for manual selection rather than inventing data.
