prog define assertdiag

	syntax anything [if/] [in/], [GENerate(namelist max = 1)] [pause] [pausedisp(string)]

	if "`generate'" == "" local newvar trouble
	else local newvar `generate'

	if "`if'" != "" {
		cap noi assert `anything' if `if'
		local gencond & `if'
		local ifwithif if `if'
		local inwithin
	}
	else if "`in'" != "" {
		cap noi assert `anything' in `in'
		local gencond & `in'
		local inwithin in `in'
		local ifwithif
	}
	else {
		cap noi assert `anything'
		local gencond
		local ifwithif
		local inwithin
	}

	if _rc != 0 {
		cap drop `newvar'
		local existingnewvar = 0
		if _rc == 0 local existingnewvar = 1
		g `newvar' = !(`anything') `gencond'
		di "Assert: `anything' `ifwithif' `inwithin'"
		if `existingnewvar' di "Existing variable -`newvar'- dropped"
		di "Contradicting observations identified by new variable -`newvar'-"
		if "`pause'" == "pause" {
			pause on
			pause `pausedisp'
		}
		error 9
	}

end
