# MIL Debugger Pro - User Guide

## MATLAB R2024b quick start

From the repository root:

    addpath(genpath(pwd))
    rehash path
    clear classes

Open the intended Simulink model, click inside it, and launch:

    app = MILDebuggerProApp();

Verify the loaded class if needed:

    which MILDebuggerProApp -all

## Recommended workflow: select blocks directly in the Simulink canvas

Do **not** use the left tree to decide which blocks to analyze.

1. Open your model in the Simulink Editor.
2. Select one block normally.
3. Hold **Ctrl** and select additional blocks.
4. Return to MIL Debugger Pro.
5. Click **Use Model Selection** if you want to confirm the selection.
6. Click **RUN MIL** once if you have not already created a cached session.
7. Click **Analyze Block I/O**.
8. The **Block I/O** tab shows:
   - captured input signals connected to the selected blocks
   - captured output signals produced by the selected blocks
   - source/destination block paths
   - signal names where available
9. Select a different group of blocks in Simulink and click **Analyze Block I/O** again. No simulation is run.
10. Click **Clear I/O Graph** when you want a clean analysis view.

## Why the exact block I/O mapping matters

The app no longer depends on a generic Signal 1, Signal 2, Signal 3 list to decide what a block means.

Before MIL, the logger assigns a unique internal logging name to each capturable signal line and retains:

- source block path
- source port number
- destination block path(s)
- original signal name
- exact line handle

After MIL, the cached logsout dataset is joined back to that topology. This allows a selected block to be analyzed by its actual connected I/O.

## One-run MIL workflow

1. Select the intended active model.
2. Click **RUN MIL**.
3. MIL Debugger Pro snapshots the original logging configuration.
4. It configures broad signal capture.
5. It compiles/updates the model.
6. It runs MIL once.
7. It caches SimulationOutput and the signal-to-block topology.
8. All later selection, plotting and analysis uses the cached run.

Selecting blocks or plotting data does not invoke sim.

## Block I/O tab

The tab has two graphs.

### Selected Block Inputs

Signals whose destination is one of the selected blocks.

### Selected Block Outputs

Signals whose source is one of the selected blocks.

For multiple selected blocks, the graphs contain the union of their captured inputs/outputs and the legend identifies source/destination paths.

## Signals & Graph tab

This remains available when you want exact signal-level analysis.

- Ctrl+Click multiple cached signals.
- **Plot Selected Signals** overlays them.
- **Select All Logged** selects all cached signals.
- **Clear Graph** removes the current signal graph.
- **Clear Signal Selection** starts a new signal analysis without rerunning MIL.
- The time cursor shows nearest captured values.

## Stateflow

The Stateflow tab exposes static metadata for charts, states, transitions and data. It does not claim that a transition executed unless runtime evidence has actually been captured.

## Logging coverage and limitations

Signal logging is not universal for every Simulink object. Some signal types and special block configurations cannot be captured through standard signal logging.

Therefore the app must report capture gaps rather than inventing values. A selected block can have an input/output that is structurally present but not observable in logsout.

For compiled port attributes such as dimensions and sample time, the model must be compiled/updated before querying compiled properties.

## Restore

Click **Restore** after analysis to restore the original signal logging configuration captured before MIL.

## Important distinction

The tool is designed around:

**select in model -> simulate once -> analyze cached evidence**

not:

**search a giant tree -> guess which signal belongs to a block**

The structural tree is retained for Stateflow and model browsing, but direct Simulink canvas selection is the primary block-analysis workflow.
