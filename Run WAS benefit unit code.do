/*
7/4/22
BB
Run coresidence code, create code with case / person / benefit unit number
*/

/*
Using assignWASbunos program here, which runs on WAS raw person-level code. Have to generate dataset number first - 1-5 for w1-5, 6-8 for r5-7. Can't do this for wave 1 - no relationship grid variables.

This code produces a file with:
	casew2-r7 (household IDs for each dataset)
	personw2-r7 (individual IDs for each dataset)
	buno (benefit unit number for each person within each household).
	
I've kept so many different case and person variables, most of which are empty for most observations, so it can be merged directly into each WAS dataset without changing variable names, matching on case and person.
*/

***** iterate (save tempfiles, append )
// Loop over waves, then rounds 

forv i = 2/5 {

	if `i' == 2 {
		use "$rawWAS/was_wave_`i'_person_eul_nov_2020", clear 
	}
	
	if inrange(`i', 3, 5) {
		use "$rawWAS/was_wave_`i'_person_eul_oct_2020", clear
	}
	
	* No relationship (or other) vars 
	if `i' == 3 {
		drop if CASEW3 == 6492
	}
	if `i' == 4 {
		drop if CASEW4 == 12063 | CASEW4 == 4143
	}
	
	if `i' == 5 {
		drop if CASEW5 == 13754
	}
	
	assignWASbunos, was_dataset(`i')
	
	keep personw`i' casew`i' buno
	
	save "$workingdata/WAS_BUno_mappings_w`i'", replace
}


forv i = 5/8 {
	
	if `i' == 5 {
		use "$rawWAS/was_round_`i'_person_eul_oct_2020", clear 
		* no relationship (or other) vars
		drop if CASER5 == 2917
	}
	
	if `i' == 6 {
		use "$rawWAS/was_round_`i'_person_eul_april_2022", clear
		drop if CASER6 == 16554 | CASER6 == 17557
	}
	
	if `i' == 7 {
		use "$rawWAS/was_round_`i'_person_eul_june_2022", clear
	}
	
	if `i' == 8 {
		use "$rawWAS/was_round_8_person_eul_march_2022_100225", clear 
		drop if CASER8 == 8326
	}
	
	local dataset_no =`i'+1
	
	assignWASbunos, was_dataset(`dataset_no') 
	
	if inrange(`i', 5, 6) {
		local j = `i'-1
		keep personw`i' personw`j' caser`i' buno
	}
	
	if `i' >= 7 {
		keep personr`i' caser`i' buno
	}
	
	save "$workingdata/WAS_BUno_mappings_r`i'", replace
	
}

