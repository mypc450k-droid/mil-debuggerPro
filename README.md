# MIL Debugger Pro

Universal post-run MIL exploration and live debugging framework for MATLAB/Simulink R2024b.

**Vision: Simulate once. Debug everywhere.**

Target: MATLAB/Simulink R2024b, primary .mdl compatibility with .slx supported where the same APIs apply.

## First workflow
1. Open a Simulink model.
2. Launch `MILDebuggerPro`.
3. Run MIL once.
4. Inspect discovered blocks/signals without rerunning.
5. Use cached analysis and a synchronized time cursor.

The implementation reports capture coverage and never fabricates unsupported runtime evidence.