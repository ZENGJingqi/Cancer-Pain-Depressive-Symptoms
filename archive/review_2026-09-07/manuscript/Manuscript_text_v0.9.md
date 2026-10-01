# Current pain and cancer history in depressive symptom transitions across three ageing cohorts

Status: public repository review v0.9; official SHARE design sensitivity and final scientific review remain outstanding
Study ID: `cpd_multicohort_01`  
Draft date: 6 September 2026

## Abstract

### Background

Cancer history and current pain represent different dimensions of illness burden. Their associations with later depressive symptoms may depend on the baseline symptom state and whether death is included in the outcome.

### Aim

To compare cancer-pain phenotypes across depressive-symptom onset and persistence, and assess the limits of symptom-based comparisons when death is included.

### Methods

We conducted coordinated prospective analyses of adults aged at least 50 years in HRS, SHARE, and CHARLS. Four baseline phenotypes combined cancer history and current pain. Survey-weighted modified Poisson models estimated next-wave risk ratios (RRs), with random-effects synthesis of prespecified contrasts. Additional sensitivity analyses directly compared pain only with cancer only and examined high symptoms or death.

### Results

Onset models included 141,756 person-intervals and 19,913 events; persistence models included 43,230 intervals and 24,548 events. Cancer and pain versus neither yielded pooled RRs of 1.42 (95%CI 1.17-1.72) for onset and 1.21 (1.04-1.41) for persistence. Pain-only associations were also reproducible, but direct pain-only versus cancer-only differences were not uniform. In HRS, the onset RR was 1.36 (1.17-1.59), compared with 0.94 (0.85-1.05) for the onset-population composite. SHARE composite RRs were close to one; CHARLS contrasts remained positive but involved sparse cancer groups. Composite analyses also differed in weighting and observed populations.

### Conclusion

Current pain marks subsequent depressive-symptom burden among surviving respondents. It does not consistently identify greater risk than cancer history alone when death is included. These associations do not establish prediction superiority, equivalence, or causal effects.

Keywords: Cancer history; Pain; Depressive symptoms; Symptom persistence; Ageing; Multicohort study

## Core Tip

Current pain was associated with subsequent high depressive symptoms across three ageing cohorts. However, direct comparisons with cancer history alone depended on the symptom transition and outcome definition. When death was included, pain-only versus cancer-only estimates were close to one in HRS and SHARE; CHARLS contrasts remained positive but imprecise in small cancer groups. Symptom-transition associations among survivors should therefore not be generalized to an overall health-risk ranking. Composite analyses also changed weights and samples and did not isolate the effect of survival selection.

## Introduction

Cancer care increasingly recognises anxiety and depression as outcomes requiring systematic identification and stepped management [1,2]. That clinical priority is often operationalised from the diagnosis outward: a history of cancer marks a population for psychological vigilance. However, cancer history is an unusually heterogeneous risk label. In a linked-record study of more than 850,000 cancer survivors, mental-health risk varied substantially by cancer site, prognosis, and time since diagnosis [3]; recent umbrella-review evidence likewise found considerable heterogeneity in pain, depression, and anxiety across cancer populations [4]. The unresolved problem is therefore not whether cancer can be psychologically consequential, but whether a broad history-of-cancer indicator adequately represents near-term psychological vulnerability after the person's current symptom state is taken into account.

A symptom-centred approach offers a different source of information. Pain is current, clinically visible, and potentially connected to mobility restriction, sleep disruption, reduced activity, loss of independence, social withdrawal, and continuing illness threat. Among older adults with gastrointestinal malignancies, moderate-to-severe pain was strongly associated with functional limitation, anxiety, and depression [5]. Across seven cancer types, pain also clustered with fatigue, sleep disturbance, and depression in distinct symptom-burden profiles [6]. These findings show that pain helps characterise heterogeneity within cancer populations, but most oncology evidence is cross-sectional or concentrated near active treatment. It remains uncertain whether a simple pain indicator differentiates later psychological states in community-dwelling adults with and without a cancer history.

Longitudinal ageing research already establishes the broader pain–depression association. SHARE data showed graded increases in two-year depression risk across mild, moderate, and severe pain [7]. Coordinated evidence from England and China supported a longitudinal relationship [8], while later analyses found that persistent or worsening pain trajectories predicted incident depressive symptoms in the United Kingdom and the United States [9]. A five-wave CHARLS analysis further suggested that pain burden more consistently preceded later depressive symptoms than the reverse pathway [10]. These studies make a simple demonstration that pain predicts depression insufficient as a contribution. The more consequential question is whether current pain provides prospective risk information that is more consistent across settings than a historical cancer label.

That comparison should also distinguish two transitions that are often conflated. Onset among people initially below a symptom threshold concerns entry into a high-symptom state; persistence among those already above it concerns failure to leave that state. A marker observed across both transitions may be relevant to repeated assessment, although relative effects need not be identical because baseline risk and symptom history differ. In addition, threshold-based associations may partly reflect overlapping somatic content or functional burden. Absolute risks, pain-burden gradients, sequential functional adjustment, and depressive-symptom scores reconstructed without the sleep item can test whether the interpretation survives these alternative explanations.

We therefore conducted coordinated prospective analyses in HRS, SHARE, and CHARLS. Within each cohort, we harmonized four baseline phenotypes—neither cancer nor pain, cancer only, pain only, and cancer with pain—and examined their associations with next-wave onset and persistence of elevated depressive symptoms. The onset estimand and its focal contrasts were prespecified in SAP v1.0; before inspecting persistence-effect estimates, we froze SAP v1.1 defining the expanded estimand and supporting analyses. We hypothesised that adjusted associations for pain-related phenotypes would be reproducible across cohorts and both state transitions, whereas cancer history alone would show a less consistent pattern. We use ‘consistency’ descriptively to mean reproducibility of direction, precision, and interval estimates across settings and estimands; it is not a claim of superior predictive performance. We treated cancer–pain interaction as an empirical boundary question rather than assuming biological synergy.

## Materials and Methods

### Study design and reporting framework

