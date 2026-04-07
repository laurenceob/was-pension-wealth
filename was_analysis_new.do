/********************************************************************************
**** Title: 		was_analysis.do 
**** Author: 		Laurence O'Brien 
**** Date started: 	02/06/2025
**** Description:	Analyse WAS wealth trends
********************************************************************************/

capture program drop main 
program define main 
	
	* Main figures
	mean_hh_wealth_over_time
	wealth_composition_over_time
	plot_discount_rates
	wealth_dist_r8
	top_wealth_share_over_time
	avg_wealth_by_educ
	db_share_by_educ
	wealth_composition_by_age_r8
	avg_wealth_by_age_r8 
	wealth_by_age_wave
	
	* Appendix 
	mean_hh_wealth_over_time_all
	gini_coefficient_over_time
	pens_wealth_comparison_by_age
	
	

end 

* Helper program: restricts data to one observation per household (the household reference person)
capture program drop keep_hh_ref_person
program define keep_hh_ref_person

	* Just keep household reference person 
	egen min_hrp = min(ishrp), by(dataset_no hhid)
	qui count if missing(min_hrp)
	assert `r(N)' < 10
	assert missing(totwlth) & missing(tothhwlth_scpe) if missing(min_hrp)
	assert min_hrp == 1 if !missing(min_hrp)
	drop min_hrp 
	// Pretty much every hh has a ref person - except a few obs where wealth is also missing so fine to drop these 
	keep if ishrp == 1

	* Check there is only one observation per household 
	bys dataset_no hhid: gen count = _N
	assert count == 1
	drop count 

end

*** Main figures

* Fig 1: Mean household wealth over time by methodology
capture program drop mean_hh_wealth_over_time
program define mean_hh_wealth_over_time 

	use "$workingdata/was_clean", clear 
	keep_hh_ref_person
	
	foreach var of varlist tothhwlth*_r totpen_*_hh_r {
		gen `var'_mean = `var'
		gen `var'_agg = `var'
	}
	
	* Get mean wealth by wave/round 
	collapse (mean) *_mean (sum) *_agg [pw=xshhwgt], by(dataset_no)
		
	* Just keep what we want to export 
	keep dataset_no tothhwlth_gilt_r_mean tothhwlth_was_new_r_mean tothhwlth_gilt_r_agg tothhwlth_was_new_r_agg totpen_gilt_hh_r_mean totpen_was_new_hh_r_mean 
	
	* Label variables
	label var tothhwlth_gilt_r_mean "Mean household wealth - IFS"
	label var tothhwlth_was_new_r_mean "Mean household wealth - ONS"
	label var totpen_gilt_hh_r_mean "Mean pension wealth - IFS"
	label var totpen_was_new_hh_r_mean "Mean pension wealth - ONS"
	label var tothhwlth_gilt_r_agg "Aggregate household wealth - IFS"
	label var tothhwlth_was_new_r_agg "Aggregate household wealth - ONS"
	
	* Export to create word graph 
	export excel using "$output/was_report_underlying_data_new.xlsx", first(varl) sheet("mean_hh_wealth_over_time", replace)

end 

* Fig 2: Share of household wealth in pensions over time, by methodology
capture program drop wealth_composition_over_time
program define wealth_composition_over_time

	use "$workingdata/was_clean", clear 
	keep_hh_ref_person
			
	* Get mean wealth and pension wealth by dataset 
	collapse (mean) tothhwlth_*_r totpen_*_hh_r hpropw_r hfinwnt_sum_r [pw=xshhwgt], by(dataset_no)

	* Share of wealth made up by different components of pension wealth
	foreach x in gilt was_old was_new scpe aa constant {
		gen penshare_`x' = totpen_`x'_hh_r / tothhwlth_`x'_r
	}
	
	* Label 
	keep penshare_gilt penshare_was_new dataset_no
	label var penshare_gilt "IFS methodology"
	label var penshare_was_new "ONS methodology"	
	
	export excel using "$output/was_report_underlying_data_new.xlsx", first(varl) sheet("penshare_over_time", replace)
	


end 

