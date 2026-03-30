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
	wealth_composition_by_age_r8
	avg_wealth_by_age_r8 
	wealth_by_age_wave
	
	* Appendix 
	mean_hh_wealth_over_time_all
	median_hh_wealth_over_time
	avg_wealth_by_pentype
	pens_wealth_comparison_by_age
	
	

end 

*** Main text 

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
	
	* Export to create word graph 
	export excel using "$output/was_report_underlying_data_new.xlsx", first(var) sheet("mean_hh_wealth_over_time", replace)

end 

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
	
	* Export 
	keep penshare* dataset_no
	export excel using "$output/was_report_underlying_data_new.xlsx", first(var) sheet("penshare_over_time", replace)
	


end 

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
	
	* Add in SCAPE rate 
	gen scpe_real = .
	replace scpe_real = 0.03 if year < 2016 | (year == 2016 & month < 4) // scape rate initially set at CPI+3 in 2011 budget. Assume same rate before that
	replace scpe_real = 0.028 if year > 2016 | (year == 2016 & month >= 4)	// scape rate reduced to CPI+2.8 in 2016 Budget (16 Mar 2016)
	replace scpe_real = 0.024 if year > 2018 | (year == 2018 & month >= 11) // scape rate reduced to CPI+2.4 in 2018 Budget (October 2018)
	replace scpe_real = 0.017 if year > 2024 | (year == 2024 & month >= 4) // scape rate reduced to CPI+1.7 in 2024
	
	gen scpe_nom = scpe_real + cpi_rate
	
	* Sort out the date 
	gen date = ym(year, month)
	format date %tm
	drop month year
	sort date
	drop maturity
	order date
	
	* Export to create word graph
	export excel using "$output/was_report_underlying_data_new.xlsx", first(var) sheet("plot_discount_rates", replace)
	
	
	/*
	use "$workingdata/was_clean", clear 
	keep dataset_no year month mnthscape
	sort year month
	egen max_scape = max(mnthscape), by(month year dataset_no)
	drop if missing(mnthscape) & !missing(max_scape)
	drop max_scape
	duplicates drop
	isid month year dataset_no
	merge m:1 year month using `cpi', keep(1 3) nogen
	gen implied_real_scape = mnthscape - cpi_rate
	gen implied_cpi = mnthscape - 0.03 if dataset < 8
	
	* Something weird going on in Round 6...
	* I'm just going to add monthly CPI to real SCAPE
	* This isn't exactly what WAS uses but gives the idea 

	
	
	* what is the average difference in AA and gilt yields?
	qui sum real_aa_yield
	local mean_aa = `r(mean)'
	qui sum real_gilt_yield
	local mean_gilt = `r(mean)'
	local diff = `mean_aa' - `mean_gilt'
	di "Mean wedge between AA bond yields and gilts is `diff'"
	di `diff' * 100
	* 1.19ppt  */



end 

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

