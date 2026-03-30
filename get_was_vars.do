/********************************************************************************
**** Title: 		get_was_vars.do 
**** Author: 		Laurence O'Brien 
**** Date started: 	26/10/2023 
**** Description:	Append different rounds of WAS
********************************************************************************/

cap program drop main 
program define main 

	specify_analysis_variables
	merge_append_was

end 


cap program drop get_approx_retiredist
program define get_approx_retiredist

	* I merge in a government bond discount rate based on distance to retirement
	* Only have 5 year age band in EUL WAS (after wave 2)
	* So will do this approximately (assuming people are in the middle of the age band)
	* This code creates this approximate "distance to retirement" variable for the 5 different retirement ages used in WAS pension valuation 
	
	syntax, dset(string)
	
	if inlist("`dset'", "w1", "w2") {
		// we have age in years for the first two waves, except for young and old people. approximate these 
		gen dvage`dset'band_2 = dvage`dset'band 
		replace dvage`dset'band_2 = (dvage`dset'band * 5) - 2 if dvage`dset'band < 4 
		replace dvage`dset'band_2 = 12 + dvage`dset'band if inrange(dvage`dset'band, 4, 5)
		replace dvage`dset'band_2 = 85 if dvage`dset'band == 6
		gen doby = year`dset' - dvage`dset'band_2
		gen approxage = dvage`dset'band_2
	}
	else {
		gen approxage = (dvage17`dset' * 5) - 3 // this is the middle of the 5 year age band 
		gen doby = year`dset' - approxage
	}
	
	forval i = 1/4 {
		if `i' < 3 gen years_to_retire`i' = ret_age_adj_`i' - approxage
		if `i' > 2 gen years_to_retire`i' = 65 - approxage
		
		replace years_to_retire`i' = 40 if years_to_retire`i' > 40 & !mi(years_to_retire`i')
		replace years_to_retire`i' = 2.5 if ///
			years_to_retire`i' > 0 & years_to_retire`i' < 2.5 & !mi(years_to_retire`i')
		replace years_to_retire`i' = 0 if years_to_retire`i' <= 0 & !mi(years_to_retire`i')
	}
	gen years_to_retire5 = 0
	
	
end 

* This program makes globals specifying the variables from WAS individual and household datasets that we want in our analysis dataset 
* WAS does not have consistent variable naming conventions across years so it's a bit messy...
cap program drop specify_analysis_variables
program define specify_analysis_variables

	* Define globals of variables to keep 

	* Household datasets 
	global hhvarsw1 casew1 yearw1 monthw1 hpropww1 hphysww1 hfinwntw1_sum totpenw1_sum numadultw1 dvvaldbtw1_sum dvdbrwealthvalw1_sum xs_wgtw1 totwlthw1 gorw1 allendww1 dvgcollvw1 dvtotvehvalw1 gcontvls2w1 landovseatw1
	global hhvarsw2 casew2 yearw2 monthw2 hpropww2 hphysww2 hfinwntw2_sum totpenw2_sum numadultw2 dvvaldbtw2_sum dvdbrwealthvalw2_sum xs_calwgtw2 totwlthw2 gorw2 allendww2 dvgcollvw2 dvtotvehvalw2 gcontvls2w2 
	global hhvarsw3 casew3 yearw3 monthw3 hpropww3 hphysww3 hfinwntw3_sum totpenw3_aggr numadultw3 dvvaldbtw3_aggr dvdbrwealthvalw3_aggr w3xswgt totwlthw3 gorw3 allendww3 dvgcollvw3 dvtotvehvalw3 gcontvlsw3 
	global hhvarsw4 casew4 yearw4 monthw4 hpropww4 hphysww4 hfinwntw4_sum totpenw4_aggr numadultw4 dvvaldbtw4_aggr dvdbrwealthvalw4_aggr w4xshhwgt totwlthw4 allendww4 dvgcollvw4 dvtotvehvalw4 gcontvlsw4 
	global hhvarsw5 casew5 yearw5 monthw5 hpropww5 hphysww5 hfinwntw5_sum totpenw5_aggr numadultw5 dvvaldbtw5_aggr dvdbrwealthvalw5_aggr w5xshhwgt totwlthw5 gorw5 allendww5 dvgcollvw5 dvtotvehvalw5 gcontvlsw5 
	global hhvarsr6 caser6 yearr6 monthr6 hpropwr6 hphyswr6 hfinwntr6_sum totpenr6_aggr numadultw6 numadultw5 dvvaldbtr6_aggr dvdbrwealthvalr6_aggr r6xshhwgt ///
		totwlthr6 gorr6 allendwr6 dvgcollvr6 dvtotvehvalr6 gcontvlsr6 
	global hhvarsr7 caser7 yearr7 monthr7 hpropwr7 hphyswr7 hfinwntr7_sum totpenr7_aggr numadultr7 numadultr7 dvvaldbtr7_aggr r7xshhwgt totwlthr7 gorr7 allendwr7 dvgcollvr7 dvtotvehvalr7 gcontvlsr7 
	global hhvarsr8 caser8 yearr8 monthr8 hpropwr8 hphyswr8 hfinwntr8_sum totpenr8_aggr numadultr8 numadultr8 dvvaldbt_oldr8_aggr dvvaldbt_scaper8_aggr ///
		r8xshhwgt totwlth_oldr8 totpen_oldr8_aggr totalpenr8_aggr gorr8 allendwr8 dvpavcuvr8_aggr dvretdb_noaccess_scaper8_aggr dvretdb_accessr8_aggr dvgcollvr8 dvtotvehvalr8 gcontvlsr8 

	* Define global of variables to keep in the individual level datasets
	forval dataset_no = 1/8 {
		
		if `dataset_no' == 6 continue // Round 6 is weird because of the wave/round thing so doing this manually after 
		
		if inrange(`dataset_no', 1, 5) local mrkr = "w"
		if `dataset_no' > 5 local mrkr = "r"
		local wvsfx "`mrkr'`dataset_no'"
		
		#delimit ;
		global indvars`wvsfx'
			/* Identifiers */
			case`wvsfx' person`wvsfx' ishrp`wvsfx' 
			/* Interview info */
			year`wvsfx' month`wvsfx' persprox`wvsfx' 
			/* Demographics */
			dvage17`wvsfx' haschd`wvsfx' isdep`wvsfx' sex`wvsfx' dvmrdf`wvsfx'
			/* Working */
			wrking`wvsfx'
			/* Education */
			edlevel`wvsfx' edattn1`wvsfx' edattn2`wvsfx' edattn3`wvsfx' tea`wvsfx' course`wvsfx' 
			attend`wvsfx' enroll`wvsfx'	
			/* Pension saving */
			dvhasdb`wvsfx' dvhasdc`wvsfx' 
			/* Pension wealth */
			totdbpen`wvsfx'_gilt totothpen`wvsfx'_gilt totdcpen`wvsfx' totpen`wvsfx'_gilt 
			totdbpen`wvsfx'_aa totothpen`wvsfx'_aa totpen`wvsfx'_aa
			totdbpen`wvsfx'_scpe totothpen`wvsfx'_scpe totpen`wvsfx'_scpe
			totdbpen`wvsfx'_constant totothpen`wvsfx'_constant totpen`wvsfx'_constant
			dvpavcuv`wvsfx' dvpfddv`wvsfx'
			dvvaldcos`wvsfx' dvppval`wvsfx'
			/* Other things used for calculating pension wealth */
			anntyfctr* real_gilt_yield* real_aa_yield scpe_rate years_to_retire* ret_age_adj* asaf* topdvd* botdvd*
			/* Physical wealth variables */
			housgdst`wvsfx' 
			;
		#delimit cr 
		
		if `dataset_no' == 1 global indvarsw1 $indvarsw1 dvagew1band xs_wgtw1 hfinw_excendww1 hfinlw1 
		if `dataset_no' == 2 global indvarsw2 $indvarsw2 casew1 personw1 dvagew2band xs_calwgtw2 hfinw_excendww2_sum hfinlw2_sum  
		if `dataset_no' == 3 global indvarsw3 $indvarsw3 casew1 personw1 casew2 personw2 w3xswgt hfinw_excendww3_sum hfinlw3_sum ageasaf1w3 rf rs
		if `dataset_no' == 4 global indvarsw4 $indvarsw4 casew1 personw1 casew2 personw2 casew3 personw3 w4xsperswgt w4_nonproxy_wgt hfinw_excendww4_sum hfinlw4_sum ageasaf
		if `dataset_no' == 5 global indvarsw5 $indvarsw5 casew1 personw1 casew2 personw2 casew3 personw3 casew4 personw4 w5xsperswgt w5_nonproxy_wgt hfinw_excendww5_sum hfinlw5_sum 
		if `dataset_no' == 7 global indvarsr7 $indvarsr7 casew1 personw1 casew2 personw2 casew3 personw3 casew4 personw4 casew5 personw5 ///
			caser6 personw6 r7xsperswgt r7_nonproxy_wgt hfinw_excendwr7_sum hfinlr7_sum 
		if `dataset_no' == 8 global indvarsr8 $indvarsr8 casew1 personw1 casew2 personw2 casew3 personw3 casew4 personw4 casew5 personw5 ///
			caser6 personw6 caser7 /*personr7*/ r8xs_nonproxy_wgt hfinw_excendwr8_sum hfinlr8_sum 
		
		if `dataset_no' >= 3 {
			global indvars`wvsfx' ${indvars`wvsfx'} hhldr`wvsfx' sector`wvsfx' dvgiemp`wvsfx' ///
				dvgise`wvsfx' p_net_prop`wvsfx' hfinw_excendw`wvsfx'_sum ///
				hfinl`wvsfx'_sum p_net_fin`wvsfx' p_phys`wvsfx' 
		}
		
		if `dataset_no' <= 7 global indvars`wvsfx' ${indvars`wvsfx'} totpen`wvsfx' dvpinpval`wvsfx' dvvaldbt`wvsfx' dvspen`wvsfx'
		if `dataset_no' == 8 global indvars`wvsfx' ${indvars`wvsfx'} totpen_old`wvsfx' totalpenr8 p_totalwlthr8 p_totwlth_oldr8 ///
		dvpinpval_oldr8 dvpinpval_scaper8 dvvaldbt_oldr8 dvvaldbt_scaper8 dvspen_oldr8 dvspen_scaper8
		if inrange(`dataset_no', 3, 7) global indvars`wvsfx' ${indvars`wvsfx'} p_totwlth`wvsfx'
		
		if `dataset_no' == 7 global indvarsr7 $indvarsr7 dvretdb_noaccessr7 dvretdc_noaccessr7 
		else if `dataset_no' == 8 global indvarsr8 $indvarsr8 dvretdb_noaccess_oldr8 dvretdb_noaccess_scaper8 dvretdc_noaccessr8 dvretdb_accessr8 dvpavcuvr8
		else global indvars`wvsfx' ${indvars`wvsfx'} dvdbrwealthval`wvsfx' dvpfcurval`wvsfx'
		
		if `dataset_no' > 1 global indvars`wvsfx' ${indvars`wvsfx'} totdbpen`wvsfx'_decomp totpen`wvsfx'_decomp totothpen`wvsfx'_decomp mnthscape`wvsfx' ///
			sector`wvsfx' sectr2`wvsfx'
		
		if `dataset_no' >= 5 global indvars`wvsfx' ${indvars`wvsfx'} ageasaf`wvsfx' rf`wvsfx' rs`wvsfx'
		
		if `dataset_no' == 3 global indvars`wvsfx' ${indvars`wvsfx'} ecactw3
		if `dataset_no' >= 4 global indvars`wvsfx' ${indvars`wvsfx'} dvecact`wvsfx'
		
		if inrange(`dataset_no', 3, 5) global indvars`wvsfx' ${indvars`wvsfx'} housgdsost`wvsfx' buylgdst`wvsfx' persphys 
		if `dataset_no' > 5 global indvars`wvsfx' ${indvars`wvsfx'} housgdsost`wvsfx' buylgdst`wvsfx' persphys`wvsfx' 
		
		if `dataset_no' == 1 global indvars`wvsfx' ${indvars`wvsfx'} ischildw1 
		if `dataset_no' > 1 global indvars`wvsfx' ${indvars`wvsfx'} dvage7`wvsfx'
		
		
	}

	#delimit ; 
	global indvarsr6 
		/* Identifiers */
		casew1 personw1 casew2 personw2 casew3 personw3 casew4 personw4 casew5 personw5 caser6 personw6 r6xsperswgt r6_nonproxy_wgt ishrpw5 ishrpw6
		/* Interview info */
		yearr6 monthr6 persproxw6 persproxw5 
		/* Demographics */
		dvage17r6 haschdw6 haschdw5 isdepw6 isdepw5 sexr6 dvmrdfr6 
		/* Education */
		edlevelr6 edattn1w6 edattn2w6 edattn3w6 edattn1w5 edattn2w5 edattn3w5 teaw6 teaw5 coursew6 coursew5 attendw6 attendw5 enrollw6 enrollw5 
		/* Wealth variables */
		p_net_propr6 hfinw_excendwr6_sum hfinlr6_sum p_net_finr6 p_physr6 totpenr6 p_totwlthr6
		/* Original pension wealth variables */
		dvvaldbtr6 dvdbrwealthvalr6 dvpavcuvr6 dvpinpvalr6 dvspenr6 dvpfddvr6 dvvaldcosr6 dvppvalr6 dvpfcurvalr6 ageasafr6 asaf1tr6 asaf2tr6 rfr6 rsr6 mnthscaper6 
		/* Employment variables */
		dvecactr6 sectorr6 sectr2r6 dvgiempr6 dvgiser6 wrkingw5 wrkingw6
		/* Other */
		hhldrw6 hhldrw5 hfinw_excendwr6_sum hfinlr6_sum dvhasdbr6 dvhasdcr6
		/* Physical wealth variables */
		housgdstr6 housgdsostr6 buylgdstr6 persphysr6
	;
	#delimit cr
	global extravarsr6 $indvarsr6 ///
		pblumv1w5_i pblumv1w6_i pblumv2w5_i pblumv2w6_i frstschr6 scndschr6 dvpeninc1r6 dvpeninc2r6 retfracr6 ///
		dvwidr6 dvspsr6 power1tr6 power2tr6 dvdbincallr6 dvvalpblumr6 pwexpaw5_i pwexpaw6_i pwexphw5_i pwexphw6_i ///
		pwidfutw5_i pwidfutw6_i pspexpaw5_i pspexpaw6_i pspexphw5_i pspexphw6_i pspsew5_i pspsew6_i totpenr6 ///
		pincinpr6

	global indvarsr6 $indvarsr6 ///
		totdbpenr6_gilt totothpenr6_gilt totdcpenr6 totpenr6_gilt ///
		totdbpenr6_aa totothpenr6_aa totpenr6_aa ///
		totdbpenr6_scpe totothpenr6_scpe totpenr6_scpe ///
		totdbpenr6_constant totothpenr6_constant totpenr6_constant ///
		totdbpenr6_decomp totothpenr6_decomp totpenr6_decomp ///
		real_aa_yield real_gilt_yield1 real_gilt_yield2 real_gilt_yield3 real_gilt_yield4 real_gilt_yield5 ///
		scpe_rate constant_rate anntyfctr_gilt1 anntyfctr_gilt2 anntyfctr_gilt3 anntyfctr_gilt4 anntyfctr_gilt5 anntyfctr_scpe1 anntyfctr_scpe2 anntyfctr_scpe3 ///
		anntyfctr_scpe4 anntyfctr_scpe5 anntyfctr_aa1 anntyfctr_aa2 anntyfctr_aa3 anntyfctr_aa4 anntyfctr_aa5 anntyfctr_constant1 anntyfctr_constant2 ///
		anntyfctr_constant3 anntyfctr_constant4 anntyfctr_constant5 years_to_retire1 years_to_retire2 years_to_retire3 years_to_retire4 years_to_retire5 

end 
	
* This program merges individual and household level data for each WAS round/wave 
* It runs the code for creating consistent pension wealth measures and also does some other cleaning up 
capture program drop merge_append_was 
program define merge_append_was 

	* Loop over waves/rounds, merge household and person-level datasets and keep relevant variables 
	tempfile toappend 
	forval dataset_no = 1/8 {
		
		* Specify wave/round marker 
		if inrange(`dataset_no', 1, 5) local mrkr = "w"
		if `dataset_no' > 5 local mrkr = "r"
		local wvsfx "`mrkr'`dataset_no'"

		/************** Open household-level dataset **************/
		
		if `dataset_no' == 1 use "$rawWAS/was_wave_1_hhold_eul_final_jan_2020", clear 
		if `dataset_no' == 2 use "$rawWAS/was_wave_2_hhold_eul_feb_2020", clear 
		if `dataset_no' == 3 use "$rawWAS/was_wave_3_hh_eul_march_2020", clear 
		if `dataset_no' == 4 use "$rawWAS/was_wave_4_hhold_eul_march_2020", clear 
		if `dataset_no' == 5 use "$rawWAS/was_wave_5_hhold_eul_sept_2020", clear 
		if `dataset_no' == 6 use "$rawWAS/was_round_6_hhold_eul_april_2022", clear 
		if `dataset_no' == 7 use "$rawWAS/was_round_7_hhold_eul_march_2022", clear 
		if `dataset_no' == 8 use "$rawWAS/was_round_8_hhold_eul_march_2022_100225", clear 
		ren *, lower
		
		* Keep relevant variables 
		keep ${hhvars`wvsfx'}
			
		* Make consistent cross-sectional household weight variable 
		if `dataset_no' == 1 ren xs_wgtw1 xshhwgt
		if `dataset_no' == 2 ren xs_calwgtw2 xshhwgt
		if `dataset_no' == 3 ren w3xswgt xshhwgt
		if inrange(`dataset_no', 4, 8) ren `wvsfx'xshhwgt xshhwgt
		
		tempfile hhdata_`dataset_no'
		save `hhdata_`dataset_no'', replace 

		/************** Open household-level dataset **************/

		if inrange(`dataset_no', 1, 2) use "$rawWAS/was_wave_`dataset_no'_person_eul_nov_2020", clear
		if inrange(`dataset_no', 3, 5) use "$rawWAS/was_wave_`dataset_no'_person_eul_oct_2020", clear
		if `dataset_no' == 6 use "$rawWAS/was_round_6_person_eul_april_2022", clear 
		if `dataset_no' == 7 use "$rawWAS/was_round_7_person_eul_june_2022", clear 
		if `dataset_no' == 8 use "$rawWAS/was_round_8_person_eul_march_2022_100225", clear 
		ren *, lower 
		
		* Sort out variable naming convention for round 6 
		if `dataset_no' == 6 {
			keep $extravarsr6 
			
			gen persproxr6 = persproxw6
			replace persproxr6 = persproxw5 if missing(persproxw6)
			foreach x in pblumv1 pblumv2 pwexpa pwexph pwidfut pspexpa pspexph pspse {
				gen `x'r6_i = `x'w6_i 
				replace `x'r6_i = `x'w5_i if missing(`x'w6_i)
				drop `x'w5_i `x'w6_i 
			}
			
		}

		/************** Run pension wealth cleaning code  **************/

		* Step 1: ensure we consistently have all the variables we need in all the waves/rounds 
		if `dataset_no' == 1 create_penvars_earlywaves, dset("w1")
		if `dataset_no' == 2 ren (asaftw2 pblumvw2_i dvpenincw2 powertw2) (asaf1tw2 pblumv1w2_i dvpeninc1w2 power1tw2)
		if inlist(`dataset_no', 7, 8) gen dvpfddvr`dataset_no' = dvretdc_accessr`dataset_no' + dvretdb_accessr`dataset_no'
		
		* Step 2: create adjusted retirement ages i.e. floor of 60 for normal retirement age
		adjust_retage, dset("`wvsfx'")
		
		* Step 3: prepare the discount rate datasets to merge in 
		tempfile giltyields aayields
		preserve 
		use "$workingdata/real_gilt_yields", clear
		ren (year month maturity) (year`wvsfx' month`wvsfx' years_to_retire)
		save `giltyields', replace 
		use "$workingdata/real_aa_yields", clear
		ren (year month) (year`wvsfx' month`wvsfx')
		save `aayields', replace 
		restore 
		
		* Step 4: prepare the data for merging in discount rates 
		get_approx_retiredist, dset("`wvsfx'") // create years_to_retire variables 
		gen single = (!inlist(dvmrdf`wvsfx', 1, 2, 7, 8)) // annuity rates depend on whether single/in couple 
		
		* Step 5: prepare the annuity rates dataset to merge in 
		preserve 
		use "$workingdata/annuity_rates", clear
		ren (year month sex) (year`wvsfx' month`wvsfx' sex`wvsfx')
		tempfile annuities
		save `annuities'
		restore 
		
		* Step 6: merge in the gilt discount rates and annuity factors 
		* note we have the loop because we can have different discount rates/annuity factors for different types of pensions
		forval i = 1/5 {
			ren years_to_retire`i' years_to_retire 
			
			* Discount rate
			merge m:1 year`wvsfx' month`wvsfx' years_to_retire using `giltyields'
			replace real_gilt_yield = 0 if years_to_retire == 0 
			drop if _merge == 2
			drop _merge		
			
			* Annuity factor
			if `i' < 3 {
				ren ret_age_adj_`i' retage 
			}
			else {
				if `i' == 3 | `i' == 4 gen retage = 65
				if `i' == 5 gen retage = approxage 
				if `i' > 3 { 
					// For retained rights of partner and pensions in payment don't include any parnter's pension rights 
					ren single single_temp 
					gen single = 1 
				}
			}
			merge m:1 year`wvsfx' month`wvsfx' retage doby sex`wvsfx' single ///
				using `annuities'
			drop if _merge == 2 
			if `i' < 5 {
				assert !missing(anntyfctr_gilt) & !missing(anntyfctr_scpe) & !missing(anntyfctr_aa) & !missing(anntyfctr_constant) if ///
					!missing(retage) & retage > 0 & dvage17`wvsfx' > 3 & !mi(dvage17`wvsfx')		
			}
			if `i' == 5 {
				assert !missing(anntyfctr_gilt) & !missing(anntyfctr_scpe) & !missing(anntyfctr_aa) & !missing(anntyfctr_constant) if ///
					!missing(retage) & retage >= 55 & dvage17`wvsfx' > 11 & !mi(dvage17`wvsfx')		
			}
			ren (years_to_retire real_gilt_yield anntyfctr_gilt anntyfctr_aa anntyfctr_scpe anntyfctr_constant) ///
				(years_to_retire`i' real_gilt_yield`i' anntyfctr_gilt`i' anntyfctr_aa`i' anntyfctr_scpe`i' anntyfctr_constant`i')
			if `i' < 3 ren retage ret_age_adj_`i'
			if `i' >= 3 {
				drop retage 
				if `i' > 3 {
					drop single
					ren single_temp single 
				}
			}
			drop _merge
		}
		
		* Do some checks 
		assert (anntyfctr_gilt3 == anntyfctr_gilt4) & (anntyfctr_scpe3 == anntyfctr_scpe4) & (anntyfctr_aa3 == anntyfctr_aa4) ///
			& (anntyfctr_constant3 == anntyfctr_constant4) if single == 1
		// if you don't have a current partner your own annty factor should not include any value of partner's benefits 
		// and therefore should be the same annty factor as any retained rights from current/former partner's pension 
		
		assert (anntyfctr_gilt1 == anntyfctr_gilt3) & (anntyfctr_scpe1 == anntyfctr_scpe3) & (anntyfctr_aa1 == anntyfctr_aa3) ///
			& (anntyfctr_constant1 == anntyfctr_constant3) if ret_age_adj_1 == 65
		// if reported ret age on first active pension is 65 then it has the same annty factor as any own retaiend rights (where ret age of 65 assumed)
		
		assert real_gilt_yield3 == real_gilt_yield4
		
		* Step 7: Merge in AA corporate bond yields 
		merge m:1 year`wvsfx' month`wvsfx' using `aayields', assert(2 3) keep(3) nogen
		
		* Step 8: Merge in SCAPE rate 
		gen scpe_rate = .
		replace scpe_rate = 0.03 if year`wvsfx' < 2016 | (year`wvsfx' == 2016 & month`wvsfx' < 4)
		// SCAPE rate initially set at CPI+3 in 2011 budget. Assume same rate before that
		replace scpe_rate = 0.028 if year`wvsfx' > 2016 | (year`wvsfx' == 2016 & month`wvsfx' >= 4)
		// SCAPE rate reduced to CPI+2.8 in 2016 Budget (16 Mar 2016)
		replace scpe_rate = 0.024 if year`wvsfx' > 2018 | (year`wvsfx' == 2018 & month`wvsfx' >= 11)
		// SCAPE rate reduced to CPI+2.4 in 2018 Budget (October 2018)
		
		* Step 9: Merge in constant discount rate 
		gen constant_rate = $constant_rate
		
		* Step 10: run pension wealth cleaning code for relevant discount rate, annuity rate
		clean_penwealth, dset("`wvsfx'") disc_type("gilt") ann_type("gilt") sfx("gilt")
		clean_penwealth, dset("`wvsfx'") disc_type("aa") ann_type("aa") sfx("aa")
		clean_penwealth, dset("`wvsfx'") disc_type("scpe") ann_type("scpe") sfx("scpe")
		clean_penwealth, dset("`wvsfx'") disc_type("constant") ann_type("constant") sfx("constant")
		if `dataset_no' > 1 {
			clean_penwealth, dset("`wvsfx'") disc_type("wasOLD") ann_type("gilt") sfx("decomp")
		}

		/************** Final adjustments  **************/

		keep ${indvars`wvsfx'}	
		
		* Merge in household level data 
		drop if missing(case`wvsfx')
		merge m:1 case`wvsfx' using `hhdata_`dataset_no'', assert(3) nogen
		
		* Round 6 adjustment to variable names 
		if `dataset_no' == 6 {
			
			foreach x in person persprox haschd isdep edattn1 edattn2 edattn3 tea course attend enroll hhldr numadult ishrp wrking {
				gen `x'r6 = `x'w6 
				replace `x'r6 = `x'w5 if missing(`x'r6)
				if "`x'" != "person" drop `x'w6 `x'w5
			}
		}
		
		* Merge in benefit unit IDs 
		if inlist(`dataset_no', 2, 3, 4, 5, 7, 8) ///
			merge 1:1 person`wvsfx' case`wvsfx' using "$workingdata/WAS_BUno_mappings_`wvsfx'", keep(1 3) nogen
		if `dataset_no' == 6 merge 1:1 personw5 personw6 caser6 using "$workingdata/WAS_BUno_mappings_r6", keep(1 3) nogen
		
		* Remove wave subscripts 
		ren person`mrkr'* personv*
		ren case`mrkr'* casev* 
		ren *`wvsfx' *
		cap ren *`wvsfx'_i *_i
		cap ren *`wvsfx'_gilt *_gilt
		cap ren *`wvsfx'_aa *_aa
		cap ren *`wvsfx'_scpe *_scpe
		cap ren *`wvsfx'_decomp *_decomp
		cap ren *`wvsfx'_constant *_constant
		cap ren *`wvsfx'_aggr *_aggr
		cap ren *`wvsfx'_sum *_sum
		gen dataset_no = `dataset_no'
		
		gen pers_num = personv`dataset_no'
		
		rename personv* person`mrkr'*
		rename casev* case`mrkr'*
		
		* Append 
		if `dataset_no' > 1 append using `toappend'
		save `toappend', replace 
		
	}

	use `toappend', clear

	* Make a consistent individual-level weight 
	gen xswgt = xs_wgt if dataset_no == 1
	replace xswgt = xs_calwgt if dataset_no == 2
	replace xswgt = w3xswgt if dataset_no == 3
	replace xswgt = w4xsperswgt if dataset_no == 4
	replace xswgt = w5xsperswgt if dataset_no == 5
	replace xswgt = r6xsperswgt if dataset_no == 6
	replace xswgt = r7xsperswgt if dataset_no == 7
	*replace xswgt =  if dataset_no == 8

	gen xswgt_nonproxy = . 
	replace xswgt_nonproxy = w4_nonproxy_wgt if dataset_no == 4
	replace xswgt_nonproxy = w5_nonproxy_wgt if dataset_no == 5
	replace xswgt_nonproxy = r6_nonproxy_wgt if dataset_no == 6
	replace xswgt_nonproxy = r7_nonproxy_wgt if dataset_no == 7
	replace xswgt_nonproxy = r8xs_nonproxy_wgt if dataset_no == 8

	drop xs_wgt xs_calwgt w3xswgt *xsperswgt *nonproxy_wgt

	* Make a non-longitudinal household identifier variable
	gen hhid = .
	forval dataset_no = 1/8 {
		
		if inrange(`dataset_no', 1, 5) local mrkr = "w"
		if `dataset_no' > 5 local mrkr = "r"
		
		replace hhid = case`mrkr'`dataset_no' if dataset_no == `dataset_no'
	}

	order dataset_no casew1 casew2 casew3 casew4 casew5 caser6 caser7 caser8 personw1 personw2 personw3 personw4 personw5 personw6 personr6 personr7 personr8 ///
		hhid month year
	sort dataset_no hhid


	* Save 
	save "$workingdata/mergedwas", replace

end

