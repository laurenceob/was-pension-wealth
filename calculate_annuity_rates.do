/********************************************************************************
**** Title: 		calculate_annuity_rates.do 
**** Author: 		Laurence O'Brien 
**** Date started: 	25/06/2025
**** Description:	Calculate annuity rates by year/month and distance to retirement 
********************************************************************************/
local yoblo 1921 
local yobmi 1950
local agelo 35
local agemi 55 

********************************************************************************
* Calculate annuity rates by year of data, retirement age, doby, year and month
********************************************************************************

use "$workingdata/real_forward_rates", clear 

* Merge in survivals 
joinby year using "$workingdata/survivals_allyears"

* Calculate implied retirement age 
gen retage = (year + years_to_retire) - doby

* And only keep relevant retirement ages 
keep if inrange(retage, 60, 68) | years_to_retire == 0 
drop if mod(retage, 1) != 0 
assert retage >= `agemi' if doby < `yobmi'
drop if retage < `agelo' & doby >= `yobmi'

sort year month doby female years_to_retire age real_gilt_forward_rate survival
order year month doby female years_to_retire age real_gilt_forward_rate real_aa_forward_rate survival

* Renormalise survivals and remove years before annuity purchase 
drop if age < retage
egen first_surv = max(survival), by(year month doby years_to_retire female)
egen first_psurv = max(partner_survival), by(year month doby years_to_retire female)
assert retage == 55 if first_surv == 1 & doby < `yobmi'
assert inlist(retage, 35, 55) if first_surv == 1
assert !missing(first_surv) & !missing(first_psurv)
drop if first_surv == 0 | first_psurv == 0
replace survival = survival / first_surv
replace partner_survival = partner_survival / first_psurv
assert survival <= 1 & partner_survival <= 1
drop first_surv first_psurv
assert !missing(survival)

* Calculate the joint probability of the partner surviving and the original person not surviving 
gen idie_psurvive = (1 - survival) * partner_survival

* Everyone gets a lump sum benefit if die within first five years of claiming 
* So essentially survival probability is 1 for the first five years 
replace survival = 1 if age < retage + 5

* Calculate the different discount rate/rates of return
ren (real_gilt_forward_rate real_aa_forward_rate) (gilt_rate aa_rate)
gen scpe_rate = 0.03 // SCAPE rate initially set at CPI+3 in 2011 budget. Assume same rate before that
replace scpe_rate = 0.028 if year > 2016 | (year == 2016 & month >= 4) 
// SCAPE rate reduced to CPI+2.8 in 2016 Budget (16 Mar 2016)
replace scpe_rate = 0.024 if year > 2018 | (year == 2018 & month >= 11)
// SCAPE rate reduced to CPI+2.4 in 2018 Budget (29 Oct 2018)

gen constant_rate = $constant_rate

* Calculate the annuity rates
* Account for the fact that in 2011 DB pensions typically increased in line with RPI 
* https://www.sackers.com/publication/pension-increases-the-change-from-rpi-to-cpi/
foreach x in gilt scpe aa constant {
	
	* For single people
	gen tosum_ind = . 
	replace tosum_ind = survival * (1 / (1 + `x'_rate)) ^ (age - retage) ///
		if year > 2011 | (year == 2011 & month >= 4)
	replace tosum_ind = survival * ((1 + $rpicpiwedge) / (1 + `x'_rate)) ^ (age - retage) ///
		if year < 2011 | (year == 2011 & month < 4)
	egen anntyfctr_ind_`x' = sum(tosum_ind), by(year month doby retage female)
	drop tosum_ind
	
	* For people in couples 
	gen tosum_cpl = . 
	replace tosum_cpl = (survival + 0.5 * idie_psurvive) * (1 / (1 + `x'_rate)) ^ (age - retage) ///
		if year > 2011 | (year == 2011 & month >= 4)
	replace tosum_cpl = (survival + 0.5 * idie_psurvive) * ((1 + $rpicpiwedge) / (1 + `x'_rate)) ^ (age - retage) ///
		if year < 2011 | (year == 2011 & month < 4)
	egen anntyfctr_cpl_`x' = sum(tosum_cpl), by(year month doby retage female)
	drop tosum_cpl 
	
}

* Collapse the year-month-doby-retirement age-sex level
collapse (mean) anntyfctr_*, by(year month doby retage female)


gen sex = female + 1
drop female 

sort year month doby retage sex 

* Reshape a bit 
tempfile toappend
foreach x in ind cpl {
	preserve 
	keep year month doby retage sex *`x'*
	ren *_`x'_* *_*
	if "`x'" == "ind" gen single = 1
	if "`x'" == "cpl" gen single = 0
	
	if "`x'" == "cpl" append using `toappend'
	save `toappend', replace 
	restore
}
use `toappend', clear 

sort year month doby retage sex single 

* Copy for some younger/older dobys we're missing 
qui sum doby if sex == 1 
local mindobymen = r(min)
local maxdobymen = r(max)
qui sum doby if sex == 2 
local mindobywomen = r(min)
local maxdobywomen = r(max)
forval i = `mindobymen'/`mindobywomen' {
	if `i' == `mindobywomen' continue 
	
	preserve 
	keep if doby == `mindobywomen' & sex == 2 
	replace doby = `i' 
	replace retage = year - doby if retage >= 70
	tempfile toappend 
	save `toappend', replace 
	restore 
	append using `toappend'	
}

forval i = `maxdobymen'/`maxdobywomen' {
	if `i' == `maxdobymen' continue 
	
	preserve 
	keep if doby == `maxdobymen' & sex == 1
	replace doby = `i'
	tempfile toappend 
	save `toappend', replace 
	restore 
	append using `toappend'
	
}

* Save 
save "$workingdata/annuity_rates", replace 




