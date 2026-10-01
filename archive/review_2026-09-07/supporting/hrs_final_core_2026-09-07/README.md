# HRS Final Core endpoint results from 7 September 2026

Four independently human-operated analyses completed using the 2022 Final Core V2.0 CES-D endpoint. The original Core archive SHA256 is recorded in input_hashes.csv; participant records are not included. Death status remains from archived RAND tracking.

Each analysis has 20 newly created imputations and 50 iterations. Published files contain aggregate estimates, per-imputation effect estimates (not imputed records), model degrees of freedom, total analytic sample sizes and disclosure-screened diagnostic summaries. Chains describe aggregate imputation statistics, not participants. No suppressed distribution is reconstructed or released.

RR uses finite complete-data residual degrees of freedom in Barnard–Rubin pooling. `risks` and `risk_differences` are **Poisson-standardized**, with arithmetic verified but private prediction-domain QA not yet reviewed. They do **not** replace the logistic-standardized absolute-risk table in manuscript v0.9.

The 56 pooled rows passed independent arithmetic checks. Twenty RR contrasts changed by at most 0.432% relative to the prior 50-iteration summary; CI inclusion of one did not change. Samples differ from the older manuscript and extensions. These comparisons do not isolate a pure version effect because sample construction, weights, random imputation and interval methods also differ.

Five distribution/model combinations remain suppressed. Fifteen run warnings were not individually reviewed; zero imputation loggedEvents is not equivalent to zero warnings. No claim of complete scientific validation or submission readiness is made.

Run `Rscript code/audit_hrs_final_core_summaries.R` from the repository root for the aggregate-only audit. See `../hrs_final_core_audit/` for the retained arithmetic results and `../../STATUS.md` for outstanding tasks.
