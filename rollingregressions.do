cd "/Users/lcdstein/Documents/Technology/Stata/S&P 500 Coronavirus/"



// Confirm getsymbols package
capture which getsymbols
if (_rc==111) ssc install getsymbols

getsymbols ^VIX ^GSPC ^SP500TR, yahoo fy(1990) ly(2020) frequency(d) clear

tsset period, daily
tsset

rename close__SP500TR p
rename close__VIX     vix

gen lnp = ln(p)

compress
save sp500_and_vix_data.dta, replace



rolling r2=e(r2) r2_a=e(r2_a), window(30) saving(rolling_regs): reg vix lnp


clonevar end=period
merge 1:1 end using rolling_regs, keep(match)

label var r2 "Rolling 30-day R2"


scatter r2 period, ytitle("Rolling 30-day R2") xtitle("") title("R2 of VIX on (log) S&P Total Return") xlabel(,format(%tdCCYY)) note("Source: Draft analysis") caption("Luke Stein @lukestein") title("R2 of VIX on S&P 500 level (log Total Return Index)")


scatter r2 period if r2>.95, name(r2,      replace) ytitle("Rolling 30-day R2 (only where >0.95)") xtitle("") xlabel(,format(%tdCCYY)) nodraw
tsline vix, name(vix, replace) ytitle("VIX")      xscale(off) fysize(20) nodraw
tsline p, name(p, replace) ysca(log) ytitle("S&P 500 TR")      xscale(off) fysize(20) nodraw
graph combine vix r2, cols(1) name(combined, replace) xcommon imargin(b=1 t=1) note("Source: Draft analysis") caption("Luke Stein @lukestein") title("R2 of VIX on S&P 500 level (log Total Return Index)")


hist r2, note("Source: Draft analysis") caption("Luke Stein @lukestein") title("R2 of VIX on S&P 500 level (log Total Return Index)")

heatplot r2 vix, note("Source: Draft analysis") caption("Luke Stein @lukestein") title("R2 of VIX on S&P 500 level (log Total Return Index)")
