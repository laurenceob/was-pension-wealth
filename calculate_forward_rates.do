/********************************************************************************
**** Title: 		calculate_forward_rates.do 
**** Author: 		Laurence O'Brien 
**** Date started: 	25/06/2025
**** Description:	Calculate annuity rates by year/month and distance to retirement 
********************************************************************************/

global rpicpiwedge = 0.009
global aagiltdiff = 0.0119

********************************************************************************
* Calculate the forward rates for gilts 
********************************************************************************

* Going to use 15 year maturity length where possible
local maturity 15

use "$workingdata/real_gilt_yields", clear

* Get ready to merge in real gilt yield of longer maturity
preserve 
drop if maturity > 25 & year < 2016
ren (maturity real_gilt_yield) (maturity_end real_gilt_yield_end)
tempfile tomerge 
save `tomerge', replace 
restore 

* Merge in real gilt yield of longer maturity 
ren (maturity real_gilt_yield) (years_to_retire real_gilt_yield_start)
gen maturity_end = years_to_retire + `maturity'
merge 1:1 year month maturity_end using `tomerge', keep(1 3) nogen

* Calculate the forward rate 
gen real_gilt_forward_rate = ((((1 + real_gilt_yield_end) ^ maturity_end) / ///
						 ((1 + real_gilt_yield_start) ^ years_to_retire)) ^ (1 / `maturity')) - 1
						 
* Copy down to later maturities 
bys year month (years_to_retire): replace real_gilt_forward_rate = real_gilt_forward_rate[_n-1] if missing(real_gilt_forward_rate)

* Keep relevant bits 
keep year month years_to_retire real_gilt_forward_rate
assert !missing(real_gilt_forward_rate)

* Also need to add on annuity rates for people retiring now (i.e. years to retirement = 0)
preserve 
use "$workingdata/real_gilt_yields", clear
keep if maturity == `maturity'
gen years_to_retire = 0 
ren real_gilt_yield real_gilt_forward_rate 
drop maturity
tempfile toappend 
save `toappend', replace
restore 
append using `toappend'
sort year month years_to_retire 

* Expand this to later years for people who are more than 40 years from retirement 
forval i = 41/80 {
	preserve 
	keep if years_to_retire == 40 
	replace years_to_retire = `i'
	tempfile toappend 
	save `toappend', replace
	restore 
	append using `toappend'
	
}

* And to earlier years (to make sure we have annuity factors for all retages for everyone)
forval i = -30(1)2 {
	if `i'  == 0 continue
	preserve 
	if `i' > 0 keep if years_to_retire == 2.5 
	if `i' < 0 keep if years_to_retire == 0
	replace years_to_retire = `i'
	tempfile toappend
	save `toappend', replace
	restore
	append using `toappend'
}



********************************************************************************
* Calculate the forward rates for corporate bonds  
********************************************************************************

* For simplicity we just add on the average wedge between AA bonds and gilts over our sample period
* Given we don't have the same granularity in maturities for AA bonds as we do for gilts
* So we can't do the same exercise 

gen real_aa_forward_rate = real_gilt_forward_rate + $aagiltdiff

* Save 
compress
save "$workingdata/real_forward_rates", replace



