/* 

Variables you need are: 
	case(w1-5; r5-7) (Household ID), 
	person(w1-6; r7) (Person ID), 
	r01-r09(w1-6; r7) (relationship variables), 
	isdep(w1-6; r7) (measures dependency status).

It is designed to be run on person-level raw WAS datasets - the only manual input is the was_dataset, which is 1-5 for waves 1-5, then 6-8 for rounds 5-7. 
WAS wave 1 has no relationship variables so benefit units cannot be assigned to observations there. 

It generates a variable called buno, which is each individual's BU number within each household 

Significant amounts of manual recoding have been required - currently working on creating any other rules which can prevent some of these. Lots of obvious mistakes with the ways relationships have been coded in WAS 

(NB household measured by caser5 == 11251 has something wrong with them which I haven't quite figured out yet. IDs shifting around between waves) 

The programme recodes some relationship (r) variables when they look like they are surely wrong. It does this both manually and using rules. To check how many cases there are of various unusual outcomes, after the programme has finished run
    macro list tooyoung_test
    macro list numpartners_test
    macro list missingxrshh_test
    macro list weirdcases_test
    macro list nonseqbunos_test
*/


cap prog drop assigntobu
prog define assigntobu
	
	syntax, rvals(string) persnoA(numlist max = 1) [kidsonly] [adultsonly]
	
	local persnoAm1 = `persnoA' - 1

	local agecond
	if "`kidsonly'" == "kidsonly" local agecond & isdep == 1
	if "`adultsonly'" == "adultsonly" local agecond & isdep == 2

	forvalues persnoB = 1 / `persnoAm1' {
		local Bxrext = `persnoB' 
		if `Bxrext' < 10 local Bxrext 0`Bxrext'
		replace mybuno = buno_`persnoB' if inlist(r`Bxrext',`rvals') `agecond' & (pers_num == `persnoA') & (mybuno == .) & (buno_`persnoB' != 0)
	}

end