capture program drop top_wealth_share_over_time
program define top_wealth_share_over_time

	use "$workingdata/was_clean", clear 
	keep_hh_ref_person
	
	* Calculate who's in the top 10% of the distribution in each wave/round 
	tempfile tomerge 
	foreach var of varlist tothhwlth_gilt_r tothhwlth_was_old_r tothhwlth_was_new_r tothhwlth_scpe_r tothhwlth_decomp_r {
		
		preserve 
		
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
	
	* Export 
	export excel using "$output/was_report_underlying_data_new.xlsx", first(var) sheet("top_10pc_share_over_time", replace)
	
	

end 

capture program drop avg_wealth_by_educ
program define avg_wealth_by_educ 

	* Actually let's also get the difference between median wealth 
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

capture program drop db_share_by_educ
program define db_share_by_educ 

	* Actually let's also get the difference between median wealth 
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

capture program drop mean_hh_wealth_over_time_all
program define mean_hh_wealth_over_time_all 

	use "$workingdata/was_clean", clear 
	keep_hh_ref_person
	
	foreach var of varlist tothhwlth*_r totpen_*_hh_r {
		gen `var'_mean = `var'
	}
	
	* Get median wealth by wave/round 
	collapse (mean) *_mean [pw=xshhwgt], by(dataset_no)
			
	* Export to create word graph 
	export excel dataset_no *wlth*_mean using "$output/was_report_underlying_data_new.xlsx", first(var) sheet("mean_hh_wealth_over_time_all", replace)

end 

capture program drop median_hh_wealth_over_time
program define median_hh_wealth_over_time 

	use "$workingdata/was_clean", clear 
	keep_hh_ref_person
	
	foreach var of varlist tothhwlth*_r totpen_*_hh_r {
		gen `var'_p50 = `var'
	}
	
	* Get median wealth by wave/round 
	collapse (median) *_p50 [pw=xshhwgt], by(dataset_no)
		
	drop *decomp*	
	
	* Export to create word graph 
	export excel dataset_no *wlth*_p50 using "$output/was_report_underlying_data_new.xlsx", first(var) sheet("median_hh_wealth_over_time", replace)

end 

capture program drop avg_wealth_by_pentype
program define avg_wealth_by_pentype
	
	use "$workingdata/was_clean", clear 

	replace xswgt_nonproxy = xswgt if persprox != 2 & dataset_no == 3
	replace xswgt_nonproxy = 0 if persprox == 2 & dataset_no == 3

	* Create more aggregated pension type variable 
	gen pentype_agg = pentype
	replace pentype_agg = 2 if pentype == 3
	label define pentype_agg 0 "No pension" 1 "Only DC" 2 "DB"
	label values pentype_agg pentype_agg 
	
	* Just keep adults 
	keep if dvage17 >= 5
	
	* Get median wealth by dataset and age group
	gen n = 1
	collapse (median) totindwlth_*_r (rawsum) n [pw=xswgt_nonproxy], by(dataset_no pentype_agg)
	assert n <= 20 if missing(pentype_agg)
	drop if missing(pentype_agg)
	
	* REshape 
	keep dataset_no pentype_agg totindwlth_gilt_r totindwlth_was_new_r 
	reshape wide totindwlth_gilt_r totindwlth_was_new_r, i(dataset_no) j(pentype_agg) 
	
	label var totindwlth_gilt_r0 "No pension (IFS methodology)"
	label var totindwlth_gilt_r1 "DC only (IFS methodology)"
	label var totindwlth_gilt_r2 "DB (IFS methodology)"
	label var totindwlth_was_new_r0 "No pension (ONS methodology)"
	label var totindwlth_was_new_r1 "DC only (ONS methodology)"
	label var totindwlth_was_new_r2 "DB (ONS methodology)"
	
	* Export 
	export excel using "$output/was_report_underlying_data_new.xlsx", first(varl) sheet("median_wealth_by_pentype", replace)
	

	
end 

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

* Maybe delete?
capture program drop rank_move_by_db_wealth
program define rank_move_by_db_wealth

	use "$workingdata/was_clean", clear 
	keep_hh_ref_person
	
	* Just do this for round 8 
	keep if dataset_no == 8 
	
	* What share of wealth is held in pensions under ONS methodology (including already accessed DB pensions)
	gen db_share = totdbpen_was_new_hh_r / tothhwlth_was_new_r
	gen db_share_bin = 1 if db_share == 0 | totdbpen_was_new_hh_r < 0 // no idea why WAS has someone with negative DB wealth but I'll put them here...
	replace db_share_bin = 2 if db_share > 0 & db_share <= 0.25
	replace db_share_bin = 3 if db_share > 0.25 & db_share <= 0.6
	replace db_share_bin = 4 if (db_share > 0.6 & db_share <= 1) | tothhwlth_was_new_r < totdbpen_was_new_hh_r 
	label define db_share_bin 1 "0%" 2 "0-25%" 3 "25-60%" 4 ">60%"
	label values db_share_bin db_share_bin 
	
	* Get wealth percentile 
	xtile hhwlth_rank_gilt = tothhwlth_gilt_r [pw=xshhwgt], nq(100)
	xtile hhwlth_rank_was_new = tothhwlth_was_new_r [pw=xshhwgt], nq(100)
	
	* And change in wealth percentile 
	gen wlthrank_change = hhwlth_rank_gilt - hhwlth_rank_was_new
	
	* Collapse to get average ranks by pension wealth decile 
	gen n = 1
	collapse (mean) hhwlth_rank_gilt hhwlth_rank_was_new wlthrank_change (sum) n [pw=xshhwgt], by(db_share_bin)
	
	* Get pop shares 
	egen tot = sum(n)
	gen pop_shr = n / tot
	drop tot
	
	* Label 
	label var hhwlth_rank_gilt "IFS methodology"
	label var hhwlth_rank_was_new "WAS methodology"
	
	* Export 
	export excel using "$output/was_report_underlying_data_new.xlsx", first(var) sheet("rank_move_by_db_wealth", replace)

end 
 
capture program drop gini_analysis
program define gini_analysis 

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
	
	* Export 
	export excel using "$output/was_report_underlying_data_new.xlsx", first(var) sheet("gini_coefficients", replace)

end  
 
 
/* Analysis we don't use 

capture program drop cohort_by_age_plot
program define cohort_by_age_plot

	use "$workingdata/was_clean", clear 
	
	* Make consistent weight 
	replace xswgt_nonproxy = xswgt if persprox != 2 & dataset_no == 3
	replace xswgt_nonproxy = 0 if persprox == 2 & dataset_no == 3

	* Approximate age and birth year 
	gen rand = runiform()
	gen approxage = .
	replace approxage = (dvage17 * 5) - 1 if rand < 0.2
	replace approxage = (dvage17 * 5) - 2 if inrange(rand, 0.2, 0.4)
	replace approxage = (dvage17 * 5) - 3 if inrange(rand, 0.4, 0.6)
	replace approxage = (dvage17 * 5) - 4 if inrange(rand, 0.6, 0.8)
	replace approxage = (dvage17 * 5) - 5 if rand > 0.8
	gen doby = year - approxage
	drop rand 
	
	* Get cohort 
	gen cohort = 1 if inrange(doby, 1930, 1939)
	replace cohort = 2 if inrange(doby, 1940, 1949)
	replace cohort = 3 if inrange(doby, 1950, 1959)
	replace cohort = 4 if inrange(doby, 1960, 1969)
	replace cohort = 5 if inrange(doby, 1970, 1979)
	replace cohort = 6 if inrange(doby, 1980, 1989)
	
	gen n = 1
	
	* Collapse to get median individual wealth by age and cohort 
	collapse (median) tothhwlth_was_new_r tothhwlth_gilt_r (rawsum) n [pw=xswgt_nonproxy], by(cohort approxage) 
	drop if n < 250
	drop if missing(cohort)
	
	* Make graphs 
	#delimit ; 
	graph twoway
		(connected tothhwlth_was_new_r approxage if cohort == 1)
		(connected tothhwlth_was_new_r approxage if cohort == 2)
		(connected tothhwlth_was_new_r approxage if cohort == 3)
		(connected tothhwlth_was_new_r approxage if cohort == 4)
		(connected tothhwlth_was_new_r approxage if cohort == 5)
		(connected tothhwlth_was_new_r approxage if cohort == 6),
		legend(order(1 "1930s" 2 "1940s" 3 "1950s" 4 "1960s" 5 "1970s" 6 "1980s")) xtitle("Age") ytitle("Median individual wealth");
	
	graph twoway
		(connected tothhwlth_gilt_r approxage if cohort == 1)
		(connected tothhwlth_gilt_r approxage if cohort == 2)
		(connected tothhwlth_gilt_r approxage if cohort == 3)
		(connected tothhwlth_gilt_r approxage if cohort == 4)
		(connected tothhwlth_gilt_r approxage if cohort == 5)
		(connected tothhwlth_gilt_r approxage if cohort == 6),
		legend(order(1 "1930s" 2 "1940s" 3 "1950s" 4 "1960s" 5 "1970s" 6 "1980s")) xtitle("Age") ytitle("Median individual wealth");
	#delimit cr
			
	* Reshape 
	reshape wide tothhwlth_was_new_r tothhwlth_gilt_r n, i(approxage) j(cohort)
	
	* Export 
	export excel tothhwlth_was_new* using "$output/was_report_underlying_data_new.xlsx", first(var) sheet("cohort_by_age_plot_was", replace)
	export excel tothhwlth_gilt_* using "$output/was_report_underlying_data_new.xlsx", first(var) sheet("cohort_by_age_plot_gilt", replace)


end 

capture program drop inequality_ratio_over_time 
program define inequality_ratio_over_time

	use "$workingdata/was_clean", clear 
	keep_hh_ref_person
	
	* Collapse to get the 50th and 90th percentile 
	foreach var of varlist tothhwlth*_r {
		gen `var'_p90 = `var'
		gen `var'_p50 = `var'
	}
	collapse (p50) *_p50 (p90) *_p90 [pw=xshhwgt], by(dataset_no)
	
	foreach x in gilt aa scpe was_new was_old constant {
		gen ratio_90_50_`x' = tothhwlth_`x'_r_p90 / tothhwlth_`x'_r_p50
	}
	keep dataset_no ratio*
	
	* Export
	export excel using "$output/was_report_underlying_data_new.xlsx", first(var) sheet("inequality_ratio_over_time", replace)


end 

capture program drop wealth_dist_r8
program define wealth_dist_r8

	* or do i want this to have two panels so i can show a few waves for each methodology? 

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
	label var tothhwlth_gilt_r "Gilt yields"
	label var tothhwlth_was_new_r "WAS methodology (new)"
	export excel using "$output/was_report_underlying_data_new.xlsx", first(varl) sheet("wealth_dist_r8", replace)

	

end 

capture program drop wealth_by_age_group
program define wealth_by_age_group 

	use "$workingdata/was_clean", clear 
	keep_hh_ref_person

	* Create age group variable
	assert !mi(dvage17)
	gen age_group = 1 if dvage17 <= 7
	replace age_group = 2 if inrange(dvage17, 8, 10)
	replace age_group = 3 if inrange(dvage17, 11, 12)
	replace age_group = 4 if inrange(dvage17, 13, 14)
	replace age_group = 5 if dvage17 >= 15
	label define age_group 1 "Age up to 34" 2 "Age 35-49" 3 "Age 50-59" 4 "Age 60-69" 5 "Age 70+"
	label values age_group age_group
	
	* Calculate total household wealth 
	collapse (sum) tothhwlth_*_r [pw=xshhwgt], by(age_group dataset_no)
	
	* Create the shares of total wealth 
	foreach var of varlist tot* {
		egen `var'_sum = sum(`var'), by(dataset_no)
		gen `var'_shr = `var' / `var'_sum
	}

	* Reshape 
	keep *was_new_r_shr *gilt_r_shr dataset_no age_group
	reshape wide tothhwlth_gilt_r_shr tothhwlth_was_new_r_shr, i(dataset_no) j(age_group)
	foreach x in was_new gilt {
		label var tothhwlth_`x'_r_shr1 "Age up to 34"
		label var tothhwlth_`x'_r_shr2 "Age 35-49"
		label var tothhwlth_`x'_r_shr3 "Age 50-59"
		label var tothhwlth_`x'_r_shr4 "Age 60-69"
		label var tothhwlth_`x'_r_shr5 "Age 70+"
	}
	
	* Export 
	export excel dataset_no tothhwlth_gilt_r_shr* using "$output/was_report_underlying_data_new.xlsx", first(varl) sheet("wealth_by_age_wave_gilt", replace)
	export excel dataset_no tothhwlth_was_new_r_shr* using "$output/was_report_underlying_data_new.xlsx", first(varl) sheet("wealth_by_age_wave_was_new", replace)

end 

capture program drop more_investigation
program define more_investigation

	use "$workingdata/was_clean", clear 
	keep_hh_ref_person
	
	* Round 8 
	keep if dataset_no == 8
	
	corr tothhwlth_gilt_r tothhwlth_was_new_r

	* Pension wealth vs non pension wealth correlation 
	gen nonpen_hhwlth_was_new_r = tothhwlth_was_new_r - totpen_was_new_hh_r

	corr nonpen_hhwlth_was_new_r totpen_was_new_hh_r
	
	* how big is the increase in pension wealth 
	gen pens_increase = (totpen_gilt_hh_r / totpen_was_new_hh_r) - 1
	corr pens_increase nonpen_hhwlth_was_new_r
	corr pens_increase totpen_was_new_hh_r
	
	gen pens_increase_abs = totpen_gilt_hh_r - totpen_was_new_hh_r
	corr pens_increase_abs nonpen_hhwlth_was_new_r
	corr pens_increase_abs totpen_was_new_hh_r
	
	gen wealth_increase = (tothhwlth_gilt_r - tothhwlth_was_new_r)
	
	* Ok what is the mean increase in pension wealth by intiial household wealth decile? 
	xtile hhwlth_decile_was_new = tothhwlth_was_new_r [pw=xshhwgt], nq(10)
	
	collapse (mean) wealth_increase pens_increase_abs tothhwlth_was_new_r  [pw=xshhwgt], by(hhwlth_decile_was_new)
	
	* Percentage increase 
	gen pc_increase = pens_increase / tothhwlth_was_new_r
	
	
	
	
	use "$workingdata/was_clean", clear 
	keep_hh_ref_person
	
	* Get deciles of household wealth under each methodology 
	gen hhwlth_decile_gilt = .
	gen hhwlth_decile_was_new = . 
	forval i = 1/8 {
		xtile hhwlth_decile_gilt`i' = tothhwlth_gilt_r [pw=xshhwgt] if dataset_no == `i', nq(10)
		replace hhwlth_decile_gilt = hhwlth_decile_gilt`i' if dataset_no == `i'
		xtile hhwlth_decile_was_new`i' = tothhwlth_was_new_r [pw=xshhwgt] if dataset_no == `i', nq(10)
		replace hhwlth_decile_was_new = hhwlth_decile_was_new`i' if dataset_no == `i'
		drop hhwlth_decile_gilt`i' hhwlth_decile_was_new`i'
	}
	
	* Get total household wealth in each decile for each methodology 	
	preserve
	collapse (sum) tothhwlth_gilt_r [pw=xshhwgt], by(hhwlth_decile_gilt dataset_no)
	ren *decile* decile 
	tempfile tomerge 
	save `tomerge', replace 
	restore 
	collapse (sum) tothhwlth_was_new_r [pw=xshhwgt], by(hhwlth_decile_was_new dataset_no)
	ren *decile* decile
	merge 1:1 decile dataset_no using `tomerge', assert(1 3) nogen
	
	* Get totals and shares 
	foreach x in gilt was_new {
		egen total_`x' = sum(tothhwlth_`x'_r), by(dataset_no)
		gen shr_`x' = tothhwlth_`x'_r / total_`x'
	}
	
	keep if dataset_no == 8 
	drop total*
	gen pc_increase = tothhwlth_gilt_r / tothhwlth_was_new_r
	gen abs_increase = tothhwlth_gilt_r - tothhwlth_was_new_r
	egen total_increase = sum(abs_increase)
	gen share_increase = abs_increase / total_increase
	
	
	* What if we do this without reranking 
	
	use "$workingdata/was_clean", clear 
	keep_hh_ref_person
	
	* Get deciles of household wealth under each methodology 
	gen hhwlth_decile_was_new = . 
	forval i = 1/8 {
		xtile hhwlth_decile_was_new`i' = tothhwlth_was_new_r [pw=xshhwgt] if dataset_no == `i', nq(10)
		replace hhwlth_decile_was_new = hhwlth_decile_was_new`i' if dataset_no == `i'
		drop hhwlth_decile_was_new`i'
	}
	
	* Get total household wealth in each decile for each methodology 	
	collapse (sum) tothhwlth_gilt_r tothhwlth_was_new_r [pw=xshhwgt], by(hhwlth_decile_was_new dataset_no)
	
	* Get totals and shares 
	foreach x in gilt was_new {
		egen total_`x' = sum(tothhwlth_`x'_r), by(dataset_no)
		gen shr_`x' = tothhwlth_`x'_r / total_`x'
	}
	
	keep if dataset_no == 8 
	drop total*
	gen pc_increase = tothhwlth_gilt_r / tothhwlth_was_new_r
	gen abs_increase = tothhwlth_gilt_r - tothhwlth_was_new_r
	egen total_increase = sum(abs_increase)
	gen share_increase = abs_increase / total_increase

end 

capture program drop south_east_wealth_share
program define south_east_wealth_share

	use "$workingdata/was_clean", clear 
	keep_hh_ref_person
			
	* Create South East variable 
	gen south_east = inlist(gor, 8, 9)
	
	* Collapse 
	collapse (sum) tothhwlth_*_r [pw=xshhwgt], by(south_east dataset_no)
			
	* Get the south east share 
	foreach var of varlist tothhwlth* {
		egen `var'_sum = sum(`var'), by(dataset_no)
		gen `var'_se_shr = `var' / `var'_sum
	}

	* Just keep south east share 
	keep if south_east == 1 
	drop south_east
	keep dataset_no *se_shr
	
	* Export 
	export excel using "$output/was_report_underlying_data_new.xlsx", first(var) sheet("south_east_wealth_share", replace)
	

end 

capture program drop regional_wealth_dist_r8
program define regional_wealth_dist_r8

	use "$workingdata/was_clean", clear 
	keep_hh_ref_person
	
	* Calculate median wealth in round 8 by region and methodology
	keep if dataset_no == 8 
	collapse (median) tothhwlth_*_r [pw=xshhwgt], by(gor)

	* Will try to make a map 
	* Export for now and work this out later 
	keep gor tothhwlth_gilt_r tothhwlth_was_new_r
	label var tothhwlth_gilt_r "IFS"
	label var tothhwlth_gilt_r "WAS"
	export excel using "$output/was_report_underlying_data_new.xlsx", first(var) sheet("regional_wealth_dist_r8", replace)

end 

capture program drop median_indwealth_by_sex
program define median_indwealth_by_sex

	use "$workingdata/was_clean", clear 

	replace xswgt_nonproxy = xswgt if persprox != 2 & dataset_no == 3
	replace xswgt_nonproxy = 0 if persprox == 2 & dataset_no == 3

	* Get median wealth by dataset and age group
	collapse (median) totindwlth_*_r (mean) mean_was_new=totindwlth_was_new_r mean_gilt=totindwlth_gilt_r [pw=xswgt_nonproxy], by(dataset_no sex)
	
	* REshape for outputting 
	keep dataset_no sex totindwlth_gilt_r totindwlth_was_new_r 
	reshape wide totindwlth_gilt_r totindwlth_was_new_r, i(dataset_no) j(sex) 
	
	label var totindwlth_gilt_r1 "IFS methodology - men"
	label var totindwlth_gilt_r2 "IFS methodology - women"
	label var totindwlth_was_new_r1 "WAS methodology - men"
	label var totindwlth_was_new_r2 "WAS methodology - women"
	
	export excel using "$output/was_report_underlying_data_new.xlsx", first(varl) sheet("median_indwealth_by_sex", replace)
	
end 

capture program drop wealth_distribution_shares
program define wealth_distribution_shares

	use "$workingdata/was_clean", clear 
	keep_hh_ref_person
	
	* Get deciles of household wealth under each methodology 
	gen hhwlth_decile_gilt = .
	gen hhwlth_decile_was_new = . 
	forval i = 1/8 {
		xtile hhwlth_decile_gilt`i' = tothhwlth_gilt_r [pw=xshhwgt] if dataset_no == `i', nq(10)
		replace hhwlth_decile_gilt = hhwlth_decile_gilt`i' if dataset_no == `i'
		xtile hhwlth_decile_was_new`i' = tothhwlth_was_new_r [pw=xshhwgt] if dataset_no == `i', nq(10)
		replace hhwlth_decile_was_new = hhwlth_decile_was_new`i' if dataset_no == `i'
		drop hhwlth_decile_gilt`i' hhwlth_decile_was_new`i'
	}
	
	* Get total household wealth in each decile for each methodology 	
	preserve
	collapse (sum) tothhwlth_gilt_r [pw=xshhwgt], by(hhwlth_decile_gilt dataset_no)
	ren *decile* decile 
	tempfile tomerge 
	save `tomerge', replace 
	restore 
	collapse (sum) tothhwlth_was_new_r [pw=xshhwgt], by(hhwlth_decile_was_new dataset_no)
	ren *decile* decile
	merge 1:1 decile dataset_no using `tomerge', assert(1 3) nogen
	
	* Get totals and shares 
	foreach x in gilt was_new {
		egen total_`x' = sum(tothhwlth_`x'_r), by(dataset_no)
		gen shr_`x' = tothhwlth_`x'_r / total_`x'
	}
	
	export excel decile shr* using "$output/was_report_underlying_data_new.xlsx" if dataset_no == 8, first(var) sheet("wealth_dist_r8_full", replace)
	

	* Simplify this 
	recode decile (1 2 3 4 5 = 1) (6 7 8 = 2) (9 = 3) (10 = 4), gen(group)
	collapse (sum) shr*, by(group dataset_no)
	label define group 1 "Bottom 50%" 2 "50-80%" 3 "80-90%" 4 "Top 10%"
	label values group group

	* Export the top 10% share over time 
	export excel dataset_no shr_* using "$output/was_report_underlying_data_new.xlsx" if group == 4, first(var) sheet("top_10pc_share_over_time", replace)
	
	* Reshape and clean up 
	reshape wide shr_gilt shr_was_new, i(dataset_no) j(group)
	forval i = 1/4 {
		ren shr_*`i' shr`i'*
	}
	reshape long shr1 shr2 shr3 shr4, i(dataset_no) j(method) string
	label var shr1 "Bottom 50%" 
	label var shr2 "50-80%" 
	label var shr3 "80-90%" 
	label var shr4 "Top 10%"
	label var method "Methodology"
	replace method = "IFS methodology" if method == "gilt"
	replace method = "ONS methodology" if method == "was_new"
	
	keep if dataset_no == 8 
	drop dataset_no
	
	* Export excel 
	export excel method shr_* using "$output/was_report_underlying_data_new.xlsx" if dataset_no == 8, first(varl) sheet("wealth_dist_r8", replace)
	
	
	
	* What if we do this at the individual level? 
	use "$workingdata/was_clean", clear 
	
	* Make consistent weight 
	replace xswgt_nonproxy = xswgt if persprox != 2 & dataset_no == 3
	replace xswgt_nonproxy = 0 if persprox == 2 & dataset_no == 3
	
	keep if dataset_no >= 3

	* Get deciles of individual wealth under each methodology 
	gen indwlth_decile_gilt = .
	gen indwlth_decile_was_new = . 
	forval i = 3/8 {
		xtile indwlth_decile_gilt`i' = totindwlth_gilt_r [pw=xswgt_nonproxy] if dataset_no == `i', nq(10)
		replace indwlth_decile_gilt = indwlth_decile_gilt`i' if dataset_no == `i'
		xtile indwlth_decile_was_new`i' = totindwlth_was_new_r [pw=xswgt_nonproxy] if dataset_no == `i', nq(10)
		replace indwlth_decile_was_new = indwlth_decile_was_new`i' if dataset_no == `i'
		drop indwlth_decile_gilt`i' indwlth_decile_was_new`i'
	}
	
	* Get total household wealth in each decile for each methodology 	
	preserve
	collapse (sum) totindwlth_gilt_r [pw=xswgt_nonproxy], by(indwlth_decile_gilt dataset_no)
	ren *decile* decile 
	tempfile tomerge 
	save `tomerge', replace 
	restore 
	collapse (sum) totindwlth_was_new_r [pw=xswgt_nonproxy], by(indwlth_decile_was_new dataset_no)
	ren *decile* decile
	merge 1:1 decile dataset_no using `tomerge', assert(1 3) nogen
	
	* Get totals and shares 
	foreach x in gilt was_new {
		egen total_`x' = sum(totindwlth_`x'_r), by(dataset_no)
		gen shr_`x' = totindwlth_`x'_r / total_`x'
	}
	
	* Also doesn't make much difference in R8
	
	

end 


