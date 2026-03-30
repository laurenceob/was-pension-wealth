# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Stata replication package for a report on measuring pension wealth in the UK, using the Wealth and Assets Survey (WAS). The analysis covers WAS Waves 1–8 (Rounds 3–8) and produces figures/tables on household wealth trends, with a focus on Defined Benefit (DB) pension valuation.

## Running the Code

All code is run via Stata. The full pipeline is orchestrated by:

```stata
do "master.do"
```

Individual scripts can be run separately, but must be run in the order defined in `master.do` due to data dependencies.

## Directory Structure

The replication package sits within a broader project directory. `master.do` defines these globals:

| Global | Path |
|---|---|
| `$project_root` | `J:\PensionsTax\wealth_report` |
| `$code` | `$project_root/code` |
| `$workingdata` | `$project_root/data` |
| `$rawdata` | `$project_root/rawdata` |
| `$output` | `$project_root/output` |
| `$rawWAS` | `I:\WAS\unrestricted\stata\UKDA-7215-stata\stata\stata_se` |

Raw WAS microdata lives on a separate restricted drive (`I:\`). Processed data is saved to `$workingdata`. Outputs (figures, tables) go to `$output`.

## Pipeline Architecture

The pipeline runs in two phases:

**Phase 1 — DB pension valuation** (produces annuity/discount rate data used in Phase 2):
1. `was_db_correction_new.do` — corrects raw DB pension wealth figures
2. `get_discount_rates.do` — constructs discount rates
3. `calculate_survivals.do` — survival probabilities by age/sex
4. `calculate_forward_rates.do` — forward rates from discount rates
5. `calculate_annuity_rates.do` — annuity rates combining survivals and forward rates

**Phase 2 — WAS data preparation and analysis**:
6. `get_was_vars.do` — appends WAS waves, harmonises variables
7. `clean_was.do` — cleaning, wave 2 adjustments, wealth variable construction
8. `was_analysis_new.do` — all analysis programs called from `main`

## Key Design Patterns

- **Program-based analysis**: `was_analysis_new.do` defines named Stata programs (e.g., `mean_hh_wealth_over_time`, `wealth_dist_r8`) that are called from a `main` program at the top. To re-run a single figure, call the relevant program after loading the data.
- **Household reference person**: Most analysis restricts to household reference persons (`ishrp == 1`) via the `keep_hh_ref_person` program.
- **Survey weights**: Population estimates use WAS cross-sectional household weights (`xshhwgt`, `xs_wgtw1`, etc., varying by wave).
- **Inflation adjustment**: Wealth is deflated to a common price base using CPIH. The index value is set as a global in `master.do` (`$cpih_index = 141.5`, March 2026 EFO).
- **Physical wealth adjustment**: Home contents wealth is reduced by 75% following Advani et al. (2021).
- **Custom ado files**: `assignWASbunos.ado` (benefit unit assignment) and `assertdiag.ado` are in this package. The `adopath` in `master.do` adds `$code/was_cleaning` to Stata's search path.

## Required Stata Packages

The following SSC packages are used (install once if not present):

```stata
ssc install missings
ssc install fastgini
```

## Reproducibility

A random seed (`set seed 359345`) is set in `master.do`. The constant discount rate mode is controlled by `global constant_rate 0`.
