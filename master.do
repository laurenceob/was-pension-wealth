/********************************************************************************
**** Title: 		master.do 
**** Author: 		Laurence O'Brien 
**** Date started: 	28/03/2025
**** Description:	Master do file for report on measuring pension wealth
********************************************************************************/

* Install necessary programs 
*ssc install missings
*ssc install fastgini

* Clear stata
clear all
macro drop _all
set more off

********************************************************************************
*** USER CONFIGURATION — update these paths before running
********************************************************************************

* Root directory of the project (parent of the replication package folder)
global project_root "J:\PensionsTax\wealth_report"

* Path to raw WAS Stata files (obtained from UK Data Service, SN 7215)
global rawWAS "I:\WAS\unrestricted\stata\UKDA-7215-stata\stata\stata_se"

********************************************************************************
*** DERIVED PATHS - ensure that you create these in your project directory before running
********************************************************************************

* Derived path globals (set relative to project_root — no need to edit)
global code "$project_root/code/replication_package"
global workingdata "$project_root/data"
global rawdata "$project_root/rawdata"
global output "$project_root/output"

adopath + "$code/was_cleaning"

********************************************************************************
*** Set constants
********************************************************************************

set seed 359345

* Discount rate used in constant-rate pension valuation scenario
global constant_rate 0

* CPIH index value for deflating wealth to March 2026 prices (March 2026 OBR EFO)
global cpih_index = 141.5

* RPI-CPI wedge is 0.9ppt from here https://obr.uk/box/the-long-run-difference-between-rpi-and-cpi-inflation/
global rpicpiwedge = 0.009

* The CPIH-CPI wedge is from here https://obr.uk/efo/economic-and-fiscal-outlook-march-2025/
* Note in Oct 2020 it was announced that RPI would be made equal to CPIH from 2030 on 
global cpihcpiwedge = 0.0039

********************************************************************************
*** Run code
********************************************************************************

* Code for DB pension valuation, making discount rates and annuity rates
do "$code/was_db_correction_new"
do "$code/get_discount_rates"
do "$code/calculate_survivals"
do "$code/calculate_forward_rates"
do "$code/calculate_annuity_rates"

* Code for cleaning WAS and creating analysis sample 
do "$code/Run WAS benefit unit code" // creates benefit unit mappings 
do "$code/get_was_vars"
main 
do "$code/clean_was"

* Code to do WAS analysis in report 
do "$code/was_analysis_new"
main 