* Fig 3: Discount rates over time
capture program drop plot_discount_rates
program define plot_discount_rates

	* Plot discount rates for someone who is 15 years from retirement 
	
	* Get monthly CPI 
	import delimited using "$rawdata/cpi_rate", rowrange(192) clear
	ren (title cpiannualrate00allitems2015100) (date cpi_rate)
	gen year = substr(date, 1, 4)
	gen monthname = substr(date, -3, .)
	gen datevar = date("1" + lower(monthname) + "2000", "DMY")
	gen month = month(datevar)
	drop date monthname datevar
	destring year, replace 
	replace cpi_rate = cpi_rate / 100 
	tempfile cpi 
	save `cpi', replace 

	* Get monthly RPI
	import delimited using "$rawdata/rpi_rate", rowrange(394) clear
	ren (title rpiallitemspercentagechangeover1) (date rpi_rate)
	gen year = substr(date, 1, 4)
	gen monthname = substr(date, -3, .)
	gen datevar = date("1" + lower(monthname) + "2000", "DMY")
	gen month = month(datevar)
	drop date monthname datevar
	destring year, replace 
	replace rpi_rate = rpi_rate / 100 
	tempfile rpi 
	save `rpi', replace 

	
	* Start with gilt yields 
	use "$workingdata/real_gilt_yields", clear
	keep if maturity == 15 
	tempfile tomerge 
	save `tomerge', replace 
	
	* Add in AA corporate bond yields 
	use "$workingdata/real_aa_yields", clear 
	merge 1:1 month year using `tomerge'
	*assert _merge == 3
	drop _merge
	merge 1:1 year month using `cpi', keep(1 3) nogen
	merge 1:1 year month using `rpi', keep(3) nogen
	
	* Add in SCAPE rate 
	gen_real_scpe, newvar(scpe_real) yearvar(year) monthvar(month)
	gen scpe_nom = scpe_real + cpi_rate if year > 2011 | (year == 2011 & month >= 4)
	replace scpe_nom = scpe_real + rpi_rate if year < 2011 | (year == 2011 & month < 4)
	
	* Sort out the date 
	gen date = ym(year, month)
	format date %tm
	drop month year
	sort date
	drop maturity
	order date
	
	keep date real_gilt_yield scpe_* 
	
	* Label 
	label var real_gilt_yield "Real 15-year gilt yield"
	label var scpe_nom "SCAPE rate (nominal)"
	label var scpe_real "SCAPE rate (real)"
	
	* Export to create word graph
	export excel using "$output/was_report_underlying_data_new.xlsx", first(varl) sheet("plot_discount_rates", replace)


end 

* Fig 4: distribution of household wealth in WAS Round 8 by methodology
capture program drop wealth_dist_r8
program define wealth_dist_r8
	
	* Plot 10-90th percentiles of wealth in Round 8 under two methodologies

	use "$workingdata/was_clean", clear 
	keep_hh_ref_person
	
	* Just focus on round 8 
	keep if dataset_no == 8
	
	* Collapse 
	foreach var of varlist tothhwlth*_r {
		forval i = 10(10)90 {
			gen `var'_p`i' = `var'
		}
	}
	collapse (p10) *_p10 (p20) *_p20 (p30) *_p30 (p40) *_p40 (p50) *_p50 (p60) *_p60 (p70) *_p70 (p80) *_p80 (p90) *_p90 [pw=xshhwgt], by(dataset_no)
	
	* Reshape 
	reshape long tothhwlth_gilt_r tothhwlth_aa_r tothhwlth_scpe_r tothhwlth_was_new_r tothhwlth_was_old_r, i(dataset_no) j(stat) string

	* Clean up 
	drop dataset_no
	gen percentile = substr(stat, -2, .)
	destring percentile, replace 
	drop stat
	
	* Export 
	keep percentile tothhwlth_gilt_r tothhwlth_was_new_r 
	order percentile tothhwlth_gilt_r tothhwlth_was_new_r
	label var tothhwlth_gilt_r "IFS methodology"
	label var tothhwlth_was_new_r "ONS methodology"
	export excel using "$output/was_report_underlying_data_new.xlsx", first(varl) sheet("wealth_dist_r8", replace)

	

