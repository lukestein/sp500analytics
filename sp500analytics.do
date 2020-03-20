/*------------------------------------------------------------------------
* sp500analytics.do
*
* Edited  2020/03/20 by Luke Stein
*
*/


cd "/Users/lcdstein/Documents/Technology/Stata/S&P 500 Coronavirus/"


*----------------------------------------------------------
* Data download 
*----------------------------------------------------------

// Confirm getsymbols package
capture which getsymbols
if (_rc==111) ssc install getsymbols

getsymbols ^VIX ^GSPC ^SP500TR, yahoo fy(2015) ly(2020) frequency(d) clear
gen p = close__GSPC
gen vix = close__VIX
gen ptr = close__SP500TR

tsset daten, daily



/*
// Run code in this commented block to manually update with today's data

assert daten[_N] < date(c(current_date), "DMY")

local newobs = _N + 1
set obs `newobs'

replace daten = date(c(current_date), "DMY") in -1
replace period = daten in -1

replace p   = 2304.92 in -1
replace ptr = 4697.09 in -1
replace vix = 66.04   in -1

list daten p ptr vix in -5/-1
*/




*----------------------------------------------------------
* Data setup 
*----------------------------------------------------------

tsset

gen day = day(daten)

gen tm = mofd(daten)
format %tm tm
tostring tm, gen(tm_string) format(%tmCCYY!mNN) force

tostring daten, gen(td_string) format(%tdnn/dd/YY) force


gen lagp   = p[_n-1]
gen lagptr = ptr[_n-1]
gen lagvix = vix[_n-1]

gen r   = 100 * ((p  /  p[_n-1])-1)
gen rtr = 100 * ((ptr/ptr[_n-1])-1)




*----------------------------------------------------------
* Return distribution (20 days) 
*----------------------------------------------------------

local lastdate = td_string[_N]

global DAYS = 20
global RLIMITS = 12
qui summ rtr in -${DAYS}/-1
local arith = `r(mean)'
local geom  = 100 * (((ptr[_N] / lagptr[_N-${DAYS}+1])^(1/${DAYS})) - 1)
disp "`arith' `geom'"


