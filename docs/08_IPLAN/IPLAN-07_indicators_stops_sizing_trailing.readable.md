# IPLAN-07: Indicators, Stops, Sizing and Trailing

> Direct readable companion of `IPLAN-07_indicators_stops_sizing_trailing.yaml`. The canonical YAML remains authoritative.

## Document Control

| Field | Value |
| --- | --- |
| Status | Draft |
| Version | 1.3 |
| Component | IIndicator, stop, sizing, and trailing policy modules |
| Source | @spec: SPEC-07 / @tdd: TDD.07.04.a6d8 |
| Updated | 2026-08-28T19:45:00-03:00 |
| Planned files | 18 |

## Planned Layout

| Order | Path | Purpose |
| --- | --- | --- |
| 1–3 | `Scripts/Tests/Test_Indicators.mq5`, `Test_Sizers.mq5`, `Test_StopsAndTrailing.mq5` | Focused policy tests, written before implementation. |
| 4 | `Include/Indicators/IndicatorBase.mqh` | Generic lifecycle/readiness/value interface. |
| 5 | `Include/Indicators/NativeIndicators.mqh` | Native ATR and MA adapters. |
| 6–7 | `Include/Indicators/Custom/IndDonchian.mqh`, `IndSupertrend.mqh` | Separate custom algorithms. |
| 8 | `Include/Indicators/Indicators.mqh` | Include-only facade across all adapters. |
| 9 | `Include/Strategy/PolicyTypes.mqh` | IPLAN-07-owned requests/results and account-value seam. |
| 10–12 | `Include/Strategy/{Stops,Sizing,Trailing}/*.mqh` | Broker-pure policy implementations. |
| 13–14 | `Scripts/Tests/Support/FakeIndicatorRuntime.mqh`, `FakeAccountValueProvider.mqh` | Deterministic runtime and equity fakes. |
| 15 | `Docs/MODULES/IndicatorsStopsSizingTrailing.md` | Delivered module reference after implementation. |
| 16 | `Scripts/Tests/RunAllTests.mq5` | Aggregate reachability update. |
| 17–18 | `docs/08_IPLAN/IPLAN-00_index.yaml`, this readable file | Completion registry and readable reconciliation. |

## Contract Boundaries

- `PolicyTypes.mqh` owns `StopRequest`, `StopLevels`, `SizingRequest`, `TrailingRequest`, and `IndicatorValue`; no policy interface depends on IPLAN-02 `Signal`.
- Indicators are wrappers because MT5 native indicators are handle-based and need uniform readiness/lifecycle/error behavior plus deterministic runtime tests. Native ATR/MA share one module; custom algorithms remain separate because their buffers/calculations differ; the facade provides one consumer include.
- Stop, sizing, and trailing policies propose values only. Later accepted mutations route through `ITradeExecutor::ModifyTicket`.
- Risk sizing reads equity through an injected provider and delegates pure calculation to `SizingMath`; it does not perform implicit account lookup.

## Execution and Gate Conditions

- No IPLAN-07 implementation source is created by CHG-25.
- CHG-25 GATE-06, GATE-08, and GATE-CODE were approved by explicit user authorization on 2026-08-28. IPLAN-07 remains Draft and begins only on a separate implementation instruction; this is not production authorization.
- During implementation: use manual MetaEditor F7 for each focused suite and the aggregate runner; record fresh compile and MT5 runtime evidence separately.

## Traceability

`@iplan: IPLAN-07`, `@spec: SPEC-07`, `@tdd: TDD.07.04.a6d8`, `@chg: CHG-25`