end 

* Fig 5: Top 10% share of household wealth over time by methodology
capture program drop top_wealth_share_over_time
program define top_wealth_share_over_time

	use "$workingdata/was_clean", clear 
	keep_hh_ref_person
	
	tempfile tomerge 
	foreach var of varlist tothhwlth_gilt_r tothhwlth_was_old_r tothhwlth_was_new_r tothhwlth_scpe_r tothhwlth_decomp_r {
		
		preserve 

		* Calculate who's in the top 10% of the distribution in each wave/round 
		gen top10_`var' = 0
		forval i = 1/8 {
			qui sum `var' if dataset_no == `i' [w=xshhwgt], d
			qui replace top10_`var' = 1 if `var' >= `r(p90)' & dataset_no == `i'
		}
	
		* Collapse to get the wealth in top 10% and bottom 90% in each wave 
		collapse (sum) `var' [pw=xshhwgt], by(dataset_no top10_`var')
		
		* Get total wealth and top 10% share 
		egen total_`var' = sum(`var'), by(dataset_no)
		keep if top10_`var' == 1
		replace `var' = `var' / total_`var'
		drop top10_`var' total_`var'
		ren `var' top10_`var'
		
		* Merge together 
		if "`var'" != "tothhwlth_gilt_r" merge 1:1 dataset_no using `tomerge', nogen
		save `tomerge', replace 
		
		restore 
	}
	
	use `tomerge', clear
	
	keep dataset_no top10_tothhwlth_gilt_r top10_tothhwlth_was_new_r
	
	* Label 
	label var top10_tothhwlth_gilt_r "IFS methodology"
	label var top10_tothhwlth_was_new_r "ONS methodology"
	
	* Export 
	export excel using "$output/was_report_underlying_data_new.xlsx", first(varl) sheet("top_10pc_share_over_time", replace)
	
	

end 

* Fig 6: Median individual wealth over time by education level and methodology
capture program drop avg_wealth_by_educ
program define avg_wealth_by_educ 

	use "$workingdata/was_clean", clear 

	replace xswgt_nonproxy = xswgt if persprox != 2 & dataset_no == 3
	replace xswgt_nonproxy = 0 if persprox == 2 & dataset_no == 3
	
	* Just keep adults 
	keep if dvage17 >= 5
	
	* Get median wealth by dataset and age group
	gen n = 1
	collapse (median) totindwlth_*_r (rawsum) n [pw=xswgt_nonproxy], by(dataset_no edlevel)
	keep if inlist(edlevel, 1, 2, 4)
	
	* REshape 
	keep dataset_no edlevel totindwlth_gilt_r totindwlth_was_new_r 
	reshape wide totindwlth_gilt_r totindwlth_was_new_r, i(dataset_no) j(edlevel) 
	
	* Label
	label var totindwlth_gilt_r1 "High educ - IFS"
	label var totindwlth_gilt_r2 "Mid educ - IFS"
	label var totindwlth_gilt_r4 "Low educ - IFS"
	label var totindwlth_was_new_r1 "High educ - ONS"
	label var totindwlth_was_new_r2 "Mid educ - ONS"
	label var totindwlth_was_new_r4 "Low educ - ONS"
	
	* Export 
	export excel using "$output/was_report_underlying_data_new.xlsx", first(varl) sheet("median_wealth_by_educ", replace)
	
end 

* Stats in report: share with DB wealth by education 
capture program drop db_share_by_educ
program define db_share_by_educ 

	use "$workingdata/was_clean", clear 
	
	keep if dataset_no == 8

	replace xswgt_nonproxy = xswgt if persprox != 2 & dataset_no == 3
	replace xswgt_nonproxy = 0 if persprox == 2 & dataset_no == 3
	
	* Just keep adults 
	keep if dvage17 >= 5
	
	* Indicator for whether any DB pension wealth 
	gen has_db_wealth = (totdbpen_gilt_r > 0)
	gen has_db_pen = (inlist(pentype, 2, 3))
	
	* Get median wealth by dataset and age group
	gen n = 1
	collapse (mean) has_db_wealth has_db_pen (rawsum) n [pw=xswgt_nonproxy], by(edlevel)
	keep if inlist(edlevel, 1, 2, 4)
	
	* Label
	label var has_db_wealth "Has positive DB wealth"
	label var has_db_pen "Enrolled in DB pension"
	
	* Export 
	export excel using "$output/was_report_underlying_data_new.xlsx", first(varl) sheet("db_share_by_educ", replace)


end 

* Fig 7: Composition of individual wealth by age group in WAS Round 8
capture program drop wealth_composition_by_age_r8
program define wealth_composition_by_age_r8

	use "$workingdata/was_clean", clear 
	
	keep if dataset_no == 8
	
	* Make consistent weight 
	replace xswgt_nonproxy = xswgt if persprox != 2 & dataset_no == 3
	replace xswgt_nonproxy = 0 if persprox == 2 & dataset_no == 3

	* Create age group variable
	assert totindwlth_gilt_r == 0 | totindwlth_gilt_r == . if mi(dvage17)
	drop if mi(dvage17)
	keep if dvage17 >= 5 // just keep adults 
		
	gen age_group = 1 if inrange(dvage17, 5, 8) // 20-39
	replace age_group = 2 if inrange(dvage17, 9, 13) // 40-64
	replace age_group = 3 if dvage17 >= 14
	label define age_group 1 "Age 20-39" 2 "Age 40-64" 3 "Age 65+"
	label values age_group age_group
	
	
	* Get mean wealth and pension wealth by dataset 
	collapse (mean) p_net_fin_r p_net_prop_r totalpen_r p_phys_new_r totpen_gilt_r totindwlth_gilt_r totindwlth_was_new_r [pw=xswgt_nonproxy], by(age_group)

	* Get rid of those under 20 
	drop if missing(age_group)
	
	* Share of wealth made up by different components of pension wealth
	ren totalpen_r totpen_was_new_r 
	foreach x in gilt was_new {
		gen penshare_`x' = totpen_`x'_r / totindwlth_`x'_r
		gen propshare_`x' = p_net_prop_r / totindwlth_`x'_r
		gen finshare_`x' = p_net_fin_r / totindwlth_`x'_r
		gen physshare_`x' = p_phys_new_r / totindwlth_`x'_r
	}
	
	* Reshape for exporting 
	keep *share* age_group	
	reshape long penshare_ propshare_ finshare_ physshare_, i(age_group) j(methodology) string
	ren *_ *
	
	* Export excel 
	foreach x in gilt was {
		label var penshare "Pension wealth"
		label var propshare "Property wealth"
		label var finshare "Financial wealth"
		label var physshare "Physical wealth"
	}
	replace methodology = "IFS" if methodology == "gilt"
	replace methodology = "ONS" if methodology == "was_new"
	export excel using "$output/was_report_underlying_data_new.xlsx", first(varl) sheet("wealth_composition_by_age_r8", replace)

