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

* Filepath globals
global project_root "J:\PensionsTax\wealth_report"
global code "$project_root/code"
global workingdata "$project_root/data"
global rawdata "$project_root/rawdata"
global output "$project_root/output"
global rawWAS "I:\WAS\unrestricted\stata\UKDA-7215-stata\stata\stata_se"

set seed 359345 

adopath + "$code/was_cleaning"

global constant_rate 0
global cpih_index = 141.5 // cpih index in 2026 according to March 2026 EFO

*** Run code

* Code for DB pension valuation, making discount rates and annuity rates
do "$code/was_db_correction_new"
do "$code/get_discount_rates"
do "$code/calculate_survivals"
do "$code/calculate_forward_rates"
do "$code/calculate_annuity_rates"

* Code for cleaning WAS and creating analysis sample 
do "$code/get_was_vars"
do "$code/clean_was"

* Code to do WAS analysis in report 
do "$code/was_analysis_new"
