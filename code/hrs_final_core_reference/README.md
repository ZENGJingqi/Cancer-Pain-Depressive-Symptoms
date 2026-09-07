# HRS Final Core endpoint update reference code

These are exact selected source snapshots from the independently human-operated HRS run completed on 7 September 2026. No data, completed imputations or fitted models are included.

## Safe synthetic test

From this folder, using R with data.table, mice, survey, splines and digest installed:

```sh
Rscript scripts/96_test_final_core_update_synthetic.R
```

This generates synthetic records only, tests four models with m=2 and 50 iterations, and verifies logical/numeric event equivalence, missing outcomes, duplicate IDs, death conflicts and unchanged earlier outcomes. It does not reproduce the real study estimates. The real run used m=20 and 50 iterations.

## Real-data use is separate

`HRS_local_run_package/final_core_update.R` defines the update functions. It selects named function definitions from scripts 27 and 39 without running their top-level data-loading code. Other source modules retain historical functions that are not part of this update. Do not execute scripts 27 or 39 directly from this public checkout.

The sources preserve original project-relative inputs and machine-specific paths to document what ran. They need an independently authorized, compliant local project containing the frozen study-specific risk sets and official Final Core archive. This is not a standalone raw-data-to-results package and is not a universal data-access grant. Do not execute on registered participant records through AI-connected tools. Provider terms govern use and redistribution.

No real-data launcher is distributed here. Participant-level output belongs outside this public repository. `LOCAL_ONLY`, RDS objects, source archives and private logs must never be committed.

## Scope and statistical differences

The update replaces the 2022 CES-D endpoint, rebuilds final-interval retention weights, and fits symptom onset, symptom persistence and their two symptom-or-death composites. Earlier baseline fields and intervals remain unchanged. Death tracking still uses archived RAND information, not a refreshed Final Tracker.

The newly exported absolute risks and risk differences use **Poisson standardization** with coefficient-covariance delta variances. The v0.9 manuscript Table 3 uses **logistic standardization**; these new files must not silently replace that table. Private prediction-domain checks remain outstanding.

Additional HRS sensitivity/extension models, updated multicohort synthesis and a fully reconciled manuscript are not supplied as completed analyses by this snapshot. See the root STATUS.md.