end 

* Fig 8: Median individual wealth in WAS round 8, by age and methodology
capture program drop avg_wealth_by_age_r8
program define avg_wealth_by_age_r8 

	use "$workingdata/was_clean", clear 

	replace xswgt_nonproxy = xswgt if persprox != 2 & dataset_no == 3
	replace xswgt_nonproxy = 0 if persprox == 2 & dataset_no == 3
	
	* Just keep round 8
	keep if dataset_no == 8
	
	* Create age group variable
	assert totindwlth_gilt_r == 0 | totindwlth_gilt_r == . if mi(dvage17)
	drop if mi(dvage17)
	keep if dvage17 >= 5 // just keep adults 
	
	gen age_group = 1 if inrange(dvage17, 5, 6)
	replace age_group = 2 if inrange(dvage17, 7, 8)
	replace age_group = 3 if inrange(dvage17, 9, 10)
	replace age_group = 4 if inrange(dvage17, 11, 12)
	replace age_group = 5 if inrange(dvage17, 13, 14)
	replace age_group = 6 if inrange(dvage17, 15, 16)
	replace age_group = 7 if dvage17 == 17
	label define age_group 1 "Age 20-29" 2 "Age 30-39" 3 "Age 40-49" 4 "Age 50-59" 5 "Age 60-69" 6 "Age 70-79" 7 "Age 80+"
	label values age_group age_group
	
	* Get median wealth by dataset and age group
	gen n = 1
	collapse (median) totindwlth_*_r [pw=xswgt_nonproxy], by(age_group)
	
	* REshape 
	keep age_group totindwlth_gilt_r totindwlth_was_new_r 
	
	* Label 
	label var totindwlth_gilt_r "IFS methodology"
	label var totindwlth_was_new_r "ONS methodology"
		
	* Export 
	export excel using "$output/was_report_underlying_data_new.xlsx", first(varl) sheet("median_wealth_by_age_r8", replace)
	
