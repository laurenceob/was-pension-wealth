********************************************************************************
/*            		  Correcting DB wealth variables 		                  */
/* 																			  */
/*																			  */
/* Author: I Delestre & L O'Brien											  */
/* Date started: 09/02/2023													  */
********************************************************************************

cap program drop create_penvars_earlywaves
program define create_penvars_earlywaves

	syntax, dset(string)

	* Whether has a DB occupational scheme
	gen frstsch`dset' = 1 if ((poctyp_f`dset'_i == 2 & pocnmsc`dset'_i > 0) | (poctyp_f`dset'_i == 3 & pbfrac_f`dset'_iflag != 1 & pocnmsc`dset'_i > 0))
	replace frstsch`dset' = 2 if missing(frstsch`dset')
	gen scndsch`dset' = 1 if ((poctyp_s`dset'_i == 2 & pocnmsc`dset'_i > 0) | (poctyp_s`dset'_i == 3 & pbfrac_s`dset'_iflag != 1 & pocnmsc`dset'_i > 0))
	replace scndsch`dset' = 2 if missing(scndsch`dset')
	
	* Pension age correction for negative powers 
	* this might be in poraget... i'll check 
	gen rf`dset' = 60 if inrange(porage_f`dset', -6, -9) & frstsch`dset' == 1
	replace rf`dset' = 50 if inrange(porage_f`dset', 0, 49) & frstsch`dset' == 1
	replace rf`dset' = porage_f`dset' if missing(rf`dset') 
	gen rs`dset' = 60 if inrange(porage_s`dset', -6, -9) & scndsch`dset' == 1
	replace rs`dset' = 50 if inrange(porage_s`dset', 0, 49) & scndsch`dset' == 1
	replace rs`dset' = porage_s`dset' if missing(rs`dset') 

	* Do some renaming to make consistent across datasets
	ren (asaft_f`dset' asaft_s`dset') (asaf1t`dset' asaf2t`dset')
	ren (pblumv_f`dset'_i pblumv_s`dset'_i) (pblumv1`dset'_i pblumv2`dset'_i)
	ren (dvpeninc_f`dset' dvpeninc_s`dset') (dvpeninc1`dset' dvpeninc2`dset')
	
	* One person hasn't had their lump sum imputed for some reason 
	* I'm just going to give them the median imputed value 
	qui sum pblumv1`dset'_i if frstsch`dset' == 1 & pblumv_f`dset'_iflag == 1, d
	replace pblumv1`dset'_i = r(p50) if pblumv1`dset'_i  < 0 & frstsch`dset' == 1
	
	* Unadjusted powers aka distance to reported retirement age 
	gen power1t`dset' = .
	replace power1t`dset' = rf`dset' - dvage`dset'band if dvage`dset'band <= rf`dset'& frstsch`dset' == 1
	replace power1t`dset' = 0 if dvage`dset'band > rf`dset'& frstsch`dset' == 1
	
	gen power2t`dset' = .
	replace power2t`dset' = rs`dset' - dvage`dset'band if dvage`dset'band <= rs`dset'& scndsch`dset' == 1
	replace power2t`dset' = 0 if dvage`dset'band > rs`dset'& scndsch`dset' == 1
	
	
end 

cap program drop adjust_retage
program define adjust_retage

	syntax, dset(string)
	
	foreach x in f s {
		if "`dset'" == "w3" local r`x' r`x' 
		else local r`x' r`x'`dset'
	}

	forval i = 1/2 {

		if `i' == 1 {
			local penage_var `rf'
			local dbflag frstsch`dset'
		}
		if `i' == 2 {
			local penage_var `rs' 
			local dbflag scndsch`dset'
		}
		
		* Create a normal retirement age variable with a floor of 60 (consistent with R8 change)
		gen ret_age_adj_`i' = 0
		
		* Retain reported age if between 60 and 68 
		replace ret_age_adj_`i' = `penage_var' if `dbflag' == 1 & inrange(`penage_var', 60, 68)
		
		* Otherwise set to 60/68 
		replace ret_age_adj_`i' = 60 if `dbflag' == 1 & `penage_var' < 60 & !missing(`penage_var')
		replace ret_age_adj_`i' = 68 if `dbflag' == 1 & `penage_var' > 68 & !missing(`penage_var')

	}

end 

cap program drop clean_penwealth
program define clean_penwealth

	syntax, dset(string) disc_type(string) ann_type(string) sfx(string)
	
	* Check inputs
	assert inlist("`disc_type'", "gilt", "scpe", "aa", "constant", "wasOLD")
	if "`disc_type'" == "gilt" {
		local discount_rate1 real_gilt_yield1 // Current DB pension 1
		local discount_rate2 real_gilt_yield2 // Current DB pension 2
		local discount_rate3 real_gilt_yield3 // Own retained rights
		local discount_rate4 real_gilt_yield4 // Partner retained rights (assert this is the same)
	}
	else {
		forval i = 1/4 {
			if "`disc_type'" == "scpe" local discount_rate`i' scpe_rate
			if "`disc_type'" == "aa" local discount_rate`i' real_aa_yield 
			if "`disc_type'" == "constant" local discount_rate`i' constant_rate
			if "`disc_type'" == "wasOLD" local discount_rate`i' mnthscape`dset'
		}
	}
	
	assert inlist("`ann_type'", "gilt", "scpe", "aa", "constant", "wasOLD")
	
	if "`i'" != "wasOLD" {
		forval i = 1/5 {
			local ann_factor`i' anntyfctr_`ann_type'`i'
		}
	}	
	else {
		local ann_factor1 asaf1t`dset'
		local ann_factor2 asaf2t`dset'
		local ann_factor3 retfrac`dset' 
		local ann_factor4 retfrac`dset'
		local ann_factor5 ageasaf`dset' // Pensions in payment 
	}
	
	
	local suffix "_`sfx'"
	
	* Adjust for changes in variable names between rounds/waves 
	foreach x in dvwid dvsps dvpinpval {
		if "`dset'" != "r8" local `x' `x'`dset'
		if "`dset'" == "r8" local `x' `x'_oldr8
	}
	foreach x in f s {
		if "`dset'" == "w3" local r`x' r`x' 
		else local r`x' r`x'`dset'
	}
	if inlist("`dset'", "r7", "r8") {
		if "`dset'" == "r8" local dvdbrwealth dvretdb_noaccess_oldr8
		if "`dset'" == "r7" local dvdbrwealth dvretdb_noaccess`dset'
		local dvpfcurval dvretdc_noaccess`dset'
	}
	else {
		local dvdbrwealth dvdbrwealthval`dset'
		local dvpfcurval dvpfcurval`dset'
	}
	if "`dset'" == "r8" {
		local totpen totpen_oldr8 
		local pincinp pincinp_oldr8 
	}
	else {
		local totpen totpen`dset'
		local pincinp pincinp`dset'
	}
	
	* Adjust occupational pension variables
	********************************************************************************

	/* This section creates adjusted variables for the total wealth accumulated
	in up to two active occupational DB pensions. */

	forvalues i = 1/2 {
		* Loop declarations
		if `i' == 1 {
			local penage_var `rf'
			local dbflag frstsch`dset'
		}

		if `i' == 2 {
			local penage_var `rs'
			local dbflag scndsch`dset'
		}
		
		* Create adjusted numerator variable
		g topdvdbopen`i't`dset'`suffix' = 0
		lab var topdvdbopen`i't`dset'`suffix' "IFS adjusted occupational DB numerator (scheme `i')"

		* Adjust numerator
		assert pblumv`i'`dset'_i >= 0 if `dbflag' == 1
		assert `ann_factor`i'' > 0 & !missing(`ann_factor`i'') if `dbflag' == 1
		replace topdvdbopen`i't`dset'`suffix' = ((`ann_factor`i''*dvpeninc`i'`dset') + pblumv`i'`dset'_i) if `dbflag' == 1

		* Create adjusted denominator variable
		g botdvdbopen`i't`dset'`suffix' = 0
		lab var botdvdbopen`i't`dset'`suffix' "IFS adjusted occupational DB denominator (scheme `i')"

		* Work out years until retirment
		g power`i't`dset'`suffix' = 0
		lab var power`i't`dset'`suffix' "IFS adjusted years until individual reaches normal retirement age (scheme `i')"
		replace power`i't`dset'`suffix' = ret_age_adj_`i' - (`penage_var'-power`i't`dset') if `dbflag' == 1 & (ret_age_adj_`i' > (`penage_var'-power`i't`dset')) & `penage_var' > 0

		* Adjust denominator		 
		replace botdvdbopen`i't`dset'`suffix' = ((`discount_rate`i'' + 1)^(power`i't`dset'`suffix')) if `dbflag' == 1

		* Create final variables
		g dvdbopen`i't`dset'`suffix' = 0
		lab var dvdbopen`i't`dset'`suffix' "IFS adjusted value of occupational DB pension (scheme `i')"
		replace dvdbopen`i't`dset'`suffix' = topdvdbopen`i't`dset'`suffix'/botdvdbopen`i't`dset'`suffix' if `dbflag' == 1
	}

	* Make total occupational DB wealth variables
	g dvvaldbt`dset'`suffix' = dvdbopen1t`dset'`suffix' + dvdbopen2t`dset'`suffix' 
	lab var dvvaldbt`dset'`suffix' "IFS adjusted total occupational DB pension wealth"

	*drop topdvdbopen* botdvdbopen*

	* Adjust value of retained rights
	********************************************************************************

	/* This section creates adjusted variables for retained pension rights. Here
	pension age is not an issue as respondents are not asked their normal pension age.
	Instead, it is assumed in WAS to be 65. Only the discount rate adjustment
	therefore needs to be made. */
	
	* Create exact age variable
	if !inlist("`dset'", "w1", "w2") {
		g age = 0
		replace age = 65 - (ln(((retfrac`dset'*dvdbincall`dset')+dvvalpblum`dset')/`dvdbrwealth')/ln(1+mnthscape`dset')) if inrange(dvage17`dset',1,13)
	}
	else gen age = dvage`dset'band
		
	* Create adjusted retained rights variable
	g `dvdbrwealth'`suffix' = 0
	lab var `dvdbrwealth'`suffix' "IFS adjusted total value of retainied DB rights"
	replace `dvdbrwealth'`suffix' = ((`ann_factor3'*dvdbincall`dset')+dvvalpblum`dset')/((1 + `discount_rate3')^(65-age)) if inrange(dvage17`dset',1,13) & `dvdbrwealth' > 0
	replace `dvdbrwealth'`suffix' = (`ann_factor3'*dvdbincall`dset')+dvvalpblum`dset' if inrange(dvage17`dset',14,17) & `dvdbrwealth' > 0

	* Drop unneeded variables
	drop age 
	
	* Adjust value of retained rights from previous partner
	********************************************************************************

	* Value of pensions expected from former spouse	
	g dvwid`dset'`suffix' = 0
	lab var dvwid`dset'`suffix' "IFS adjusted total value of pensions expected from former spouse"

	* Calculate exact age for those who give annual income
	if !inlist("`dset'", "w1", "w2") {
		g age = 0
		replace age = 65 - (ln((retfrac`dset'*pwexpa`dset'_i)/`dvwid')/ln(1 + mnthscape`dset')) ///
			if pwexph`dset'_i == 2 & pwidfut`dset'_i == 1 & inrange(dvage17`dset',1,13)
	}
	else {
		gen age = dvage`dset'band
	}
	
	* Where annual amount of expected income is given
	replace dvwid`dset'`suffix' = (`ann_factor4'*pwexpa`dset'_i)/((1 + `discount_rate4')^(65-age)) /// 
		if pwexph`dset'_i == 2 & pwidfut`dset'_i == 1 & inrange(dvage17`dset',1,13) & pwexpa`dset'_i >= 0

	* Calculate exact age for those who give monthly income
	if !inlist("`dset'", "w1", "w2") {
		replace age = 0
		replace age = 65 - (ln((retfrac`dset'*pwexpa`dset'_i*12)/`dvwid')/ln(1 + mnthscape`dset')) ///
			if pwexph`dset'_i == 3 & pwidfut`dset'_i == 1 & inrange(dvage17`dset',1,13) 
	}
	* Where monthly amount of expected income is given
	replace dvwid`dset'`suffix' = (`ann_factor4'*pwexpa`dset'_i*12)/((1 + `discount_rate4')^(65-age)) /// 
		if pwexph`dset'_i == 3 & pwidfut`dset'_i == 1 & inrange(dvage17`dset',1,13) & pwexpa`dset'_i >= 0 


	* Value of pensions expected from former spouse (this is not asked in Wave 1)
	g dvsps`dset'`suffix' = 0
	lab var dvsps`dset'`suffix' "IFS adjusted total value of pensions expected from former partner"

	* Calculate exact age for those who give annual income
	if !inlist("`dset'", "w1", "w2") {
		replace age = 0
		replace age = 65 - (ln((retfrac`dset'*pspexpa`dset'_i)/`dvsps')/ln(1 + mnthscape`dset')) ///
			if pspexph`dset'_i == 2 & pspse`dset'_i == 1 & inrange(dvage17`dset',1,13) 
	}
	* Where annual amount of expected income is given
	if "`dset'" != "w1" {
		replace dvsps`dset'`suffix' = (`ann_factor4'*pspexpa`dset'_i)/((1 + `discount_rate4')^(65-age)) /// 
			if pspexph`dset'_i == 2 & pspse`dset'_i == 1 & inrange(dvage17`dset',1,13) & pspexpa`dset'_i >= 0
	}
	* Calculate exact age for those who give monthly income
	if !inlist("`dset'", "w1", "w2") {
		replace age = 0
		replace age = 65 - (ln((retfrac`dset'*pspexpa`dset'_i*12)/`dvsps')/ln(1 + mnthscape`dset')) ///
			if pspexph`dset'_i == 3 & pspse`dset'_i == 1 & inrange(dvage17`dset',1,13)
	}
	if "`dset'" != "w1" {
	* Where monthly amount of expected income is given
		replace dvsps`dset'`suffix' = (`ann_factor4'*pspexpa`dset'_i*12)/((1 + `discount_rate4')^(65-age)) /// 
			if pspexph`dset'_i == 3 & pspse`dset'_i == 1 & inrange(dvage17`dset',1,13) & pspexpa`dset'_i >= 0
	}
	* Total value of pensions expected from spouse/partner
	g dvspen`dset'`suffix' = dvwid`dset'`suffix' + dvsps`dset'`suffix'
	lab var dvspen`dset'`suffix' "IFS adjusted total value of pensions expected from former spouse/partner"

	* Drop uneeded variables
	drop age

	* Adjust value of pensions in payment 
	*******************************************************************************
	
	gen dvpinpval`dset'`suffix' = 0
	label var dvpinpval`dset'`suffix' "IFS adjusted value of pensions in payment"
	
	replace `pincinp' = 0 if dvage17`dset' < 11 | missing(`pincinp')
	// Don't allow people to have positive pension income below age 50 as this is surely mostly measurement error 
	assert !missing(`ann_factor5') if !missing(`pincinp') & `pincinp' > 0
	
	replace dvpinpval`dset'`suffix' = `pincinp' * `ann_factor5' if !missing(`ann_factor5') & `pincinp' >= 0
	

	* Tabulate totals
	********************************************************************************

	foreach var of varlist dvvaldbt`dset'`suffix' dvvaldcos`dset' dvpavcuv`dset' dvppval`dset' `dvpfcurval' dvpfddv`dset' ///
	 dvpinpval`dset'`suffix' dvspen`dset'`suffix' {
	 	assert `var' >= 0 | mi(`var')
	 }
	
	#d ;
		g totpen`dset'`suffix' = dvvaldbt`dset'`suffix' + 	/* Adjusted IFS current occ DB pension wealth */
								 dvvaldcos`dset' +   		/* Current occ DC pension wealth */
								 dvpavcuv`dset' +   		/* Total value of AVCs scheme */ 
								 dvppval`dset' + 			/* Total value of personal pension scheme */
								 `dvpfcurval' + 			/* DC retained rights (no money accessed) */
								 `dvdbrwealth'`suffix' + 	/* Adjusted IFS DB retained rights (not accessed) */
								 dvpfddv`dset' + 			/* Total retained rights for drawdown */
								 dvpinpval`dset'`suffix' + 	/* Value of pensions in payment */
								 dvspen`dset'`suffix'		/* Adjusted IFS value of expected pensions from former spouse/partner */
	; #d cr

	lab var totpen`dset'`suffix' "IFS adjusted total pension wealth (discount rate & annuity adjustment)"

	
	cap confirm var totdcpen`dset'
	if _rc != 0	gen totdcpen`dset' = dvvaldcos`dset' + dvppval`dset' + `dvpfcurval'
	// This is: current occupational DC pen + current personal DC pen + previous DC pens (not accessed) 
	// But doesn't include previously accessed DC pensions as these are not split out before R7
	// Instead this is in oth pen

	gen totdbpen`dset'`suffix' = dvvaldbt`dset'`suffix' + `dvdbrwealth'`suffix' + dvpavcuv`dset'
	// Again this doesn't include previously accessed DB pensions
	
	gen totothpen`dset'`suffix' = dvpinpval`dset'`suffix' + dvspen`dset'`suffix' + dvpfddv`dset'
	// This includes previously accessed DB and DC pensions 
	
	assert !missing(totpen`dset'`suffix') if !missing(`totpen')

	drop if missing(case`dset')


end 




