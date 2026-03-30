# Replication Package: How is wealth distributed across British households?

**Authors:** Isaac Delestre and Laurence O'Brien

**Report:** How is wealth distributed across British households? Reassessing the valuation of pensions

**Date:** 9 April 2026

---

## Overview

This replication package implements the IFS methodology for estimating the value of private pension wealth in the Wealth and Assets Survey (WAS). This methodology calculates the value of private pension wealth on a consistent basis for all waves/rounds of the WAS, discounting DB/accessed private pensions with a constant discount factor, that the user can specify.

In addition, the package produces all the figures and tables in Delestre and O'Brien (2026).

---

## Data Requirements

### Wealth and Assets Survey (WAS)

The raw microdata are **not included** in this replication package. Access to the WAS must be obtained independently via the UK Data Service:

- **Dataset:** Wealth and Assets Survey, Waves 1–8
- **UK Data Service SN:** 7215
- **URL:** https://beta.ukdataservice.ac.uk/datacatalogue/studies/study?id=7215
- **Access type:** Safeguarded (requires registration and project application)

Once access is granted, download the Stata (`.dta`) files. The default path used in this package is:

```
I:\WAS\unrestricted\stata\UKDA-7215-stata\stata\stata_se
```

You will need to update this path in `master.do` if your files are stored elsewhere (see [Directory Setup](#directory-setup) below).

---

## Software Requirements

- **Stata** (version 17 or later recommended)
- **SSC packages:** Install the following once before running:

```stata
ssc install missings
ssc install fastgini
```

These lines are included (commented out) at the top of `master.do` for convenience.

---

## Directory Setup

The pipeline uses six path globals, all defined at the top of `master.do`. Before running, update these to match your system:

| Global | Default path | Description |
|--------|-------------|-------------|
| `$project_root` | `J:\PensionsTax\wealth_report` | Root directory for the project |
| `$code` | `$project_root/code` | Directory containing this replication package |
| `$workingdata` | `$project_root/data` | Where processed `.dta` files are saved |
| `$rawdata` | `$project_root/rawdata` | Other raw input data (discount rates, mortality tables) |
| `$output` | `$project_root/output` | Where figures and tables are saved |
| `$rawWAS` | `I:\WAS\...\stata_se` | Location of raw WAS Stata files |

The directories `$workingdata`, `$rawdata`, and `$output` must exist before running. The `$code` directory is the root of this replication package.

---

## How to Run

Open Stata, navigate to the replication package directory, and run:

```stata
do "master.do"
```

This runs the full pipeline from raw data to final outputs. Individual scripts can be run separately but must be run in the order defined in `master.do` due to data dependencies.

---

## Pipeline

The code runs in two phases:

### Phase 1 — DB Pension Valuation

Constructs the annuity and discount rates used to value DB pension wealth.

| Script | Description |
|--------|-------------|
| `was_db_correction_new.do` | Corrects raw DB pension wealth figures in WAS |
| `get_discount_rates.do` | Constructs nominal and real discount rates from gilt and AA corporate bond yields |
| `calculate_survivals.do` | Computes survival probabilities by age and sex using ONS life tables |
| `calculate_forward_rates.do` | Derives forward rates from the discount rate term structure |
| `calculate_annuity_rates.do` | Combines survival probabilities and forward rates into annuity factors |

### Phase 2 — WAS Data Preparation and Analysis

Prepares the WAS microdata and produces all outputs.

| Script | Description |
|--------|-------------|
| `get_was_vars.do` | Appends WAS waves 1–8 and harmonises variables across waves |
| `clean_was.do` | Applies cleaning, wave 2 adjustments, and constructs wealth variables |
| `was_analysis_new.do` | Defines and runs all analysis programs producing figures and tables |

---

## Outputs

All outputs are saved to `$output`. The analysis produces the following:

**Main figures:**
- Mean household wealth over time (by wealth component)
- Wealth composition over time
- Discount rates used in DB valuation
- Wealth distribution in Wave 8
- Top wealth shares over time
- Average wealth by education
- Wealth composition by age (Wave 8)
- Average wealth by age (Wave 8)
- Wealth by age across waves

**Appendix figures:**
- Mean household wealth over time (all wealth components)
- Median household wealth over time
- Average wealth by pension type
- Pension wealth comparison by age

---

## Custom Ado Files

Two custom Stata ado files are included in the `was_cleaning/` subdirectory and are added to Stata's search path by `master.do`:

- **`assignWASbunos.ado`** — Assigns benefit unit numbers to WAS person-level records. Handles known data quality issues in the raw WAS relationship variables.
- **`assertdiag.ado`** — Enhanced assertion command that flags and describes contradicting observations to assist with data checks.

---

## Reproducibility Notes

- A random seed (`set seed 359345`) is set in `master.do`.
- Wealth is deflated to March 2026 prices using CPIH (`$cpih_index = 141.5`, from the March 2026 OBR EFO).
- Home contents wealth is reduced by 75% following Advani et al. (2021), as the WAS questionnaire elicits replacement rather than market value.

---

## Contact

For questions about this replication package, contact Laurence O'Brien laurence.obrien@ifs.org.uk.