end 

* Fig 9: Share of aggregate total individual wealth held by individuals of different ages over time, by methodology
capture program drop wealth_by_age_wave
program define wealth_by_age_wave

	use "$workingdata/was_clean", clear 
	
	* Make consistent weight 
	replace xswgt_nonproxy = xswgt if persprox != 2 & dataset_no == 3
	replace xswgt_nonproxy = 0 if persprox == 2 & dataset_no == 3

	* Create age group variable
	assert totindwlth_gilt_r == 0 | totindwlth_gilt_r == . if mi(dvage17)
	drop if mi(dvage17)
	keep if dvage17 >= 5 // just keep adults 
		
	gen age_group = 1 if inrange(dvage17, 5, 8) // 20-39
	replace age_group = 2 if inrange(dvage17, 9, 13) // 40-64
	replace age_group = 3 if dvage17 >= 14
	label define age_group 1 "Age 20-39" 2 "Age 40-64" 3 "Age 65+"
	label values age_group age_group
	
	* Calculate total household wealth 
	collapse (sum) totindwlth_*_r [pw=xswgt_nonproxy], by(age_group dataset_no)
	
	* Create the shares of total wealth 
	foreach var of varlist tot* {
		egen `var'_sum = sum(`var'), by(dataset_no)
		gen `var'_shr = `var' / `var'_sum
	}

	* Reshape 
	keep *was_new_r_shr *gilt_r_shr dataset_no age_group
	reshape wide totindwlth_gilt_r_shr totindwlth_was_new_r_shr, i(dataset_no) j(age_group)
	label var totindwlth_gilt_r_shr1 "Age 20-39 (IFS methodology)"
	label var totindwlth_gilt_r_shr2 "Age 40-64 (IFS methodology)"
	label var totindwlth_gilt_r_shr3 "Age 65+ (IFS methodology)"
	label var totindwlth_was_new_r_shr1 "Age 20-39 (ONS methodology)"
	label var totindwlth_was_new_r_shr2 "Age 40-64 (ONS methodology)"
	label var totindwlth_was_new_r_shr3 "Age 65+ (ONS methodology)"

	* Export 
	export excel using "$output/was_report_underlying_data_new.xlsx", first(varl) sheet("wealth_shr_by_age_wave", replace)
	
end

*** Appendix 

* Fig B.1: Mean household wealth over time by methodology
capture program drop mean_hh_wealth_over_time_all
program define mean_hh_wealth_over_time_all 

	use "$workingdata/was_clean", clear 
	keep_hh_ref_person
	
	foreach var of varlist tothhwlth*_r totpen_*_hh_r {
		gen `var'_mean = `var'
	}
	
	* Get median wealth by wave/round 
	collapse (mean) *_mean [pw=xshhwgt], by(dataset_no)
	
	* Label 
	label var tothhwlth_gilt_r_mean "IFS methodology (gilt)"
	label var tothhwlth_aa_r_mean "IFS methodology (AA bond)"
	label var tothhwlth_was_old_r_mean "ONS methodology (old)"
	label var tothhwlth_was_new_r_mean "ONS methodology (new)"
	label var tothhwlth_constant_r_mean "IFS methodology (no discounting)"
	label var tothhwlth_scpe_r_mean "IFS methodology (SCAPE discounting)"
			
	* Export to create word graph 
	export excel dataset_no *wlth*_mean using "$output/was_report_underlying_data_new.xlsx", first(varl) sheet("mean_hh_wealth_over_time_all", replace)

