/********************************************************************************
**** Title: 		extract_pension_wealth.do 
**** Author: 		Laurence O'Brien 
**** Date started: 	12/12/2025
**** Description:	Extract pension wealth 
********************************************************************************/

use "$workingdata/mergedwas", clear 

keep if dataset_no == 7

keep dataset_no caser7 personr7 totpen_gilt 

save "$workingdata/r7_pension_data_for_jed", replace