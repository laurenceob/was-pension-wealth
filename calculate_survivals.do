/********************************************************************************
**** Title: 		calculate_survivals.do 
**** Author: 		Laurence O'Brien 
**** Date started: 	21/06/2025
**** Description:	Calculate survival probabilities by age, cohort and sex. Also partner survival probs. 
					These are needed for annuity rate calcs 
					Note one annoying thing is that I have data for loads more years in 2008/10/20/22 than in 2012/14/16/18.
					So I have to copy across surivival probabilities for these years for 2012-18 from either 2010 or 2020 
********************************************************************************/

********************************************************************************
* Calculate survivals over time
********************************************************************************

local yoblo 1921 
local yobmi 1950
local yobhi 2005
local agelo 35
local agemi 55 
local agehi 125 

foreach sx in males females {
	
	local SX = strproper("`sx'")

	* Loop over projections which we have the full data for

	foreach year in 2008 2010 2020 2022 {

		* Import 
		if `year' == 2008 {
			import excel using "$rawdata/qx`year'.xls", sheet("Principal `sx'_period") cellrange(A7) firstrow clear
		}
		if `year' == 2010 {
			import excel using "$rawdata/qx`year'.xls", sheet("Principal `sx'_period") cellrange(A7) firstrow clear
		}
		if `year' == 2020 {
			import excel using "$rawdata/qx`year'.xlsx", sheet("Period qx `SX'") cellrange(A6) firstrow clear
		}
		if `year' == 2022 {
			import excel using "$rawdata/qx`year'.xlsx", sheet("Period `SX' qx") cellrange(A6) firstrow clear
		}
		
		missings dropvars, force
		missings dropobs, force

		* Rename variables 
		local yr = 1981 
		local frst = 0
		foreach var of varlist _all {
			
			if `frst' == 0 {
				ren `var' age 
				local frst 1
				continue
			}
			
			ren `var' qx`yr'
			local yr = `yr' + 1
			
		}
		
		* Reshape 
		reshape long qx, i(age) j(year)
		gen yob = year - age
		drop year

		* Normalise to probability of dying 
		replace qx = qx / 100000
		
		* Save temporarily
		tempfile qxdata`year'
		save `qxdata`year'', replace

		* Just keep ages we care about 
		keep if inrange(yob, `yoblo', `yobhi')
		keep if inrange(age, `agelo', 125)

		* Reshape again
		reshape wide qx, i(age) j(yob)
		
		* Copy for the few years which we are missing 
		forval i = 1925(-1)1921 {
			replace qx`i' = qx`=`i'+1' if missing(qx`i') & !missing(qx`=`i'+1')
		}
	
		* Create survival probabilities  
		forval i = `yoblo'/`yobhi' {
			if `i' < `yobmi' {
				gen survival`i' = 1 if age == `agemi'
				replace survival`i' = survival`i'[_n-1]*(1-qx`i'[_n-1]) if age > `agemi'
			}
			else {
				gen survival`i' = 1
				replace survival`i' = survival`i'[_n-1]*(1-qx`i'[_n-1]) if age > `agelo'
			}
		}
		
		drop qx*

		* Reshape yet again 
		reshape long survival, i(age) j(doby)

		drop if age >= 115
		assert age >= 110 | (age < `agemi' & doby < `yobmi') if missing(survival)
		replace survival = 0 if missing(survival) & age >= 110
		
		* Save
		save "$workingdata/survivals`year'_`sx'", replace
	}


	* For the years where we don't have the full data I'm going to add in some of the qx's from nearby data
	foreach year in 2012 2014 2016 2018 {
		
		import excel using "$rawdata/qx`year'.xls" , sheet("`SX' period qx") cellrange(A7) firstrow clear
		
		missings dropvars, force
		missings dropobs, force

		* Rename variables 
		local yr = 1981 
		local frst = 0
		foreach var of varlist _all {
			
			if `frst' == 0 {
				ren `var' age 
				destring age, replace force
				local frst 1
				continue
			}
			
			ren `var' qx`yr'
			local yr = `yr' + 1
			
		}
		
		* Reshape 
		missings dropobs, force
		reshape long qx, i(age) j(year)
		gen yob = year - age
		drop year

		* Normalise to probability of dying 
		replace qx = qx / 100000
		
		* Merge in the missing bits from a projection from a nearby year 
		ren qx qx_orig 
		if `year' < 2015 merge 1:1 age yob using `qxdata2010', assert(2 3)
		if `year' >= 2015 merge 1:1 age yob using `qxdata2020', assert(2 3)
		replace qx_orig = qx if missing(qx_orig)
		drop qx _merge 
		ren qx_orig qx
		
		* Just keep ages we care about 
		keep if inrange(yob, `yoblo', `yobhi')
		keep if inrange(age, `agelo', 125)

		* Reshape again
		reshape wide qx, i(age) j(yob)
		
		* Copy for the few years which we are missing 
		forval i = 1925(-1)1921 {
			replace qx`i' = qx`=`i'+1' if missing(qx`i') & !missing(qx`=`i'+1')
		}

		* Create survival probabilities  
		forval i = `yoblo'/`yobhi' {
			if `i' < `yobmi' {
				gen survival`i' = 1 if age == `agemi'
				replace survival`i' = survival`i'[_n-1]*(1-qx`i'[_n-1]) if age > `agemi'
			}
			else {
				gen survival`i' = 1
				replace survival`i' = survival`i'[_n-1]*(1-qx`i'[_n-1]) if age > `agelo'
			}
		}
		drop qx*

		* Reshape yet again 
		reshape long survival, i(age) j(doby)

		drop if age >= 115
		assert age >= 110 | (age < `agemi' & doby < `yobmi') if missing(survival)
		replace survival = 0 if missing(survival) & age >= 110
		
		* Save 
		save "$workingdata/survivals`year'_`sx'", replace
		
	}
}


