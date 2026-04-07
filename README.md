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

The raw WAS microdata are **not included** in this replication package. Access to the WAS must be obtained independently via the UK Data Service:

- **Dataset:** Wealth and Assets Survey, Waves 1–8
- **UK Data Service SN:** 7215
- **URL:** https://beta.ukdataservice.ac.uk/datacatalogue/studies/study?id=7215
- **Access type:** Safeguarded (requires registration and project application)

Once access is granted, download the Stata (`.dta`) files and save them in a single folder. You should then update the global `$rawWAS` with the file path where you saved these files (see [Directory Setup](#directory-setup) below).

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
| `$project_root` | `PUT_FILE_PATH_HERE` | Root directory for the project |
| `$code` | `$project_root/replication_package` | Directory containing this replication package |
| `$rawdata` | `$project_root/rawdata` | Other raw input data (discount rates, mortality tables) |
| `$workingdata` | `$project_root/data` | Where processed `.dta` files are saved |
| `$output` | `$project_root/output` | Where figures and tables are saved |
| `$rawWAS` | `PUT_FILE_PATH_HERE` | Location of raw WAS Stata files |

The directories `$workingdata` and `$output` must exist before running. The `$code` directory is the root of this replication package.

---

## How to Run

After updating the directories, open Stata, navigate to the replication package directory, and run:

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
| `was_db_correction_new.do` | Programs to correct raw DB pension wealth figures in WAS |
| `get_discount_rates.do` | Constructs nominal and real discount rates from gilt and AA corporate bond yields |
| `calculate_survivals.do` | Computes survival probabilities by age and sex using ONS life tables |
| `calculate_forward_rates.do` | Derives forward rates from the discount rate term structure |
| `calculate_annuity_rates.do` | Combines survival probabilities and forward rates into annuity factors |

### Phase 2 — WAS Data Preparation and Analysis

Prepares the WAS microdata and produces all outputs.

| Script | Description |
|--------|-------------|
| `Run WAS benefit unit code.do` | Assigns benefit unit numbers to person-level WAS records across waves 2–8 using `assignWASbunos.ado` |
| `get_was_vars.do` | Appends WAS waves 1–8 and harmonises variables across waves |
| `clean_was.do` | Applies cleaning, wave 2 adjustments, and constructs wealth variables |
| `was_analysis_new.do` | Defines and runs all analysis programs producing figures and tables |

---

## Using your own discount rate 

Currently, the code calculates the value of pension wealth in all 8 waves/rounds of WAS under four discount rates:

1. Real gilt yields
2. Real AA corporate bond yields
3. Real SCAPE rate
4. Constant real discount rate of 0%

The code can be adapted to calculate pension wealth using your own discount rate.

The easiest ways to edit the discount rate used are either (i) to edit the `constant_rate` global defined in line 46 of `master.do` or (ii) if you want to define the SCAPE rate in a different way, editing the function `gen_real_scpe` in `get_discount_rates.do`. 

Alternatively, you can update `clean_penwealth` in `was_db_correction_new` to accept new discount rates and annuity factor variables. In particular, you then need to provide a discount rate for four different types of pensions:

* First current DB pension, to be saved in local `discount_rate1`
* Second current DB pension, to be saved in local `discount_rate2`
* Own retained rights, to be saved in local `discount_rate3`
* Partner retained rights, to be saved in local `discount_rate4`

And annuity factors for five different types of pensions:

* First current DB pension, to be saved in local `ann_factor1`
* Second current DB pension, to be saved in local `ann_factor2`
* Own retained rights, to be saved in local `ann_factor3`
* Partner retained rights, to be saved in local `ann_factor4`
* Pensions in payment, to be saved in local `ann_factor5`

These do not necessarily need to be in different variables. For example, when you specify `disc_type = scpe`, the variable scpe_rate is set equal to all four discount rates. 

The rest of the code can help you create manually-calculated actuarially fair annuity factors for different discount rates. In particular, if you want to create these annuity factors for a new discount rate, you should create this new discount rate variable in calculate_annuity_rates (for example, similar to how we create the SCAPE rate in that file) and add it into the loop starting on line 62. This will then calculate year-by-month-by-birthYear-by-retirementAge-by-sex-by-partnerStatus annuity factors for your new discount rate. Then, you need to edit the code in `get_was_vars.do` to ensure that the `clean_penwealth` file runs for this new discount rate and annuity factor combo.


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
- The RPI–CPI wedge (`$rpicpiwedge = 0.009`) and CPIH–CPI wedge (`$cpihcpiwedge = 0.0039`) used in pension valuation are sourced from OBR publications and set in `master.do`.
- Home contents wealth is reduced by 75% following Advani et al. (2021), as the WAS questionnaire elicits replacement rather than market value.

See the report **link here** for more information. 

---

## Contact

For questions about this replication package, contact Laurence O'Brien laurence.obrien@ifs.org.uk.