cap prog drop assignWASbunos
prog define assignWASbunos

	// 'was_dataset' is 2-5 for waves 2-5, 6-8 for rounds 5-7
	syntax, was_dataset(numlist max = 1) 
	
	// Minimally clean data first - just remove r7 suffixes, make vars lowercase
	rename *, lower 
	gen dataset_no = `was_dataset'
	
	local suffix
		if (`was_dataset' == 2) local suffix "w2"
		if (`was_dataset' == 3) local suffix "w3"
		if (`was_dataset' == 4) local suffix "w4"
		if (`was_dataset' == 5) local suffix "w5"
		if (`was_dataset' == 6) local suffix "r5"
		if (`was_dataset' == 7) local suffix "r6"
		if (`was_dataset' == 8) local suffix "r7"
		if (`was_dataset' == 9) local suffix "r8"
		
	gen pers_num = .
	if inlist(`was_dataset', 2, 3, 4, 5, 8, 9) replace pers_num = person`suffix'

	if (`was_dataset' == 6) replace pers_num = personw5 
	if (`was_dataset' == 6) replace pers_num = personw4 if mi(pers_num)
	
	if (`was_dataset' == 7) replace pers_num = personw6 
	if (`was_dataset' == 7) replace pers_num = personw5 if mi(pers_num)
	
	gen hhid = .
	replace hhid = case`suffix' 
	
	local wave_vars r01 r02 r03 r04 r05 r06 r07 r08 r09 isdep
	
	foreach var in `wave_vars' {
		if (`was_dataset' == 6) {
			gen `var' =.
			replace `var' = `var'w5
			replace `var' = `var'w4 if `var'w5 ==.
			drop `var'w5 `var'w4
		}
		if (`was_dataset' == 7) {
			gen `var' =.
			replace `var' = `var'w6
			replace `var' = `var'w5 if `var'w6 ==.
			drop `var'w6 `var'w5
		}
	}
	
	if inlist(`was_dataset', 2, 3, 4, 5, 8, 9) rename r??`suffix' r?? 
	
	if inlist(`was_dataset', 2, 3, 4, 5, 8, 9) rename isdep`suffix' isdep
	
	// local for the max number of people in a household
	su pers_num
	local maxpersnodataset = r(max)
	
	// recode if relationship variables missing
	recode r01 (. = -7)
	
	*** Recode some XR vars
	// recode those under 15 measured as a parent of someone to a child of someone
	global tooyoung_test = 0
	foreach v of varlist r?? {
		qui count if inlist(`v', 1, 2, 7, 8, 10, 20) & dvage17`suffix' < 4 // under 15
		global tooyoung_test = ${tooyoung_test} + r(N) // number of people for whom this holds
		replace `v' = 3 if inlist(`v', 1, 2, 7, 8, 10, 20) & dvage17`suffix' < 4 // recode as child
	}

	
	*If two people list someone as a partner, recode the second to other non-relative
	g numpartners = 0
	forvalues persnoA = 1 / `maxpersnodataset' {  //The two suitors
		local persnoAm1 = `persnoA' - 1
		forvalues persnoB = 1 / `persnoAm1' {  //The centre of the love triangle
			local Bxrext = `persnoB' 
			if `Bxrext' < 10 local Bxrext 0`Bxrext'
			bys hhid: egen persnoAisBspartner = max((pers_num == `persnoA') * inlist(r`Bxrext',1,2,20))
			replace numpartners = numpartners + 1 if (pers_num == `persnoB') & persnoAisBspartner
			bys hhid: egen Bnumpartners = max((pers_num == `persnoB') * numpartners)
			replace r`Bxrext' = 18 if (pers_num == `persnoA') & (Bnumpartners > 1) & inlist(r`Bxrext',1,2,20)
			drop persnoAisBspartner Bnumpartners
		}
	}
	tab numpartners
	qui count if numpartners > 1
	global numpartners_test = r(N)
	drop numpartners
	
	// edit isdep - check that not measured as independent if they are listed by a partner, or if they list a partner 
	foreach v of varlist r?? {
		replace isdep = 2 if inlist(`v',1,2,20) & isdep == 1
	}
	
	forvalues persnoA = 1 / `maxpersnodataset' {  // This is the partner
		local persnoAm1 = `persnoA' - 1
		forvalues persnoB = 1 / `persnoAm1' {  // This is the depchild
			local Bxrext = `persnoB' 
			if `Bxrext' < 10 local Bxrext 0`Bxrext'
			bys hhid: egen persnoAisBspartner = max((pers_num == `persnoA') * inlist(r`Bxrext',1,2,20))
			replace isdep = 2 if isdep == 1 & (pers_num == `persnoB') & persnoAisBspartner
			drop persnoAisBspartner
		}
	}

	*Some additional vars that will be helpful later
	bys hhid: egen maxpersnohh = max(pers_num)
	bys hhid: egen minpersnohh = min(pers_num)
	bys hhid: egen numadultshh = sum(isdep == 2)
	bys hhid: g numpersonhh = _N

	/* NB not the case in r7 - can check earlier */
	
	*If no XR vars are recorded for a whole household, check that there are no more than two adults in the household.
	//If so, then make a note of this and later we'll just put them all in BU 1.
	g maxxrvar = -1000
	foreach v of varlist r?? {
		bys hhid: egen maxv = max(`v')
		replace maxxrvar = maxv if maxv > maxxrvar
		drop maxv
	}
	g missingxrshh = (maxxrvar == -9) & (numpersonhh > 1) & (numadultshh <= 2)
	tab missingxrshh
	qui count if missingxrshh
	global missingxrshh_test = r(N)
	drop maxxrvar
	
	
	***Main assignment
	*First person
	//Set the buno of the first person to 1 (possible that they aren't persno = 1 as sometimes that is missing for some reason)
	
	sort hhid pers_num
	by hhid: g firinhh = _n == 1
	g mybuno = 1 if firinhh //This var will eventually be what we use to identify benunits
	g maxbuno = 1  //This is the highest buno assigned thus far
	forvalues i = 1 / `maxpersnodataset' {
		g buno_`i' = . //buno_X is the buno of persno X
		replace buno_`i' = 1 if minpersnohh == `i'
	}

	//If no XR vars have been recorded, now recode the whole house to BU 1
	replace mybuno = 1 if missingxrshh

	*Find spouses and children, in cases (the vast majority) where the child has a higher persno than the responsible adult, so they are listed as a child (rather than the parent listed as a parent)
	forvalues persnoA = 2 / `maxpersnodataset' {  //We are assigning a buno to this person
		//Assign to partners
		//Loop over relations with other people, looking for partners
		assigntobu, rvals(1,2,20) persnoA(`persnoA')
		//Now the kids
		assigntobu, rvals(3,4,5,6) persnoA(`persnoA') kidsonly
		//Looks like they need to be in a new BU (if they are an adult)
		replace mybuno = maxbuno + 1 if (pers_num == `persnoA') & (mybuno == .) & isdep == 2
		
		//Update
		bys hhid: egen persnoAexists = max(pers_num == `persnoA')
		bys hhid: egen buno_`persnoA'_temp = max(mybuno * (pers_num == `persnoA')) if (`persnoA' <= maxpersnohh) & persnoAexists
		replace buno_`persnoA' = buno_`persnoA'_temp if (`persnoA' <= maxpersnohh) & (buno_`persnoA'_temp != 0)
		bys hhid: egen maxbuno_temp = max(mybuno)
		replace maxbuno = maxbuno_temp
		drop maxbuno_temp persnoAexists buno_`persnoA'_temp
	}
	cap assertdiag (mybuno != .) & (mybuno > 0) if isdep == 2
	if _rc != 0 {
		di as error "assignWASbunos error 1"
		error(1412)
	}

	*For parents who have a higher persno than their kids, and are therefore listed as parents, give the kid the parent's buno
	forvalues persnoA = 2 / `maxpersnodataset' {  //This is the parent
		local persnoAm1 = `persnoA' - 1
		forvalues persnoB = 1 / `persnoAm1' {  //This is the kid
			local Bxrext = `persnoB' 
			if `Bxrext' < 10 local Bxrext 0`Bxrext'
			bys hhid: egen persnoAisBsparent = max((pers_num == `persnoA') * inlist(r`Bxrext',7,8))
			replace mybuno = buno_`persnoA' if (pers_num == `persnoB') & ((mybuno == .) | firinhh) & persnoAisBsparent & isdep == 1  //If firinhh, overwrite mybuno - this is when the kid
			//is the first person in the HH and so just got assigned buno 1
			drop persnoAisBsparent
			//Update
			bys hhid: egen persnoBexists = max(pers_num == `persnoB')
			bys hhid: egen buno_`persnoB'_temp = max(mybuno * (pers_num == `persnoB')) if `persnoB' <= maxpersnohh & persnoBexists
			replace buno_`persnoB' = buno_`persnoB'_temp if `persnoB' <= maxpersnohh
			bys hhid: egen maxbuno_temp = max(mybuno)
			replace maxbuno = maxbuno_temp
			drop maxbuno_temp persnoBexists buno_`persnoB'_temp
		}
	}

	*For any remaining kids, assign them to the bunos of other adults in the following order: grandparents; then other relatives; then other non-relatives, then siblings;
	//then son/daughter in law, then brother/sister in law.
	forvalues persnoA = 2 / `maxpersnodataset' {  //We are assigning a buno to this person
		assigntobu, rvals(16) persnoA(`persnoA') kidsonly // grandparents
		assigntobu, rvals(17) persnoA(`persnoA') kidsonly // other relatives
		assigntobu, rvals(18) persnoA(`persnoA') kidsonly // other non relatives
		assigntobu, rvals(11,12) persnoA(`persnoA') kidsonly // siblings
		assigntobu, rvals(6) persnoA(`persnoA') kidsonly
		assigntobu, rvals(15) persnoA(`persnoA') kidsonly
		//Update
		bys hhid: egen persnoAexists = max(pers_num == `persnoA')
		bys hhid: egen buno_`persnoA'_temp = max(mybuno * (pers_num == `persnoA')) if `persnoA' <= maxpersnohh & persnoAexists
		replace buno_`persnoA' = buno_`persnoA'_temp if `persnoA' <= maxpersnohh
		bys hhid: egen maxbuno_temp = max(mybuno)
		replace maxbuno = maxbuno_temp
		drop maxbuno_temp persnoAexists buno_`persnoA'_temp
	}

	cap assertdiag (mybuno != .) & (mybuno > 0)
	if _rc != 0 {
		di as error "assignWASbunos error 2"
		error(1412)
	}

	*Obscure situation - you are a child in your own BU, but there is an adult in the HH. This happens if a child is listed as the first person, and if the
	//second person is their sibling, but an adult. And maybe in some other situations. Put the kid in the same BU as the first adult
	bys hhid mybuno: g numinbu = _N
	g childaloneinbu = isdep == 1 & numinbu == 1
	bys hhid: egen numkidsaloneinbu = sum(childaloneinbu)
	assertdiag numkidsaloneinbu <= 1
	drop numkidsaloneinbu
	bys hhid: egen childaloneinbu_buno = max(mybuno * childaloneinbu)
	//Find the persno of the first adult
	sort hhid pers_num
	by hhid: gen adnuminhh = sum(isdep == 2) //Running sum
	g firadinhh = adnuminhh == 1
	drop adnuminhh
	by hhid: egen firadinhh_buno = max(mybuno * firadinhh)
	forvalues pers_num = 1 / `maxpersnodataset' {
		replace mybuno = childaloneinbu_buno if (childaloneinbu_buno > 0) & (mybuno > childaloneinbu_buno) & (mybuno == firadinhh_buno)
		//Line above says: put my buno to that of the lonesome kid if the kid has a lower buno than me and I am in the same buno as the first adult in the HH. This ensures
		//that spouses/other kids get moved together
		replace mybuno = firadinhh_buno      if childaloneinbu & (numadultshh > 0) & (mybuno > firadinhh_buno)
		//Line above says: put my buno to that of the first adult in the HH if there is such a person and I am a lonesome kid and the first adult has a lower buno than me 
	}

	***Checks
	cap assertdiag (mybuno != .) & (mybuno > 0)
	if _rc != 0 {
		di as error "assignWASbunos error 3"
		error(1412)
	}
	drop childaloneinbu numinbu //Recalculate this now that we've made some adjustments for it
	bys hhid mybuno: g numinbu = _N
	g childaloneinbu = isdep == 1 & numinbu == 1
	assertdiag numadultshh == 0 if childaloneinbu  //If you are a kid in a BU of your own, can only be if there are no adults around
	gen weird_kid = . 
	gen weird_adult = .
	global weirdcases_test = 0
	forvalues persnoA = 1 / `maxpersnodataset' {  //Check that essentially everyone is in the same BU as their spouse or kid when adults are listed first - basically the straightforward cases
		local persnoAm1 = `persnoA' - 1           //Some cases where this won't hold: eg a man & woman have a kid together, live together, but are not a couple anymore. Then the kid
		forvalues persnoB = 1 / `persnoAm1' {     //gets put in one of the parent's BUs, but the other parent is in a diff BU, so the kid is in a diff BU to one parent.
			local Bxrext = `persnoB' 		  //Hence why these are not written as assertdiags - these are not necessarily wrong, but they should be rare.
			if `Bxrext' < 10 local Bxrext 0`Bxrext'
			qui bys hhid: egen persnoB_buno = max(mybuno * (pers_num == `persnoB'))
			replace weird_adult = 1 if mybuno != persnoB_buno & inlist(r`Bxrext',1,2,20) & (pers_num == `persnoA') & (persnoB_buno > 0)
			qui count if mybuno != persnoB_buno & inlist(r`Bxrext',1,2,20) & (pers_num == `persnoA') & (persnoB_buno > 0) //Last condition is just in case for some reason persnoB is not in the survey
			local weirdcases_sp = r(N)
			// attach an indicator variable if 'weird kid' - this is the majority of cases
			replace weird_kid = 1 if mybuno != persnoB_buno & inlist(r`Bxrext',3,4,5) & (pers_num == `persnoA') & (persnoB_buno > 0) & isdep == 1
			qui count if mybuno != persnoB_buno & inlist(r`Bxrext',3,4,5) & (pers_num == `persnoA') & (persnoB_buno > 0) & isdep == 1
			local weirdcases_kid = r(N)
			if (`weirdcases_sp' > 0) | (`weirdcases_kid' > 0) di "`persnoA' -- `persnoB': weird cases = `weirdcases_sp' + `weirdcases_kid'"
			drop persnoB_buno
			global weirdcases_test = ${weirdcases_test} + `weirdcases_sp' + `weirdcases_kid'
		}
	}
	
	// this checks that there are only two adults in each benefit unit
	bys hhid mybuno: egen numadsbu = sum(isdep == 2)
	cap assertdiag numadsbu <= 2
	if _rc != 0 {
		di as error "assignWASbunos error 4"
		error(1412)
	}

	*Possible that bunos are not sequential or not based at 1 in obscure situations; fix.
	su mybuno
	local maxbuno = r(max)
	forvalues i = 1 / `maxbuno' {
		bys hhid: egen buno`i'exists = max(mybuno == `i')
	}
	global nonseqbunos_test = 0
	forvalues i = 1 / `maxbuno' {
		qui count if !buno`i'exists & (`i' < mybuno)
		global nonseqbunos_test = ${nonseqbunos_test} + r(N)
		replace mybuno = mybuno - 1 if !buno`i'exists & (`i' < mybuno)
	}
	sort hhid mybuno
	assertdiag inlist(mybuno,mybuno[_n-1],mybuno[_n-1]+1) if hhid == hhid[_n-1] //Sequential bunos
	bys hhid: egen minbuno = min(mybuno)
	assertdiag minbuno == 1
	
	***Clean up 
	
	ren mybuno buzno
	drop *buno*
	ren buzno buno
	lab var buno "Within-household benefit unit number"
	drop maxpersnohh minpersnohh numadultshh numinbu childaloneinbu firadinhh numadsbu firinhh missingxrshh numpersonhh weird_kid weird_adult pers_num hhid dataset_no


end