********************************************************************************
* Add in partner survivals
********************************************************************************

foreach year in 2008 2010 2012 2014 2016 2018 2020 2022 {

	***** For men
	use "$workingdata/survivals`year'_males", clear 

	* Assume that their partner is two years younger than them 
	gen partner_doby = doby + 2
	gen partner_age = age - 2

	* Get their partner's survivals
	preserve 
	use "$workingdata/survivals`year'_females", clear 
	ren (doby age survival) (partner_doby partner_age partner_survival)
	tempfile tomerge_women 
	save `tomerge_women', replace 
	restore 
	merge 1:1 partner_doby partner_age using `tomerge_women'
	replace partner_survival = 0 if partner_age > 110 & missing(partner_survival)
	replace partner_survival = 1 if age >= `agemi' & doby < `yobmi' & missing(partner_survival)
	replace partner_survival = 1 if age >= `agelo' & doby >= `yobmi' & missing(partner_survival)
	drop if _merge == 2 | missing(partner_survival)
	drop _merge

	drop partner_age partner_doby 
	
	* Have some merging issues given we have two starting ages and different partner ages 
	assert inrange(doby, `=`yobmi'-2', `=`yobmi'-1') & age < `agemi' if missing(survival)
	drop if missing(survival)
	// Renormalise so that survival is from age 50 for the partner for these dobys 
	egen maxpsurv = max(partner_survival), by(doby)
	assert inrange(doby, `=`yobmi'-2', `=`yobmi'-1') if maxpsurv < 1
	replace partner_survival = partner_survival / maxpsurv
	drop maxpsurv
	
	* Save 
	save "$workingdata/survivals`year'_males_partner", replace


	***** For women
	use "$workingdata/survivals`year'_females", clear 

	* Assume that their partner is two years older than them 
	gen partner_doby = doby - 2
	gen partner_age = age + 2

	* Get their partner's survivals
	preserve 
	use "$workingdata/survivals`year'_males", clear 
	ren (doby age survival) (partner_doby partner_age partner_survival)
	tempfile tomerge_men 
	save `tomerge_men', replace 
	restore 
	merge 1:1 partner_doby partner_age using `tomerge_men'
	replace partner_survival = 0 if partner_age > 110 & missing(partner_survival)
	replace partner_survival = 1 if age >= `agemi' & doby < `yobmi' & missing(partner_survival)
	replace partner_survival = 1 if age >= `agelo' & doby >= `yobmi' & missing(partner_survival)
	drop if _merge == 2 | missing(partner_survival)
	drop _merge
	drop if doby < 1923
	drop if age < `agemi' & doby < `=`yobmi'+2'
	
	* Renormalise survivals again 
	egen maxsurv = max(survival), by(doby)
	egen maxpsurv = max(partner_survival), by(doby)
	assert inrange(doby, `yobmi', `=`yobmi'+1') if  maxsurv < 1
	replace survival = survival / maxsurv 
	replace partner_survival = partner_survival / maxpsurv
	drop maxsurv maxpsurv
	
	* Make joint probability of their partner surviving and they have died 
	drop partner_age partner_doby

	* Save 
	save "$workingdata/survivals`year'_females_partner", replace
}
********************************************************************************
* Append survival data together 
********************************************************************************

* Append the survivals 
tempfile toappend 
forval year = 2006/2024 {
	foreach sx in males females {
	
		if inrange(`year', 2006, 2009) use "$workingdata/survivals2008_`sx'_partner", clear 
		if inrange(`year', 2010, 2011) use "$workingdata/survivals2010_`sx'_partner", clear 
		if inrange(`year', 2012, 2013) use "$workingdata/survivals2012_`sx'_partner", clear 
		if inrange(`year', 2014, 2015) use "$workingdata/survivals2014_`sx'_partner", clear 
		if inrange(`year', 2016, 2017) use "$workingdata/survivals2016_`sx'_partner", clear 
		if inrange(`year', 2018, 2019) use "$workingdata/survivals2018_`sx'_partner", clear 
		if inrange(`year', 2020, 2021) use "$workingdata/survivals2020_`sx'_partner", clear 
		if `year' >= 2022 use "$workingdata/survivals2022_`sx'_partner", clear 
		
		gen year = `year'
		
		if "`sx'" == "males" gen female = 0 
		else gen female = 1
		
		if `year' > 2006 | "`sx'" != "males" append using `toappend'
		save `toappend', replace 
	}
}

use `toappend', clear 
order year doby female age survival 
sort year doby female age
compress
save "$workingdata/survivals_allyears", replace 








