# MIL Debugger Pro - User Guide

## Quick start

Open a Simulink model in MATLAB R2024b:

    addpath(genpath('mil-debuggerPro'))
    app = MILDebuggerPro();

The service layer detects the active model and initializes the debugger graph.

## Design contract

Run MIL once. Block selection and analysis consume the cached DebugSession and do not invoke sim.

## Trust model

The tool distinguishes runtime evidence, static metadata and unsupported cases. It never fabricates values or transition outcomes.

## Test model

Run:

    addpath(genpath('test_models'))
    modelName = create_demo_model();

Then exercise discovery and simulation locally in MATLAB R2024b.
