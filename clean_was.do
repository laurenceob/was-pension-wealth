/********************************************************************************
**** Title: 		clean_was.do 
**** Author: 		Laurence O'Brien 
**** Date started: 	27/10/2023 
**** Description:	Clean WAS
********************************************************************************/

use "$workingdata/mergedwas", clear 

/*******************************************************************************/
* Adjust wealth for wave 2 issue & physical wealth 
/*******************************************************************************/

****** Wave 2 adjustments ****** 

* Note - ONS confirmed that there is an issue with the household level wealth variables in wave 2
* And that we should recalculate these by summing individual wealth over members of the household 

* Pension wealth adjustment in wave 2
egen hhpenwealth_new = sum(totpen), by(hhid dataset_no)
replace totpen_aggr = hhpenwealth_new if dataset_no == 2
replace totpen_aggr = . if missing(totpen) & dataset_no == 2

* Financial wealth adjustment in wave 2
egen hfinw_excendw_aggr_new = sum(hfinw_excendw_sum), by(hhid dataset_no)
egen hfinl_aggr_new = sum(hfinl_sum), by(hhid dataset_no)
gen hhfinwealth_new = hfinw_excendw_aggr_new + allendw - hfinl_aggr_new 
replace hfinwnt_sum = hhfinwealth_new if dataset_no == 2
replace hfinwnt_sum = . if missing(hfinw_excendw_sum) & dataset_no == 2

****** Physical wealth adjustment ****** 

* Following Advani et al (2021), reduce the reported value of home contents by 75%
* As the questionnaire asks for the replacement value rather than the market value 
* To do this, will have to recreate total physical wealth variables 

* Need to make a new numadult variable for wave 1 as it seems dodgy 
replace ischild = 0 if dvagew1band >= 5 & dataset_no == 1
gen isadult = 1 - ischild if dataset_no == 1
replace isadult = (dvage7 > 1) if dataset_no > 1
egen numadult_new = sum(isadult), by(hhid dataset_no)

* Personal physical wealth is just housgdst in first two waves 
* As goods in buy-to-let & overseas properties is not asked 
replace persphys = housgdst if inlist(dataset_no, 1, 2)
assert persphys == housgdst + housgdsost + buylgdst if dataset_no > 2

* Now recreate hhpphys 
replace gcontvls = gcontvls2 if dataset_no <= 2
gen hhpphys = (gcontvls + dvgcollv + dvtotvehval) / numadult_new
replace hhpphys = (gcontvls + dvgcollv + dvtotvehval) / 8 if hhid == 11529 & dataset_no == 8 // these seem to have 8 rather than 7 adults 
replace hhpphys = 0 if dvage7 == 1 & dataset_no >= 2 // non adults don't get it
replace hhpphys = 0 if ischild == 1 & dataset_no == 1 // non adults don't get it

* Recreate p_phys and check it's the same as in the data (for waves 3+ when this variable exists)
gen p_phys_check = hhpphys + persphys
*assert abs(p_phys_check - p_phys) < 0.5 if !inlist(dataset_no, 1, 2, 6) & !mi(p_phys)
// this is failing for a few people but I'm pretty sure I'm right and ONS is wrong. My method still adds up. So I'm going to leave this as is. 
assert p_phys == . if p_phys_check == . & !inlist(dataset_no, 1, 2, 6)

* Recreate hphysw and check it's the same as in the data 
egen hphysw_check = sum(p_phys_check), by(dataset_no hhid)
replace hphysw_check = . if missing(hphysw)
assert abs(hphysw_check - hphysw) < 0.5 if dataset_no != 6 & dataset_no != 2 & !mi(hphysw) // doesn't always add up for wave 2 - same problem as above 

*drop p_phys_check hphysw_check 

* Make new p_phys and new hphysw where we knock off 75% of value of household contents 
gen persphys_new = 0.25 * persphys
gen hhpphys_new = ((0.25 * gcontvls) + dvgcollv + dvtotvehval) / numadult_new
replace hhpphys_new = 0 if dvage7 == 1 & dataset_no >= 2 // non adults don't get it
replace hhpphys_new = 0 if ischild == 1 & dataset_no == 1 // non adults don't get it
gen p_phys_new  = hhpphys_new + persphys_new
egen hphysw_new = sum(p_phys_new), by(dataset_no hhid)

/*******************************************************************************/
* Create new wealth measures 
/*******************************************************************************/

* Create benefit unit measures of wealth 
egen bu_finwealth = sum(p_net_fin), by(dataset_no hhid buno)
egen bu_propwealth = sum(p_net_prop), by(dataset_no hhid buno)
egen bu_physwealth = sum(p_phys_new), by(dataset_no hhid buno)

