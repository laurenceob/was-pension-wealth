/********************************************************************************
**** Title: 		get_discount_rates.do 
**** Author: 		Laurence O'Brien 
**** Date started: 	12/06/2025
**** Description:	Takes raw data containing gilt yields and corporate bond yields and cleans it ready for use
********************************************************************************/
********************************************************************************
* SCAPE rate (real)
********************************************************************************

* Rather than creating a dataset for this, it's just a few lines of code so it's in a program instead 

cap program drop gen_real_scpe
program define gen_real_scpe

	syntax, newvar(string) yearvar(varname) monthvar(varname)

	gen `newvar' = 0.035 // scape rate was initially based on social time preference rate - RPI+3.5
	replace `newvar' = 0.03 if `yearvar' > 2011 | (`yearvar' == 2011 & `monthvar' >= 4) // scape rate set at CPI+3 in 2011 budget (and moves to reflect long term GDP growth)
	replace `newvar' = 0.028 if `yearvar' > 2016 | (`yearvar' == 2016 & `monthvar' >= 4)	// scape rate reduced to CPI+2.8 in 2016 Budget (16 Mar 2016)
	replace `newvar' = 0.024 if `yearvar' > 2018 | (`yearvar' == 2018 & `monthvar' >= 11) // scape rate reduced to CPI+2.4 in 2018 Budget (October 2018)
	replace `newvar' = 0.017 if `yearvar' > 2023 | (`yearvar' == 2023 & `monthvar' >= 4) // scape rate reduced to CPI+1.7 in 2023

end


********************************************************************************
* Gilts
********************************************************************************

* Data before 2016 
import excel using "$rawdata/gilts_data_79_15.xlsx", clear sheet("4. spot curve")

* Sort out variable names 
missings dropvars, force
destring B, force replace
ds A, not 
foreach var in `r(varlist)' {
	sum `var' if _n == 4
	local newname = subinstr("`r(mean)'", ".", "point", .)
	ren `var' real_gilt_yield`newname'
}
drop if inrange(_n, 1, 5)

* Clean up
gen date = date(A, "DMY")
format date %td
drop A
drop if date < td(01jan2006)
order date

* Reshape 
reshape long real_gilt_yield, i(date) j(maturity) string
replace maturity = subinstr(maturity, "point", ".", .)
destring maturity, replace

* Get the early maturities if missing (assume this is the same as the shortest nonmissing maturity)
bys date (maturity): replace real_gilt_yield = real_gilt_yield[_n+1] if missing(real_gilt_yield)
assert maturity == 2.5 if missing(real_gilt_yield)
gen yield3 = real_gilt_yield if maturity == 3 
egen yield_3 = max(yield3), by(date)
replace real_gilt_yield = yield_3 if maturity == 2.5 & missing(real_gilt_yield)
assert !missing(real_gilt_yield)
drop yield_3 yield3

* Get ready to extend to longer maturities 
levelsof date, local(dates) 
local nummaturities = 76
by date: gen tocount = (_n == 1)
qui sum tocount if tocount == 1
local numdates = `r(N)'
drop tocount 

* going to assume that the yield curve is flat after 25 
gen yield25 = real_gilt_yield if maturity == 25
egen yield_25 = max(yield25), by(date)
drop yield25

tempfile tomerge 
save `tomerge', replace 

* Add on the longer maturities 
clear 
set obs `=`nummaturities' * `numdates''
gen date = . 
gen maturity = . 
local start = 1
foreach date in `dates' {
	replace date = `date' if inrange(_n, `start', `=`start'+75')
	local start = `start' + `nummaturities'
} 
local counter = 1
forval i = 2.5(0.5)40 {
	replace maturity = `i' if mod(_n, `nummaturities') == `counter'
	local counter = `counter' + 1
}
replace maturity = 40 if missing(maturity)
merge 1:1 date maturity using `tomerge', nogen

* Now extend 
egen yield25 = max(yield_25), by(date)
replace real_gilt_yield = yield25 if maturity > 25
drop yield_25 yield25

* Save the earlier data
tempfile toappend 
save `toappend', replace 

* Data from 2016 onwards
import excel using "$rawdata/gilts_data_16_24.xlsx", clear sheet("4. spot curve")

* Sort out variable names 
missings dropvars, force
destring B, force replace
ds A, not 
foreach var in `r(varlist)' {
	sum `var' if _n == 4
	local newname = subinstr("`r(mean)'", ".", "point", .)
	ren `var' real_gilt_yield`newname'
}
drop if inrange(_n, 1, 5)

* Clean up
gen date = date(A, "DMY")
format date %td
drop A
drop if date < td(01jan2006)
order date