end 

* Fig B.2: Gini coefficient of household wealth over time by methodology
capture program drop gini_coefficient_over_time
program define gini_coefficient_over_time 

	use "$workingdata/was_clean", clear 
	keep_hh_ref_person
	
	replace xswgt_nonproxy = xswgt if persprox != 2 & dataset_no == 3
	replace xswgt_nonproxy = 0 if persprox == 2 & dataset_no == 3
	
	foreach x in gilt was_new was_old {
	
		* Where to store the ginis 
		gen gini_`x'_hh = . 
		gen gini_`x'_ind = . 
		
		forval i = 1/8 {
			
			* Calculate the ginis 
			fastgini tothhwlth_`x'_r if dataset_no == `i' [pw=xshhwgt]
			replace gini_`x'_hh = `r(gini)' if dataset_no == `i'		
			
			if `i' < 3 continue
			
			* Calculate the ginis 
			fastgini totindwlth_`x'_r if dataset_no == `i' [pw=xswgt_nonproxy]
			replace gini_`x'_ind = `r(gini)' if dataset_no == `i'		
			
		}
			
	}
	
	* Collapse 
	collapse (mean) gini_*, by(dataset_no)
	
	keep dataset_no gini_gilt_hh gini_was_new_hh
	
	* Label 
	label var gini_gilt_hh "IFS methodology"
	label var gini_was_new_hh "ONS methodology"
	
	* Export 
	export excel using "$output/was_report_underlying_data_new.xlsx", first(varl) sheet("gini_coefficients", replace)

end  
 
* Fig B.3: Ratio of total individual pension wealth calcualted using IFS methodology versus total individual pension wealth
* calculated using ONS methodology by age group, over time 
capture program drop pens_wealth_comparison_by_age 
program define pens_wealth_comparison_by_age

	use "$workingdata/was_clean", clear 
	
	replace xswgt_nonproxy = xswgt if persprox != 2 & dataset_no == 3
	replace xswgt_nonproxy = 0 if persprox == 2 & dataset_no == 3
	
	* Make consistent WAS pension wealth 
	gen totpen_was_new_r = totpen_r
	replace totpen_was_new_r = totalpen_r if dataset_no == 8
	
	* Just keep people with positive pension wealth (zero pension wealth is the same under every methodology)
	keep if totpen_was_new_r > 0 & !mi(totpen_was_new_r)
	
	* Create age group variable
	assert !mi(dvage17)
	gen age_group = 1 if dvage17 <= 7
	replace age_group = 2 if inrange(dvage17, 8, 10)
	replace age_group = 3 if inrange(dvage17, 11, 12)
	replace age_group = 4 if inrange(dvage17, 13, 14)
	replace age_group = 5 if dvage17 >= 15
	label define age_group 1 "Up to age 34" 2 "Age 35-49" 3 "Age 50-59" 4 "Age 60-69" 5 "Age 70+"
	label values age_group age_group
	
	* Collapse 
	collapse (mean) totpen_was_new_r totpen_gilt_r [pw=xswgt_nonproxy], by(age_group dataset_no)
	
	* Create ratio between my pension wealth measure and WAS old/decomp measure
	gen gilt_was_new_ratio = totpen_gilt_r / totpen_was_new_r 
	
	* Reshape so we can plot this by dataset 
	keep dataset_no age_group gilt_was_new_ratio
	reshape wide gilt_was_new_ratio, i(age_group) j(dataset_no)
	label var age_group "Age group"
	label var gilt_was_new_ratio3 "Jul 10 - Jun 12"
	label var gilt_was_new_ratio4 "Jul 12 - Jun 14"
	label var gilt_was_new_ratio5 "Jul 14 - Jun 16"
	label var gilt_was_new_ratio6 "Apr 16 - Mar 18"
	label var gilt_was_new_ratio7 "Apr 18 - Mar 20"
	label var gilt_was_new_ratio8 "Apr 20 - Mar 22"
	
	* Export 
	export excel using "$output/was_report_underlying_data_new.xlsx", first(varl) sheet("pens_wealth_comparison_by_age", replace)

end 
