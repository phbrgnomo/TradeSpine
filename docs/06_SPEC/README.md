# Technical Specifications

Layer 6 translates approved ADR decisions and upstream requirements into component-level implementation contracts for downstream TDD.

## Current SPEC Set

| ID | Component | YAML | Readable |
| --- | --- | --- | --- |
| SPEC-01 | Strategy Authoring Surface | [YAML](SPEC-01_strategy_authoring_surface/SPEC-01_strategy_authoring_surface.yaml) | [Markdown](SPEC-01_strategy_authoring_surface/SPEC-01_strategy_authoring_surface.readable.md) |
| SPEC-02 | Trade Coordination Pipeline | [YAML](SPEC-02_trade_coordination_pipeline/SPEC-02_trade_coordination_pipeline.yaml) | [Markdown](SPEC-02_trade_coordination_pipeline/SPEC-02_trade_coordination_pipeline.readable.md) |
| SPEC-03 | Guarded Execution and Risk Controls | [YAML](SPEC-03_guarded_execution_and_risk_controls/SPEC-03_guarded_execution_and_risk_controls.yaml) | [Markdown](SPEC-03_guarded_execution_and_risk_controls/SPEC-03_guarded_execution_and_risk_controls.readable.md) |
| SPEC-04 | Position Account Mode and State | [YAML](SPEC-04_position_account_mode_and_state/SPEC-04_position_account_mode_and_state.yaml) | [Markdown](SPEC-04_position_account_mode_and_state/SPEC-04_position_account_mode_and_state.readable.md) |
| SPEC-05 | Persistence and Audit Evidence | [YAML](SPEC-05_persistence_and_audit_evidence/SPEC-05_persistence_and_audit_evidence.yaml) | [Markdown](SPEC-05_persistence_and_audit_evidence/SPEC-05_persistence_and_audit_evidence.readable.md) |
| SPEC-06 | Market Session and Symbol Context | [YAML](SPEC-06_market_session_and_symbol_context/SPEC-06_market_session_and_symbol_context.yaml) | [Markdown](SPEC-06_market_session_and_symbol_context/SPEC-06_market_session_and_symbol_context.readable.md) |
| SPEC-07 | Indicators Stops Sizing and Trailing | [YAML](SPEC-07_indicators_stops_sizing_trailing/SPEC-07_indicators_stops_sizing_trailing.yaml) | [Markdown](SPEC-07_indicators_stops_sizing_trailing/SPEC-07_indicators_stops_sizing_trailing.readable.md) |
| SPEC-08 | Release Testing and Documentation Governance | [YAML](SPEC-08_release_testing_and_documentation_governance/SPEC-08_release_testing_and_documentation_governance.yaml) | [Markdown](SPEC-08_release_testing_and_documentation_governance/SPEC-08_release_testing_and_documentation_governance.readable.md) |
| SPEC-09 | Core Runtime and Configuration | [YAML](SPEC-09_core_runtime_and_configuration/SPEC-09_core_runtime_and_configuration.yaml) | [Markdown](SPEC-09_core_runtime_and_configuration/SPEC-09_core_runtime_and_configuration.readable.md) |
| SPEC-10 | Visualization Optional Services | [YAML](SPEC-10_visualization_optional_services/SPEC-10_visualization_optional_services.yaml) | [Markdown](SPEC-10_visualization_optional_services/SPEC-10_visualization_optional_services.readable.md) |
| SPEC-11 | Testing Support and Harnesses | [YAML](SPEC-11_testing_support_and_harnesses/SPEC-11_testing_support_and_harnesses.yaml) | [Markdown](SPEC-11_testing_support_and_harnesses/SPEC-11_testing_support_and_harnesses.readable.md) |

## Gate Status

- Corpus audit: [SPEC-00.A v005 PASS](SPEC-00.A_audit_report_v005.md)
- Code-deliverable SPEC documents include BRD, PRD, EARS, BDD, ADR, SPEC, and TDD trace tags. SPEC-08 is documentation/process governance scope and intentionally has no TDD/IPLAN artifact.
- All SPEC documents include C4-L3 and DFD-L3 diagram tags.
- All SPEC documents meet the TDD-ready threshold of 90/100.

## Next Layer

Generate or refresh TDD for code-deliverable SPEC-01 through SPEC-07 and SPEC-09 through SPEC-11 after SPEC approval. Do not generate TDD-08 unless SPEC-08 is split into a code-deliverable SPEC.