graph twoway (histogram rtr in -${DAYS}/-1, dens width(1) start(-${RLIMITS}) xlab(-${RLIMITS}(1)${RLIMITS}) xline(`arith' `geom')) /// 
             (function normalden(x, 0, 75.91/sqrt(252)), range(-${RLIMITS} ${RLIMITS})), ///
  title("Last ${DAYS} days daily S&P 500 total return (%)") ///
  note("Through `lastdate'. Normal distribution has mean zero and std dev 54%/sqrt(252)." "Vertical lines show geometric and arithmetic means.") ///
  caption("Luke Stein @lukestein")

graph export "return distribution (10 days).png", replace


*----------------------------------------------------------
* S&P 500 time series 
*----------------------------------------------------------

local final = p[_N]

summ daten if p > p[_N], format
local first_date = `r(min)'

summ daten if p < p[_N], format
local last_date = `r(max)'

tsline p if tin(01jan2015,31dec2020), ///
  yline(`final') xline(`last_date') xline(`first_date') ///
  ysca(log) ytitle("") ///
  ttitle("") tlabel(,format(%tdCCYY)) ///
  note("Vertical axis shows S&P 500 Total Return Index (i.e., including dividend reinvestment) on log scale.") ///
  title("S&P 500 total return index") ///
  caption("Luke Stein @lukestein")

graph export "sp500 time series.png", replace


*----------------------------------------------------------
* VIX predicts volatility 
*----------------------------------------------------------

local lastdate = td_string[_N]

scatter rtr lagvix if (daten[_N] - daten) < 365, ///
  yline(0) ///
  ytitle("S&P 500 (daily return, %)") ///
  xtitle("VIX (previous day's close)") ///
  title("VIX vs. S&P 500 return (daily)") ///
  note("One year through `lastdate'.") ///
  caption("Luke Stein @lukestein")

graph export "vix predicts volatility.png", replace



*----------------------------------------------------------
* VIX as hedge 
*----------------------------------------------------------

local lastdate = td_string[_N]

scatter vix p if ((day <= day[_N]) & (mofd(daten) == mofd(daten[_N]))) | ((day > day[_N]) & (mofd(daten) == mofd(daten[_N]) - 1)) ///
  , connect(l) mlab(day) mlabpos(0) m(O) msize(vlarge) mcolor(white) ///
  xtitle("S&P 500") ///
  xsca(log) ///
  ytitle("VIX") ///
  title("VIX vs. S&P 500 level (daily, previous month)") ///
  note("Through `lastdate'. Label is calendar day. Horizontal axis is log scale.") ///
  caption("Luke Stein @lukestein")

graph export "vix as hedge.png", replace


*----------------------------------------------------------
* Daily return time series scatter
*----------------------------------------------------------


// summ r if (tm[_N]-tm < 12), det

local lastdate = td_string[_N]

global MONTHS "12"
global WINLIMIT "3"

//
scatter rtr daten if (tm[_N]-tm < ${MONTHS}), ///
  mlab(day) mlabsize(small) mlabpos(0) m(i) ///
  yline(-${WINLIMIT}) yline(+${WINLIMIT}) xtitle("") ytitle("") title("S&P 500 total return (daily)") xlab(,format(%tdM)) ///
  note("Through `lastdate'. Label is calendar day. Horizontal lines at ±${WINLIMIT}%.") ///
  caption("Luke Stein @lukestein")

graph export "daily return ts.png", replace


*----------------------------------------------------------
* Daily return histograms 
*----------------------------------------------------------

global MONTHS "12"
global WINLIMIT "3"

cap drop rtr_win
clonevar rtr_win = rtr
replace  rtr_win = -${WINLIMIT}.01 if rtr < -${WINLIMIT} & ~missing(rtr)
replace  rtr_win = +${WINLIMIT}.01 if rtr > +${WINLIMIT} & ~missing(rtr)

/*
//
count if (~inrange(rtr, -${WINLIMIT}, ${WINLIMIT})) & (~missing(rtr)) & (tm[_N]-tm < ${MONTHS})
local outliers = `r(N)'
local lastdate = td_string[_N]

histogram rtr_win if (tm[_N]-tm < ${MONTHS}), frac width(.5) start(-${WINLIMIT}.5) xlab(-${WINLIMIT}(1)${WINLIMIT}) ytitle("") xtitle("") by(tm_string, total ///
noiyaxes ixaxes holes(13 14 15) ///
  title("Daily S&P 500 returns (%)") ///
  note("Through `lastdate'. Extreme bars show all returns greater than ±${WINLIMIT}% (n=`outliers').") ///
  caption("Luke Stein @lukestein"))
*/

//
count if (~inrange(rtr, -${WINLIMIT}, ${WINLIMIT})) & (~missing(rtr)) & (tm[_N]-tm < ${MONTHS})
list daten r if (~inrange(rtr, -${WINLIMIT}, ${WINLIMIT})) & (~missing(rtr)) & (tm[_N]-tm < ${MONTHS})

local outliers = `r(N)'
local lastdate = td_string[_N]

graph twoway (histogram rtr_win if  inrange(rtr, -${WINLIMIT}, ${WINLIMIT}), bcolor(blue) freq width(.5) start(-${WINLIMIT}.5) xlab(-${WINLIMIT}(1)${WINLIMIT})) /// 
             (histogram rtr_win if ~inrange(rtr, -${WINLIMIT}, ${WINLIMIT}), bcolor(red)  freq width(.5) start(-${WINLIMIT}.5) xlab(-${WINLIMIT}(1)${WINLIMIT})) if (tm[_N]-tm < ${MONTHS}), ///
  ytitle("") xtitle("") by(tm_string, ///
  noiyaxes ixaxes legend(off) ///
  title("Daily S&P 500 returns (%)") ///
  note("Through `lastdate'. Red bars show all changes greater than ±${WINLIMIT}% (n=`outliers').") ///
  caption("Luke Stein @lukestein"))

graph export "daily return histograms.png", replace


*----------------------------------------------------------
* Save data 
*----------------------------------------------------------

compress
save sp500data.dta, replace
