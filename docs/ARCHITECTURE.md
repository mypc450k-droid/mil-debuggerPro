# Architecture

MIL Debugger Pro is layered so App Designer UI code does not own simulation logic.

Core flow:
ModelManager -> ModelDiscovery -> ModelCompiler -> LoggingManager -> SimulationManager -> DebugSessionManager

Analysis:
SignalRepository, StateRepository, StateflowAnalyzer, ExecutionTraceManager, DiagnosticsManager, ComparisonEngine, AnomalyDetector, TraceEngine.

UI/support:
PlotEngine, ModelNavigator, ReportGenerator, ExportManager, CompatibilityManager.

Rules:
- Selecting a block never starts simulation.
- Original model configuration is snapshotted and restored.
- Every discovered object gets an internal ID.
- Expensive queries are cached.
- Capture coverage and limitations are explicit.
- Runtime claims require runtime evidence.

Two modes:
1. Post-run analysis using cached data.
2. Explicit live debugging through a dedicated adapter.