This study used a coordinated multicohort prospective design based on repeated observations from three population-based studies of ageing: the Health and Retirement Study (HRS) in the United States, the Survey of Health, Ageing and Retirement in Europe (SHARE), and the China Health and Retirement Longitudinal Study (CHARLS) [11-13]. The substantive question, exposure definitions, outcome hierarchy, and minimum adjustment set were aligned across cohorts, but each cohort was reconstructed and analysed separately under its own measurement and sampling structure. Individual-level records and survey weights were not pooled across studies. The primary unit of analysis was the person-interval: exposure and baseline covariates were measured at one interview, and depressive symptoms were evaluated at the next eligible interview. Reporting follows the STROBE recommendations for observational cohort studies [18].

### Data sources, products, and observation windows

HRS is a biennial longitudinal study of US adults over age 50 and their spouses. The present analyses used the RAND HRS Longitudinal File 2022 (Version 1) together with the 2012, 2014, 2016, 2018, 2020, and 2022 RAND HRS Fat Files. Product descriptions and documentation are available from the [official RAND HRS products page](https://hrsdata.isr.umich.edu/data-products/rand). The analysed person-intervals were 2012-2014, 2014-2016, 2016-2018, 2018-2020, and 2020-2022. Cancer history and harmonized sociodemographic variables were obtained from the RAND longitudinal file; current pain, pain severity, depressive-symptom items, interview status, and survey-design fields were verified against the relevant biennial files. The 2022 RAND Fat File used in the current frozen analysis is release E.3A, and the 2022 components of the RAND longitudinal product are based on Early Release material. If this analysis version is retained at submission, the mandatory Early Release acknowledgement specified in the [HRS Conditions of Use](https://hrsdata.isr.umich.edu/data-products/conditions-of-use) will be included, and the sensitivity analysis excluding 2020-2022 will remain reported.

SHARE is a multidisciplinary longitudinal study of adults aged 50 years or older and their partners across European countries and Israel. We used Gateway Harmonized SHARE G, based on SHARE Release 9.0.0, together with the corresponding official longitudinal-weight files. The primary intervals were Waves 5-6 and 8-9. Waves 6-8 were reserved for sensitivity analysis because this interval was longer and did not have a directly released pair-specific longitudinal weight. Release documentation and dataset identifiers are available through the [SHARE data documentation portal](https://www.share-eric.eu/data/data-documentation), and registered-user access is provided through the [SHARE Research Data Center](https://www.share-eric.eu/data/data-access). Gateway Harmonized SHARE is an ex-post harmonized derivative intended to support cross-study comparison; its variables were checked against the SHARE release documentation, and the SHARE Conditions of Use continued to apply.

CHARLS is a nationally representative longitudinal study of Chinese residents aged 45 years or older. We used the original 2011, 2013, 2015, and 2018 wave files, with Harmonized CHARLS Version D used to support cross-wave mapping. The analysed intervals were 2011-2013, 2013-2015, and 2015-2018. Core variables were checked against the original wave files, labels, release notes, and user guides rather than relying solely on harmonized variables. Official materials and registered-user downloads are available for [Wave 1 (2011)](https://charls.pku.edu.cn/en/Data/a2011_CHARLS_Wave1__Baseline_.htm), [Wave 2 (2013)](https://charls.pku.edu.cn/en/Data/a2013_CHARLS_Wave2.htm), [Wave 3 (2015)](https://charls.pku.edu.cn/en/Data/a2015_CHARLS_Wave_3.htm), and [Wave 4 (2018)](https://charls.pku.edu.cn/en/Data/a2018_CHARLS_Wave_4.htm). The 2020 wave was not included because the locally archived harmonized product ended in 2018 and incorporating a separately released pandemic-period wave would have changed the measurement and source-version framework.

### Participants and person-interval construction

Eligible baseline observations were restricted to respondents aged 50 years or older who completed an interview and had ascertainable cancer history, current pain, and depressive-symptom status. The primary estimand concerned onset of elevated depressive symptoms: person-intervals entered this analysis when the baseline symptom score was below the cohort-specific threshold, and the outcome was whether the score crossed the threshold at the next eligible wave. The important secondary estimand concerned persistence: person-intervals entered this analysis when the baseline score was at or above the threshold, and the outcome was whether the score remained at or above the threshold at follow-up. This distinction separated entry into a high-symptom state from failure to leave that state.

Recorded deaths before the subsequent interview were reported as a distinct follow-up state and excluded before modelling non-response among survivors. We did not estimate a competing-risk cumulative incidence; the target estimand was next-wave depressive-symptom transition among people surviving to the follow-up wave. Surviving respondents with no observed follow-up outcome contributed to interval-specific retention models but not to outcome models. Respondents could contribute more than one eligible interval; estimates therefore describe next-wave risk among eligible person-intervals rather than first-ever lifetime incidence or persistence. Respondent identifiers were included in the survey design to account for repeated contributions. A prespecified sensitivity analysis retained only the first eligible interval per respondent.

### Cancer-pain phenotypes

At each interval baseline, participants were assigned to one of four mutually exclusive phenotypes: neither cancer nor pain, cancer only, pain only, or cancer and pain. Cancer was defined as a harmonized history of physician-diagnosed cancer; the HRS definition excluded non-melanoma skin cancer according to the RAND coding. Pain was defined from the cohort-specific item indicating current pain or being often troubled by pain. The exposure was intentionally based on current pain rather than inferred pain aetiology. Cancer site, stage, treatment, recurrence, and time since diagnosis were not consistently available across the three cohorts, while pain duration and interference were not measured comparably. Accordingly, the exposure is described as any cancer history and current pain, not active cancer, gastrointestinal cancer, chronic pain, cancer pain, or treatment-related pain.

### Depressive-symptom outcomes

Elevated depressive symptoms were defined using established cohort-specific thresholds: an eight-item Center for Epidemiologic Studies Depression score (CES-D-8) of at least 4 in HRS, a EURO-D score of at least 4 in SHARE, and a ten-item CES-D score (CES-D-10) of at least 10 in CHARLS [14,15]. Baseline depressive-symptom score was included continuously in every adjusted model. The outcomes are termed onset and persistence of elevated depressive symptoms rather than incident or persistent clinical depression because the cohorts did not use a common diagnostic interview.

To assess whether associations were driven by overlapping somatic content, item-level symptom scores were reconstructed and the sleep item was removed from each scale. Reconstructed full scores were required to agree with the released or harmonized score before reduced scores were used. The reduced follow-up score was standardized within cohort and modelled with adjustment for the corresponding standardized baseline score.

### Pain-burden measures

The primary four-phenotype exposure used a binary pain indicator to maximize comparability. Supporting analyses used the more detailed pain information available within each cohort. HRS and SHARE pain severity was categorized as no, mild, moderate, or severe pain. CHARLS pain burden was categorized by the number of reported painful body sites as none, one, two, or three or more. Because pain severity and painful-site count are not equivalent constructs, these gradients were analysed and interpreted within cohort and were not combined in meta-analysis. Pain-burden models adjusted for cancer history and the common covariate set.

### Covariates

The minimum common adjustment set was defined before formal modelling and included age represented by a natural spline with three degrees of freedom, sex, education (three levels), partnered status, continuous baseline depressive-symptom score, number of non-cancer chronic conditions, current smoking, within-interval wealth quintile, and interval indicators. SHARE models additionally included country fixed effects. The non-cancer condition count comprised hypertension, diabetes, chronic lung disease, heart disease, stroke, and arthritis. Body mass index and alcohol use were not included in the common set because their availability and measurement were not sufficiently uniform across waves.

Covariates were selected to address plausible common causes of cancer history, pain, and depressive symptoms while avoiding routine adjustment for variables that could be consequences of pain or illness. Mobility limitations and limitations in activities of daily living were therefore added sequentially only in explanatory secondary models. Attenuation after functional adjustment was not interpreted as a causal mediation effect because exposure, function, and baseline depressive symptoms were measured contemporaneously.

### Survey design, weighting, and attrition

All analyses retained cohort-specific survey structure. HRS models used the interval-baseline response weight multiplied by an interval-specific inverse probability of follow-up observation among survivors and incorporated HRS standard-error strata, half-sample clusters, and respondent identifiers. SHARE primary intervals used the released calibrated pair-specific longitudinal respondent weights and incorporated country strata plus household and respondent clustering. CHARLS 2011-2013 used the released individual longitudinal weight; later intervals used the baseline individual survey weight multiplied by an interval-specific retention factor and incorporated community and respondent clustering.

Retention models were estimated separately by interval among respondents alive at follow-up. Predictors were age, sex, education, partnered status, cancer-pain phenotype, baseline depressive-symptom score, non-cancer comorbidity count, smoking, and wealth. Predicted observation probabilities were bounded at 0.05-0.99; inverse-probability factors were truncated at the interval-specific 1st and 99th percentiles; and final weights were normalized to mean one within interval. Recorded deaths were not modelled as ordinary attrition. Because official SHARE longitudinal weights were highly right-skewed in some intervals, an additional persistence sensitivity analysis trimmed final weights at the 1st and 99th percentiles.

Variance estimation used the with-replacement first-stage approximation without finite-population corrections. Respondent identifiers were listed at a subsequent clustering stage; this did not supply a separate lower-stage variance component under that approximation. For SHARE, the first-stage clusters in the reported models were households rather than the newly obtained official PSUs. Official-design sensitivity estimates are not included in the present results.

### Missing data

Follow-up outcomes, cancer history, current pain, and final analysis weights were not imputed. Covariates were multiply imputed separately within each cohort using chained equations with 20 imputations when the extent of missingness justified imputation [16]. The onset analysis used multiple imputation in HRS and CHARLS and complete covariate records in SHARE, where covariate missingness was minimal. The independently specified persistence analysis used 20 imputations in all three cohorts because SHARE wealth missingness exceeded 1%. Complete-case and reduced-covariate models were prespecified as sensitivity analyses.

### Statistical analysis

Within each cohort and estimand, survey-weighted modified Poisson marginal models with a log link and design-based robust variance estimated adjusted risk ratios (RRs) [17]. The two prespecified focal contrasts were cancer and pain versus neither condition and cancer and pain versus cancer only. Pain only versus neither and cancer only versus neither were supporting contrasts used to determine whether any association pattern was anchored in cancer history, pain, or their co-occurrence. Cohort-specific log RRs were synthesized using restricted maximum-likelihood random-effects meta-analysis with Hartung-Knapp confidence intervals. Heterogeneity estimates and prediction intervals were interpreted cautiously because only three cohorts were available.

Comparative consistency was evaluated from the prespecified pattern of cohort-specific and pooled contrasts across onset and persistence, considering direction, confidence intervals, and heterogeneity. We did not fit a head-to-head clinical prediction model or compare discrimination, calibration, reclassification, or net benefit. Thus, more consistent refers to reproducibility of the adjusted association pattern rather than formal predictive superiority.

Cohort-specific adjusted absolute risks and risk differences were estimated by survey-weighted logistic marginal standardization using the same covariate set. Logistic standardization was used because direct standardization from log-link models generated a small number of individual predicted probabilities above one; the modified Poisson RRs remained the primary relative measures. Supporting analyses examined pain-burden gradients, sequential functional adjustment, complete-case samples, first eligible intervals, reduced covariate sets, alternative SHARE intervals and weight specifications, exclusion of pandemic-affected HRS intervals, reduced-item symptom scores, and final-weight trimming for persistence. Multiplicative and additive cancer-by-pain interaction analyses distinguished joint classification from statistical interaction. Limited effect-modification analyses examined sex and age group for the cancer-and-pain versus neither contrast; cohort-specific estimates were omitted when a modifier stratum contained fewer than 20 focal events.

Data management used Python and R; statistical modelling was conducted in R. Figures were produced in R, exported as vector PDF, and visually checked using rendered PNG previews. The onset analysis followed SAP v1.0. The persistence estimand and supporting analyses were specified in SAP v1.1 before their effect estimates were inspected.

### Direct comparisons and composite adverse states

Following review of the main analyses, additional reliability analyses evaluated pain only versus cancer only using a linear contrast of fitted phenotype coefficients and their full covariance matrix. These were additional sensitivity analyses, not newly designated primary contrasts. Recorded deaths were summarized separately by baseline phenotype and interview interval. A further outcome combined elevated symptoms at the next interview with recorded death during the interval, among the baseline-low and baseline-high symptom populations separately. This composite was a discrete next-wave adverse state, not incident clinical depression or a competing-risk cumulative incidence.

Composite analyses began with eligible baseline intervals with positive baseline survey weights. Deaths were assigned an event and retained their baseline weight. Among survivors, follow-up observation probabilities were modelled separately by interval using the common covariates. Missing categorical predictors were represented by missing categories in retention models; missing comorbidity counts used an interval median and, where applicable, a missingness indicator. Probabilities were bounded at 0.05-0.99, inverse-probability factors were truncated at the 1st and 99th percentiles among observed survivors, and observed survivors received the baseline weight multiplied by that factor. Composite weights were normalized within interval. Surviving respondents with an unobserved symptom outcome were not assigned an outcome event or imputed outcome.

Composite outcome models used the same common covariate structure and the cohort survey specifications described above. HRS and CHARLS used 20 covariate imputations; SHARE used complete covariate records. HRS composite imputation used 10 iterations. An additional SHARE analysis truncated final composite weights within interval at the 1st and 99th percentiles. Direct contrasts and composite estimates were reported by cohort without an additional pooled risk ranking, because observation windows, weights, missing-data handling, and selection differed. Differences from symptom models cannot therefore be attributed exclusively to inclusion of death.

### Reproducibility and diagnostic scope

Source versions, input hashes, cohort variable mappings, analysis code, aggregate outputs, and software-session information were retained. Multiple-imputation estimates were combined using Rubin's rules, with uncertainty for coefficient contrasts obtained before pooling. For the returned HRS models, Monte Carlo error of each pooled log RR was estimated as the square root of between-imputation variance divided by the number of imputations. This quantity addresses simulation stability rather than convergence, correctness of the imputation model, or validity of the missing-at-random assumption. Chain summaries were retained for further diagnostic review; no claim of completed distributional or convergence validation is made.

### Ethics

HRS, SHARE, and CHARLS obtained ethics approval and informed consent under their respective study protocols [11-13]. This study used secondary, de-identified data accessed under the user agreements of the three data providers. The final manuscript will report the institutional determination for this secondary analysis once confirmed; no cohort participant was contacted for the present study.


## Results

### Samples and observed state transitions

The onset models included 58,443 HRS intervals from 19,031 respondents, 62,160 SHARE intervals from 50,982 respondents, and 21,153 CHARLS intervals from 11,489 respondents. In total, 141,756 person-intervals from 81,502 cohort-specific respondents were included, with 19,913 transitions to elevated depressive symptoms.

The persistence models were built independently among respondents already at or above the symptom threshold. They included 10,087 HRS intervals from 5,679 respondents, 21,866 SHARE intervals from 19,841 respondents, and 11,277 CHARLS intervals from 7,168 respondents. Across cohorts, 43,230 person-intervals from 32,688 cohort-specific respondents contributed 24,548 persistent-high outcomes (Supplementary Figure S1; Table 1).

Cancer-specific cells were much smaller in CHARLS than in HRS or SHARE. Consequently, CHARLS estimates for contrasts involving cancer only or cancer and pain were less precise and were treated as directional replication rather than stable country-specific effect magnitudes.

### Primary analysis: onset of elevated depressive symptoms

Compared with neither cancer nor pain, cancer and pain were associated with higher onset risk in HRS (RR 1.47, 95% CI 1.28–1.69), SHARE (1.34, 1.18–1.52), and CHARLS (1.62, 1.21–2.16). The pooled RR was 1.42 (1.17–1.72), with little estimated heterogeneity (I² approximately 1%; Figure 1; Table 2).

Pain only was also associated with higher onset risk in HRS (RR 1.48, 1.36–1.62), SHARE (1.27, 1.17–1.39), and CHARLS (1.37, 1.28–1.46), with a pooled RR of 1.37 (1.14–1.65). Cancer only did not show a pooled association (RR 0.99, 0.48–2.06). Cancer and pain versus cancer only produced RRs of 1.35 (1.14–1.60) in HRS, 1.15 (0.96–1.38) in SHARE, and 2.54 (1.58–4.09) in CHARLS. The pooled estimate was imprecise and heterogeneous (RR 1.50, 0.57–3.99; I² 89.7%), precluding a common magnitude claim.

Adjusted onset risks for neither, cancer only, pain only, and cancer and pain were 6.2%, 6.7%, 9.1%, and 9.0% in HRS; 15.2%, 17.5%, 19.2%, and 20.4% in SHARE; and 19.4%, 12.4%, 26.8%, and 34.6% in CHARLS. The adjusted risk differences for cancer and pain versus neither were 2.9, 5.2, and 15.2 percentage points, respectively (Figure 2; Table 3). Absolute risks should be interpreted within cohort because instruments, thresholds, calendar periods, and designs differed.

### Important secondary analysis: persistence of elevated depressive symptoms

Cancer and pain versus neither condition was associated with persistence in HRS (RR 1.25, 95% CI 1.13–1.37) and SHARE (1.23, 1.13–1.33), while the CHARLS estimate was smaller and compatible with no difference (1.06, 0.90–1.26). The pooled RR was 1.21 (1.04–1.41), with approximately zero estimated heterogeneity and a 95% prediction interval of 1.04–1.41.

Pain only was associated with persistence in all cohorts: RR 1.24 (1.16–1.33) in HRS, 1.19 (1.12–1.27) in SHARE, and 1.14 (1.10–1.18) in CHARLS; the pooled RR was 1.18 (1.06–1.31). Cancer only again did not show a pooled association (RR 1.01, 0.58–1.78). Cancer and pain versus cancer only was not significant in the pooled analysis (RR 1.13, 0.91–1.41).

Adjusted persistence risks for neither, cancer only, pain only, and cancer and pain were 46.1%, 52.1%, 56.0%, and 56.7% in HRS; 51.3%, 55.0%, 59.9%, and 62.6% in SHARE; and 55.8%, 38.8%, 62.8%, and 58.8% in CHARLS. Cancer and pain versus neither corresponded to adjusted risk differences of 10.6 percentage points in HRS, 11.2 in SHARE, and 3.0 in CHARLS, with the CHARLS interval including zero (Figure 2; Table 3).

### Pain-burden gradients

More detailed pain measures showed graded associations with both outcomes after adjustment for cancer history and the common covariates (Figure 3). For each one-level increase in pain burden, onset RRs were 1.20 in HRS, 1.12 in SHARE, and 1.13 in CHARLS. Corresponding persistence RRs were 1.08, 1.06, and 1.05; all six trend estimates were statistically distinguishable from one.

Comparing the highest category with no pain, onset RRs were 1.56 (95% CI 1.38–1.77) for severe pain in HRS, 1.45 (1.27–1.66) for severe pain in SHARE, and 1.39 (1.27–1.53) for three or more painful sites in CHARLS. Persistence RRs were 1.26 (1.17–1.35), 1.19 (1.11–1.27), and 1.16 (1.11–1.22), respectively. These estimates were not pooled because pain severity and painful-site counts represented different constructs.

### Functional adjustment and robustness analyses

Sequential functional adjustment attenuated, but did not reverse, the main pattern (Supplementary Figure S2). For cancer and pain versus neither, the pooled onset RR changed from 1.41 in the common complete-case core sample to 1.32 after adding mobility limitations and remained 1.32 after adding ADL limitations. The analogous persistence estimate changed from 1.21 to 1.16 after mobility adjustment and remained 1.16 after ADL adjustment; the latter confidence intervals included one. These changes are compatible with functional status accounting for part of the observed stratification signal, but they are not evidence of mediation.

Persistence estimates for cancer and pain versus neither were stable in complete-case (pooled RR 1.21, 95% CI 1.03–1.42), first-eligible-interval (1.21, 1.06–1.39), final-weight-trimmed (1.21, 1.05–1.40), and reduced-covariate (1.22, 1.05–1.43) analyses. Excluding pandemic-affected HRS intervals produced an RR of 1.27 (1.12–1.44), and inclusion of SHARE Waves 6–8 produced an RR of 1.23 (1.13–1.33). The previously prespecified onset sensitivity analyses were likewise directionally concordant.

Reconstructed full depressive-symptom scores agreed exactly with their released or harmonized counterparts. After removing the sleep item and standardizing the reduced follow-up score, cancer and pain versus neither was associated with a pooled 0.16-SD higher score (95% CI 0.02–0.29) in the onset sample and a 0.22-SD higher score (0.19–0.25) in the persistence sample. Pain only showed corresponding pooled differences of 0.18 SD (0.08–0.29) and 0.18 SD (0.04–0.31). The findings therefore did not depend solely on overlap between pain, sleep disturbance, and the binary symptom threshold.

Complete-case analyses did not support reproducible multiplicative or additive cancer-by-pain interaction. Limited sex and age-group analyses in HRS and SHARE also showed no coherent modification of the focal contrast. For cancer and pain versus neither, pooled ratios of RRs were 0.95 for sex and 0.82 for age group in the onset analysis, and 0.93 and 0.90 in the persistence analysis; all confidence intervals included one. CHARLS was omitted under the prespecified minimum-event rule.

### Direct pain only versus cancer only comparisons

For symptom onset, pain only versus cancer only yielded RRs of 1.36 (95%CI 1.17-1.59) in HRS, 1.09 (0.94-1.27) in SHARE, and 2.15 (1.38-3.34) in CHARLS. Corresponding persistence RRs were 1.08 (0.94-1.24), 1.09 (0.97-1.23), and 1.60 (1.12-2.28). Thus, reproducible pain-only associations relative to neither condition did not imply a uniformly higher risk than cancer only across cohorts and symptom transitions (Supplementary Table S3).

### Composite high symptoms or death

The baseline-low symptom composite analyses included 61,528 HRS intervals with 7,966 events, 65,883 SHARE intervals with 12,992 events, and 21,829 CHARLS intervals with 5,439 events. For baseline-high symptom populations, corresponding counts were 11,116/6,510, 24,053/14,493, and 11,806/7,282 intervals/events. These denominators differed from the symptom-transition samples and should not be treated as an unchanged sample with an extra outcome category.

Pain only versus cancer only had composite RRs of 0.94 (95%CI 0.85-1.05), 0.98 (0.87-1.12), and 1.44 (1.05-1.97) in HRS, SHARE, and CHARLS for baseline-low symptom populations. Corresponding baseline-high symptom RRs were 0.98 (0.89-1.08), 1.01 (0.92-1.10), and 1.40 (1.02-1.91). HRS and SHARE estimates did not demonstrate a clear difference; they were not evidence of equivalence. CHARLS cancer-only groups comprised 185 and 53 composite person-intervals, respectively, limiting precision and generalizability.

In SHARE, interval-specific truncation of composite weights reduced the long weight tail while changing the ten log RRs by at most 0.016. This supported insensitivity to the particular extreme-weight truncation tested, not resolution of all survey-design concerns. Across the four returned HRS models, the largest Monte Carlo error relative to the pooled standard error was approximately 0.000923. This small simulation-error estimate did not establish imputation convergence.

## Discussion

### Principal findings

Across ageing cohorts in the United States, Europe, and China, current pain was associated with subsequent onset and persistence of elevated depressive symptoms among surviving respondents. Cancer-and-pain and pain-only groups had higher pooled risks than those with neither condition, without reproducible cancer-pain interaction. However, direct pain-only versus cancer-only contrasts were not uniformly elevated, and inclusion of death in a composite outcome produced estimates close to one in HRS and SHARE. The contribution is therefore an estimand-specific comparison of a current symptom marker with a broad historical diagnosis, not a universal ranking of their psychological or overall health risks.

The evidence formed a coherent hierarchy rather than depending on one contrast. The primary onset analysis established the prospective association among respondents initially below the symptom threshold; it represents next-wave threshold crossing, not first-ever clinical onset. The important secondary persistence analysis extended the pattern to respondents already symptomatic. Within cohorts, adjusted absolute risks translated these relative associations into clinically interpretable differences. Pain-burden trend estimates were positive for both outcomes, although individual category estimates were not uniformly monotonic, and associations remained after the sleep item was removed from depressive-symptom scores. Together, these findings support symptom burden as a practical supplement to diagnosis-centred surveillance.

The smaller relative estimates for persistence should not be interpreted as absence of clinical relevance. Persistence was common among respondents already above the symptom threshold, leaving less relative separation between groups even when adjusted risk differences remained appreciable in HRS and SHARE. Conversely, the null or imprecise cancer-only estimates do not imply that cancer has no psychological consequences. Cancer may have affected the baseline symptom state already included in the model, and the harmonized exposure collapsed site, prognosis, treatment, recurrence, and time since diagnosis into a single history indicator. Our inference is limited to next-wave stratification conditional on observed baseline symptoms.

### Outcome definition and interpretation of comparative risk

The composite analyses show why the target outcome must remain explicit. A weak cancer-only association in surviving respondents does not imply low overall illness burden. Recorded death, follow-up observation, and baseline symptom status select different populations into symptom-transition models. The composite findings are compatible with this concern, but they do not quantify a causal effect of survival selection: the composite models also used different weights, denominators, and missing-data handling. The persistent positive CHARLS contrasts should be interpreted alongside its small cancer groups rather than as proof that the same ordering holds in all populations.

### Relation to previous evidence

Psycho-oncology research shows that mental-health burden can extend beyond diagnosis and treatment while varying substantially across cancer types and survivorship periods [1–4]. Symptom-science studies further identify co-occurring pain, fatigue, sleep, functional, and psychological profiles [6,19]. The present analysis connects these literatures by treating pain not as proof of a cancer-specific mechanism but as a current burden marker that may reveal heterogeneity hidden within an any-cancer-history category.

The pain-only and pain-gradient findings are consistent with longitudinal evidence from SHARE, HRS, ELSA, and CHARLS [7–10]. A 2026 Korean fixed-effects analysis likewise linked within-person increases in pain intensity to higher depressive-symptom levels and identified social and physical activity as potential buffers [20]. This agreement deliberately limits the novelty claim: the study did not discover a new pain–depression association. Its contribution is the comparative design. The same coordinated framework tested a diagnosis-history marker and a current symptom marker across two depressive-symptom transitions and three settings. The results support evaluating current symptom burden alongside diagnosis history for next-wave psychological assessment among survivors; they do not challenge the broader evidence that cancer can elevate mental-health risk.

Earlier HRS work demonstrated heterogeneous depressive-symptom trajectories among older adults with cancer [21]. Pain may be one observable dimension of that heterogeneity. A recent single-centre study in older cancer patients linked impaired locomotor function with subthreshold depression, but its cross-sectional design could not establish temporal ordering [22]. In the CARE Registry, pain among older adults with gastrointestinal malignancies was strongly associated with depression, anxiety, and functional limitation [5]. Our population-cohort design adds temporal ordering and a cancer-free comparison, whereas oncology registries provide the site, stage, treatment, and recurrence detail absent here. These approaches are complementary: registry studies can explain cancer-specific burden, while coordinated population cohorts test whether a simple clinical signal remains informative across community settings.

### Interpreting function, measurement overlap, and interaction

Several non-exclusive processes could connect current pain with later depressive symptoms. Pain may restrict mobility and valued activity, threaten independence, disturb sleep, reduce social participation, and reinforce anxiety or adverse pain beliefs; shared biological processes are also plausible [23–25]. The attenuation after mobility and ADL adjustment is compatible with functional burden lying on, confounding, or marking part of this pathway. Because function, pain, and depressive symptoms were measured contemporaneously at interval baseline, these models cannot distinguish mediation from confounding or consequence and should not be presented as mechanistic proof.

Removing the sleep item addressed a narrower measurement concern. Pain-related groups continued to have higher standardized follow-up symptom scores after the shared somatic item was excluded and the corresponding baseline score was controlled. The result therefore did not depend solely on sleep-item overlap or dichotomisation at cohort-specific thresholds. It does not eliminate all construct overlap, because energy, activity, affect, and social engagement are both components of lived symptom burden and domains represented in depressive-symptom instruments.

Neither multiplicative nor additive analyses demonstrated reproducible cancer–pain interaction. The cancer-and-pain versus cancer-only contrast was especially heterogeneous for onset and imprecise when pooled for persistence. A joint phenotype may be useful for triage even when its components do not interact statistically or biologically. The evidence therefore concerns phenotype-specific associations and pain-burden gradients, rather than a uniform ordering of cancer and pain or the largest cancer-specific estimate in any single cohort.

### Clinical and research implications

ASCO and ESMO guidance supports systematic identification and management of anxiety and depression in cancer care [1,2]. The present findings suggest a restrained operational refinement for survivorship and general older-adult care: current pain could prompt assessment of psychological needs rather than be managed as an isolated physical complaint. Among people already above a symptom threshold, pain may also justify closer follow-up because high symptoms were more likely to persist. Pain is neither a depression diagnosis nor a validated screening rule; it is a low-burden prompt for applying validated assessment and integrating physical and psychological symptom review.

The findings also support testing simple, interpretable clinical signals before adding complex prediction algorithms. A systematic review of depression-risk models in older adults found limited external validation and generally high or unclear risk of bias [26]. This study did not develop a clinical prediction model and therefore makes no claim about discrimination, calibration, net benefit, or incremental predictive performance. Future work should explicitly test whether repeated pain measures, interference, trajectories, and change improve prediction beyond baseline symptoms and routine clinical information. Linkage to cancer registries is needed to address site, stage, treatment, recurrence, time since diagnosis, and pain aetiology. Intervention studies would then be required to determine whether pain-triggered psychological assessment or integrated care improves patient outcomes.

### Strengths and limitations

Strengths include prospective person-interval construction; a prespecified primary onset estimand and an independently frozen persistence expansion; adjustment for baseline symptom score; separation of recorded death from ordinary attrition; cohort-specific complex survey designs; and coordinated replication without inappropriate pooling of individual records or survey weights. Relative and absolute effects, pain-burden gradients, functional adjustment, item-level outcome reconstruction, and multiple sensitivity specifications provided distinct tests of the same central interpretation.

Several limitations define the claim boundary. First, cancer site, stage, treatment, recurrence, and time since diagnosis were not harmonized. The study concerns any cancer history and cannot support claims specific to gastrointestinal or other cancers. Second, the common pain indicator did not uniformly measure duration, interference, or aetiology and cannot be interpreted as chronic, malignant, or treatment-related pain. HRS and SHARE measured pain severity, whereas CHARLS contributed painful-site counts; these cohort-specific gradients were therefore not pooled. Third, depressive symptoms were measured with different instruments and thresholds. Coordinated relative estimates are interpretable across cohorts, but absolute risks should remain within-cohort quantities. Threshold crossing may also reflect short-term symptom fluctuation or regression to the mean; adjustment for the baseline continuous score and analyses of continuous reduced-item scores mitigate but do not eliminate this concern.

Fourth, cancer-only and cancer-with-pain cells were sparse in CHARLS, limiting precision for cancer-specific contrasts and excluding this cohort from prespecified effect-modification analyses. CHARLS provides strong replication for pain-only and pain-burden findings but only directional evidence for joint cancer phenotypes. Fifth, highly variable official SHARE longitudinal weights required sensitivity analysis, although trimming did not materially alter persistence estimates. Sixth, self-reported exposures are vulnerable to recall and classification error, and people with severe illness or cognitive limitations may be underrepresented. Finally, the estimand is conditional on survival to the next wave; inverse-probability weighting addresses measured non-response among survivors but cannot remove selection from death, unmeasured attrition processes, or selective survival before cohort entry. Residual confounding and reciprocal pain–depression processes also remain possible. The data establish temporal ordering across adjacent waves, not causality or the effect of treating pain.

The SHARE estimates currently use country strata and a household-first clustering specification without finite-population corrections, rather than a completed sensitivity analysis using the newly obtained official primary sampling units and strata. Availability of those fields does not validate their linkage or use across national sampling designs. Complete imputation convergence and observed-versus-imputed distribution checks also remain outstanding. The 2022 HRS components include Early Release material; the version decision and corresponding disclosure must be finalized before submission. These limitations prevent treating the present version as a fully locked analysis release.

## Conclusion

Current pain was associated with next-wave onset and persistence of elevated depressive symptoms among surviving respondents across three ageing cohorts. Direct comparisons with cancer history alone were less uniform, and composite outcomes including death did not show clearly higher pain-only risk in HRS or SHARE. Pain assessment may complement psychological assessment, but these findings do not establish an overall health-risk hierarchy, predictive superiority, equivalence, causality, or benefit from intervention.

## Data availability statement

The individual-level data used in this study are not owned by the authors and cannot be redistributed with the article. Researchers can obtain the same source data independently after registration and acceptance of the applicable user agreements; access does not require permission from the authors.

HRS public-release and RAND files are available to registered users through the [HRS data portal](https://hrsdata.isr.umich.edu/data-products) and the [RAND HRS products page](https://hrsdata.isr.umich.edu/data-products/rand). Use and redistribution are governed by the [HRS Conditions of Use](https://hrsdata.isr.umich.edu/data-products/conditions-of-use). The current analysis used RAND HRS Longitudinal File 2022 (Version 1) and RAND HRS Fat Files for 2012-2022; the 2022 E.3A product is an Early Release file and will be acknowledged according to those conditions if retained in the final analysis.

SHARE data are available free of charge for scientific use after individual registration through the [SHARE Research Data Center](https://www.share-eric.eu/data/data-access); the registration procedure is described on the [Become a SHARE User](https://share-eric.eu/data/become-a-user) page. This study used Release 9.0.0 for [Wave 5](https://doi.org/10.6103/SHARE.w5.900), [Wave 6](https://doi.org/10.6103/SHARE.w6.900), [Wave 8](https://doi.org/10.6103/SHARE.w8.900), [Wave 9](https://doi.org/10.6103/SHARE.w9.900), and the [longitudinal weights](https://doi.org/10.6103/SHARE.wXweights.900), together with Gateway Harmonized SHARE G. SHARE data may not be redistributed by the authors.

CHARLS data and documentation are available to registered users through the [official CHARLS portal](https://charls.pku.edu.cn/en/) and the wave-specific pages for [2011](https://charls.pku.edu.cn/en/Data/a2011_CHARLS_Wave1__Baseline_.htm), [2013](https://charls.pku.edu.cn/en/Data/a2013_CHARLS_Wave2.htm), [2015](https://charls.pku.edu.cn/en/Data/a2015_CHARLS_Wave_3.htm), and [2018](https://charls.pku.edu.cn/en/Data/a2018_CHARLS_Wave_4.htm). Harmonized CHARLS Version D was used to support variable mapping, with core measures checked against the original wave files. CHARLS source data may not be redistributed by the authors.

The manuscript and aggregate supporting materials are available at https://github.com/ZENGJingqi/Cancer-Pain-Depressive-Symptoms. Individual records, imputed datasets and participant-level model objects are excluded. Obtain source data separately from the cohort providers.

## Code availability

Selected analysis scripts and aggregate-only figure code are available at https://github.com/ZENGJingqi/Cancer-Pain-Depressive-Symptoms. This prepublication release reproduces Figures 1–3 and S1–S2 from summaries, not the full analysis from raw data. Outstanding design, imputation and version checks are documented there.


## References

1. Grassi L, Caruso R, Riba MB, Lloyd-Williams M, Kissane D, Rodin G, et al. Anxiety and depression in adult cancer patients: ESMO Clinical Practice Guideline. ESMO Open. 2023;8(2):101155. doi:10.1016/j.esmoop.2023.101155.
2. Andersen BL, Lacchetti C, Ashing K, Berek JS, Berman BS, Bolte S, et al. Management of anxiety and depression in adult survivors of cancer: ASCO Guideline Update. J Clin Oncol. 2023;41(18):3426–3453. doi:10.1200/JCO.23.00293.
3. Forbes H, Carreira H, Funston G, Andresen K, Bhatia U, Strongman H, et al. Early, medium and long-term mental health in cancer survivors compared with cancer-free comparators: matched cohort study using linked UK electronic health records. EClinicalMedicine. 2024;76:102826. doi:10.1016/j.eclinm.2024.102826.
4. Getie A, Ayalneh M, Bimerew M. Global prevalence and determinant factors of pain, depression, and anxiety among cancer patients: an umbrella review of systematic reviews and meta-analyses. BMC Psychiatry. 2025;25:156. doi:10.1186/s12888-025-06599-5.
5. Al-Obaidi M, Kosmicki S, Harmon C, Lobbous M, Outlaw D, Khushman M, et al. Pain among older adults with gastrointestinal malignancies—results from the Cancer and Aging Resilience Evaluation (CARE) Registry. Support Care Cancer. 2022;30(12):9793–9801. doi:10.1007/s00520-022-07398-4.
6. Lee LJ, Han CJ, Saligan L, Wallen GR. Comparing symptom clusters in cancer survivors by cancer diagnosis: a latent class profile analysis. Support Care Cancer. 2024;32(5):308. doi:10.1007/s00520-024-08489-0.
7. Ogliari G, Ryg J, Andersen-Ranberg K, Scheel-Hincke LL, Collins JT, Cowley A, et al. Association between pain intensity and depressive symptoms in community-dwelling adults: longitudinal findings from the Survey of Health, Ageing and Retirement in Europe (SHARE). Eur Geriatr Med. 2023;14:1111–1124. doi:10.1007/s41999-023-00835-5.
8. Qiu Y, Ma Y, Huang X. Bidirectional relationship between body pain and depressive symptoms: a pooled analysis of two national aging cohort studies. Front Psychiatry. 2022;13:881779. doi:10.3389/fpsyt.2022.881779.
9. Tu MQ, Yi TP, Tu JY. Association of chronic pain trajectories with incident depressive symptoms among older adults: evidence from national cohorts in the UK and the US. Int J Psychiatry Med. 2026;61(5):650–672. doi:10.1177/00912174261440653.
10. Kang Y. Longitudinal bidirectional relationship between pain burden and depressive symptoms among middle-aged and elderly individuals: a cross-lagged panel model. Int J Psychiatry Med. 2026. Online ahead of print. doi:10.1177/00912174261436560.
11. Sonnega A, Faul JD, Ofstedal MB, Langa KM, Phillips JWR, Weir DR. Cohort profile: the Health and Retirement Study (HRS). Int J Epidemiol. 2014;43(2):576–585. doi:10.1093/ije/dyu067.
12. Börsch-Supan A, Brandt M, Hunkler C, Kneip T, Korbmacher J, Malter F, et al. Data resource profile: the Survey of Health, Ageing and Retirement in Europe (SHARE). Int J Epidemiol. 2013;42(4):992–1001. doi:10.1093/ije/dyt088.
13. Zhao Y, Hu Y, Smith JP, Strauss J, Yang G. Cohort profile: the China Health and Retirement Longitudinal Study (CHARLS). Int J Epidemiol. 2014;43(1):61–68. doi:10.1093/ije/dys203.
14. Andresen EM, Malmgren JA, Carter WB, Patrick DL. Screening for depression in well older adults: evaluation of a short form of the CES-D. Am J Prev Med. 1994;10(2):77–84.
15. Prince MJ, Reischies F, Beekman ATF, Fuhrer R, Jonker C, Kivela SL, et al. Development of the EURO-D scale—a European Union initiative to compare symptoms of depression in 14 European centres. Br J Psychiatry. 1999;174:330–338. doi:10.1192/bjp.174.4.330.
16. van Buuren S, Groothuis-Oudshoorn K. mice: multivariate imputation by chained equations in R. J Stat Softw. 2011;45(3):1–67. doi:10.18637/jss.v045.i03.
17. Zou G. A modified Poisson regression approach to prospective studies with binary data. Am J Epidemiol. 2004;159(7):702–706. doi:10.1093/aje/kwh090.
18. von Elm E, Altman DG, Egger M, Pocock SJ, Gøtzsche PC, Vandenbroucke JP; STROBE Initiative. The Strengthening the Reporting of Observational Studies in Epidemiology (STROBE) statement: guidelines for reporting observational studies. Lancet. 2007;370(9596):1453–1457. doi:10.1016/S0140-6736(07)61602-X.
19. Gross S, Koczwara B, Beatty L. Medical and psychosocial symptom clusters and their temporal patterns in people with cancer. Support Care Cancer. 2025;33(12):1085. doi:10.1007/s00520-025-10028-4.
20. Song E, Kim J. The longitudinal relationship between pain and depressive symptoms in later life: the buffering effects of social and physical activities among older Koreans. Innov Aging. 2026;10(5):igag037. doi:10.1093/geroni/igag037.
21. Schapmire TJ, Faul AC. Depression symptoms in older adults with cancer: a multilevel longitudinal study. J Psychosoc Oncol. 2017;35(3):260–277. doi:10.1080/07347332.2017.1286698.
22. Zhou YQ, Xu WJ, Yang YL, Su H, Lu H, Yu H, et al. Correlation between musculoskeletal system function and pre-depressive states in elderly cancer patients: a single-center cross-sectional study. World J Psychiatry. 2025;15(11):110825. doi:10.5498/wjp.v15.i11.110825.
23. Hassamal S. Chronic stress, neuroinflammation, and depression: an overview of pathophysiological mechanisms and emerging anti-inflammatories. Front Psychiatry. 2023;14:1130989. doi:10.3389/fpsyt.2023.1130989.
24. Nakanishi M, Perry M, Bejjani R, Yamaguchi S, Usami S, van der Steen JT. Longitudinal associations between subjective cognitive impairment, pain and depressive symptoms in home-dwelling older adults: modelling within-person effects. Int J Geriatr Psychiatry. 2024;39(5):e6103. doi:10.1002/gps.6103.
25. Shim EJ, Ha H, Yeom CW, Son KL, Kim WH, Hahm BJ. Depression and cancer pain: mediating roles of anxiety and pain beliefs. J Pain Symptom Manage. 2025;70(5):481–489. doi:10.1016/j.jpainsymman.2025.07.030.
26. Tan J, Ma C, Zhu C, Wang Y, Zou X, Li H, et al. Prediction models for depression risk among older adults: systematic review and critical appraisal. Ageing Res Rev. 2023;83:101803. doi:10.1016/j.arr.2022.101803.

## Main tables and figures

- Table 1. Characteristics of onset and persistence person-intervals by cohort and cancer–pain phenotype.
- Table 2. Cohort-specific and pooled adjusted RRs for onset and persistence.
- Table 3. Cohort-specific adjusted absolute risks and focal risk differences.
- Figure 1. Adjusted RRs for the two focal contrasts across both estimands.
- Figure 2. Adjusted absolute risks and risk differences across both estimands.
- Figure 3. Cohort-specific pain-burden gradients for onset and persistence.

## Supplementary material

- Supplementary Figure S1. Dual-estimand person-interval construction and retention.
- Supplementary Figure S2. Sequential functional-adjustment models.
- Supplementary Table S3. Direct pain-only versus cancer-only comparisons for symptom transitions and composite adverse states, reported separately by cohort.
- Additional aggregate supporting estimates and the status of unfinished analyses are documented in the repository.