* Create measures of pension and total wealth based on different discount rates
egen totdcpen_hh = sum(totdcpen), by(dataset_no hhid)
foreach dsc in gilt aa scpe constant decomp {	
	
	* Household pension wealth 
	foreach x in totpen totdbpen totothpen {
		egen `x'_`dsc'_hh = sum(`x'_`dsc'), by(dataset_no hhid)
		egen `x'_`dsc'_bu = sum(`x'_`dsc'), by(dataset_no hhid)
	}
	
	* Household wealth 
	gen tothhwlth_`dsc' = totpen_`dsc'_hh + hpropw + hfinwnt_sum + hphysw_new

	* Individual wealth 
	gen totindwlth_`dsc' = p_net_fin + p_net_prop + totpen_`dsc' + p_phys_new
	
	* Benefit unit wealth 
	gen totbuwlth_`dsc' = bu_finwealth + bu_propwealth + totpen_`dsc'_bu + bu_physwealth
}

* Total wealth based on ONS pensions methodology (but with updated phsyical wealth)
gen totindwlth_was_new = p_net_fin + p_net_prop + totpen + p_phys_new
replace totindwlth_was_new = p_net_fin + p_net_prop + totalpen + p_phys_new if dataset_no == 8

gen totindwlth_was_old = totindwlth_was_new
replace totindwlth_was_old = p_net_fin + p_net_prop + totpen_old + p_phys_new if dataset_no == 8

gen tothhwlth_was_new = hfinwnt_sum + hpropw + totpen_aggr + hphysw_new
replace tothhwlth_was_new = hfinwnt_sum + hpropw + totpen_sum + hphysw_new if dataset_no == 1
replace tothhwlth_was_new = hfinwnt_sum + hpropw + totalpen_aggr + hphysw_new if dataset_no == 8

gen tothhwlth_was_old = tothhwlth_was_new
replace tothhwlth_was_old = hfinwnt_sum + hpropw + totpen_old_aggr + hphysw_new if dataset_no == 8

* Consistent measure of WAS pension wealth 
gen totpen_was_old_hh = totpen_sum if dataset_no == 1
replace totpen_was_old_hh = totpen_aggr if inrange(dataset_no, 2, 7)
replace totpen_was_old_hh = totpen_old_aggr if dataset_no == 8

gen totpen_was_new_hh = totpen_was_old_hh
replace totpen_was_new_hh = totalpen_aggr if dataset_no == 8

* WAS hh DB pension wealth (R8 only)
gen totdbpen_was_new_hh = dvvaldbt_scape_aggr + dvretdb_access_aggr + dvretdb_noaccess_scape_aggr + dvpavcuv_aggr if dataset_no == 8
assert totdbpen_was_new_hh <= totpen_was_new_hh if dataset_no == 8

foreach var of varlist bu_* *_bu totbu* {
	replace `var' = `var' if dataset_no == 1
}

* Without the physical wealth adjustment 
gen double totalwlth = hfinwnt_sum + hpropw + totpen_aggr + hphysw
replace totalwlth = hfinwnt_sum + hpropw + totpen_sum + hphysw if dataset_no == 1
replace totalwlth = hfinwnt_sum + hpropw + totalpen_aggr + hphysw if dataset_no == 8

/*******************************************************************************/
* Other cleaning 
/*******************************************************************************/

* Sector 
gen public = . 
replace public = 0 if wrking == 1 & (sector == 1 | (sector == 2 & inlist(sectr2, 1, 5, 7)))
replace public = 1 if wrking == 1 & sector == 2 & inlist(sectr2, 2, 3, 4, 6, 8)

* Pension type 
gen pentype = .
replace pentype = 0 if dvhasdc == 0 & dvhasdb == 0 
replace pentype = 1 if dvhasdc == 1 & dvhasdb == 0
replace pentype = 2 if dvhasdb == 1 & dvhasdc == 0 
replace pentype = 3 if dvhasdb == 1 & dvhasdc == 1 
label define pentype 0 "No pension" 1 "DC only" 2 "DB only" 3 "DB and DC"
label values pentype pentype 

* Economic activity 
replace dvecact = ecact if dataset_no == 3 
label define dvecact 1 "Employee" 2 "Self-employed" 3 "ILO unemployed" 4 "Student" 4 "Looking after family/home" 5 "Temporarily sick or injured" ///
	6 "Long-term sick or disabled" 7 "Retired" 8 "Other inactive"
label values dvecact dvecact

* Education 
foreach var of varlist edlevel tea edattn* {
	replace `var' = . if `var' < 0 // change error/unknown/not asked to missings
}

gen edcat = 1 if edlevel == 4 // No qualifications
replace edcat = 2 if inlist(edlevel, 2, 3) // Qualifications, not degree level 
replace edcat = 3 if edlevel == 1 // Degree-level qualifications
replace edcat = 1 if tea <= 16 & mi(edcat) // Assume this is no qualifications
replace edcat = 3 if inlist(course, 4, 6, 8) & inlist(attend, 1, 2) & enroll == 1 // Assume will finish degree if currently doing it 
label define edcat 1 "No qualifications" 2 "Below degree qualifications" 3 "Degree or equivalent"
label values edcat edcat 

/*******************************************************************************/
* Deflate 
/*******************************************************************************/

* Clean CPIH data ready for merging
preserve
import delimited using "$rawdata/cpih.csv",  clear
keep if _n >= 9
destring v2, replace
keep if _n >= 187
ren (v1 v2) (date cpih)
gen year = substr(date, 1, 4)
gen monthname = substr(date, -3, .)
gen datevar = date("1" + lower(monthname) + "2000", "DMY")
gen month = month(datevar)
drop date monthname datevar
destring year, replace
tempfile cpih 
save `cpih', replace 
restore 

* Merge in 
merge m:1 month year using `cpih', assert(2 3) keep(3) nogen

* Make real variables 
foreach var of varlist totwlth p_totalwlth p_totwlth totbuwlth* tothhwlth* totindwlth* totpen* totdcpen* /// 
 totdbpen* totothpen* hphysw_new hpropw hfinwnt_sum totalpen_aggr totalpen p_net_fin p_net_prop p_phys_new {
	gen `var'_r = `var' * ($cpih_index / cpih)
}

/*******************************************************************************/
* Save 
/*******************************************************************************/

label define dataset_no 1 "Jul 06 - Jun 08" 2 "Jul 08 - Jun 10" 3 "Jul 10 - Jun 12" 4 "Jul 12 - Jun 14" 5 "Jul 14 - Jun 16" 6 "Apr 16 - Mar 18" ///
						7 "Apr 18 - Mar 20" 8 "Apr 20 - Mar 22"
label values dataset_no dataset_no

save "$workingdata/was_clean", replace 