* Reshape 
reshape long real_gilt_yield, i(date) j(maturity) string
replace maturity = subinstr(maturity, "point", ".", .)
destring maturity, replace

* Get the early maturities if missing (assume this is the same as the shortest nonmissing maturity)
bys date (maturity): replace real_gilt_yield = real_gilt_yield[_n+1] if missing(real_gilt_yield)
assert inlist(maturity, 2.5, 3) if missing(real_gilt_yield)
gen yield35 = real_gilt_yield if maturity == 3.5
egen yield_35 = max(yield35), by(date)
replace real_gilt_yield = yield_35 if maturity == 3 & missing(real_gilt_yield)
gen yield3 = real_gilt_yield if maturity == 3 
egen yield_3 = max(yield3), by(date)
replace real_gilt_yield = yield_3 if maturity == 2.5 & missing(real_gilt_yield)
assert !missing(real_gilt_yield)
drop yield_3 yield3 yield_35 yield35

* Append together 
append using `toappend'
sort date

* Extract the month and year 
gen month = month(date)
gen year = year(date)
drop date

replace real_gilt_yield = real_gilt_yield / 100

* Need to add on RPI-CPI wedge 
* Or CPIH-CPI wedge
* First make a variable showing what share of what we are adding on is RPI-CPI wedge and what share is CPIH-CPI wedge 
gen statamonth = ym(year, month)
gen finalmonth = statamonth + 12 * maturity
gen rpishare = 1 if year < 2020 | (year == 2020 & month < 11) | finalmonth < tm(2030m2)
replace rpishare = (tm(2030m2) - statamonth) / (finalmonth - statamonth) if missing(rpishare)
assert inrange(rpishare, 0, 1)

replace real_gilt_yield = real_gilt_yield + ($rpicpiwedge * rpishare) + ($cpihcpiwedge * (1 - rpishare))
drop rpishare statamonth finalmonth

order year month maturity real_gilt_yield
sort year month maturity
format real_gilt_yield %6.5f

* Save 
save "$workingdata/real_gilt_yields", replace

********************************************************************************
* Corporate bond yields 
********************************************************************************

* First - get expected inflation 
import excel using "$rawdata/inflation_data_79_15.xlsx", clear sheet("4. spot curve")

* Just keep 15 years maturity for now
keep A AA
assert AA == 15 if A == "years:"

* Clean up
drop if inrange(_n, 1, 5)
gen date = date(A, "DMY")
format date %td
drop A
ren AA rpi_rate
drop if date < td(01jan2006)
order date

tempfile toappend 
save `toappend', replace 

* Data from 2016 onwards 
import excel using "$rawdata/inflation_data_16_24.xlsx", clear sheet("4. spot curve")

* Just keep 15 years maturity 
keep A AA
assert AA == 15 if A == "years:"
drop if inrange(_n, 1, 5)
gen date = date(A, "DMY")
format date %td
drop A
ren AA rpi_rate
order date

* Append together 
append using `toappend'
sort date

* Make it CPI rate by taking off the RPI-CPI wedge (and the CPIH-CPI wedge where relevant)
* First make a variable showing what share of what we are adding on is RPI-CPI wedge and what share is CPIH-CPI wedge 
gen month = month(date)
gen year = year(date)
gen statamonth = ym(year, month)
gen finalmonth = statamonth + 12 * 15 // looking at 15 years maturity
gen rpishare = 1 if year < 2020 | (year == 2020 & month < 11) | finalmonth < tm(2030m2)
replace rpishare = (tm(2030m2) - statamonth) / (finalmonth - statamonth) if missing(rpishare)
assert inrange(rpishare, 0, 1)

gen cpi_rate = rpi_rate - ($rpicpiwedge * 100 * rpishare) - ($cpihcpiwedge * 100 * (1 - rpishare))
drop rpishare statamonth finalmonth year month rpi_rate

* Save 
tempfile inflation_data
save `inflation_data', replace 

* Get corporate bond yields 
import excel using "$rawdata/yields_data.xlsx", clear first
ren (Name IBOXXCORPORATESAA10Annu) (date nominal_aa)
format date %td

* Make end of month 
replace date = date - 1

* Merge in with inflation data
merge 1:1 date using `inflation_data'
keep if _merge == 3 
drop _merge

* Make real aa rate 
gen real_aa_yield = nominal_aa - cpi_rate 
drop nominal_aa cpi_rate

* Extract the month and year 
gen month = month(date)
gen year = year(date)
drop date

replace real_aa_yield = real_aa_yield / 100

* Save 
save "$workingdata/real_aa_yields", replace






