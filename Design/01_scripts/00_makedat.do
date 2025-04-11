clear
*make dat 
set seed 081198
set obs 1000



* Set programatic variables 
gen caseid = _n
label variable caseid "Unique Identifier for Each Observation"
gen int enum_id = floor(runiform(1, 11))  // 1 to 10 i.e each should get ~100 surveys
label variable enum_id "Enumerator ID"
label define enumerator_lbl 1 "Enumerator 1" 2 "Enumerator 2" 3 "Enumerator 3" 4 "Enumerator 4" 5 "Enumerator 5" 6 "Enumerator 6" 7 "Enumerator 7" 8 "Enumerator 8" 9 "Enumerator 9" 10 "Enumerator 10"
label values enum_id enumerator_lbl

* Create start and end times so that on average interviews take an hour 
gen double base_time = clock("01jan2025 08:00:00", "DMYhms")
label variable base_time "Base Time (Fixed)"
gen double offset_msec = runiform(0, 8 * 60) * 60 * 1000  // 0–8 hours in milliseconds
gen double start_time = base_time + offset_msec
label variable start_time "Start Time of Interview"
gen double duration_sec = rnormal(3600, 600)
replace duration_sec = max(duration_sec, 300)  // Ensure minimum duration of 5 minutes
label variable duration_sec "Interview Duration in Seconds"
gen double end_time = start_time + duration_sec * 1000
label variable end_time "End Time of Interview"
format start_time end_time %tcHH:MM:SS
* Calculate actual duration in seconds (check it's correct)
gen double duration = (end_time - start_time) / 1000  // duration in seconds
label variable duration "Duration of Interview in Seconds"
sum duration

*make some fake lat longs so we can map them and see if they were in the right place 
* 13.2543° S, 34.3015° E (malawi) 
gen double lat = runiform(12, 14)  
gen double lon = runiform(33, 35)  
label variable lat "Latitude"
label variable lon "Longitude"

* Create a demo variable for gender, based on a normal distribution
gen female = (rnormal() < .52)
label variable female "Female Indicator (1 = Female, 0 = Male)"
label define female_lbl 0 "Male" 1 "Female"
label values female female_lbl

* Education (years of education)
gen yrs_educ = floor(runiform(0, 12))
label variable yrs_educ "Years of Education"
replace yrs_educ = . if rnormal() < .1
replace yrs_educ = 99 if rnormal() > .99
label define edu_lbl 99 "Refused"
label values yrs_educ edu_lbl

* Age 
gen age = rnormal(50, 15)
replace age = round(age) 
replace age = max(age, 18) if rnormal() < .2
replace age = min(age, 100)  // Ensure age is not greater than 100
label variable age "Age of Respondent"
label define age_lbl 17/100 "Age Range"
label values age age_lbl

* Economic variables
gen employed = (rnormal() < .32)
label variable employed "Employment Status (1 = Employed, 0 = Not Employed)"
label define emp_lbl 0 "Not Employed" 1 "Employed"
label values employed emp_lbl
gen hours_worked = floor(runiform(0, 55))
replace hours_worked = . if employed != 1 & runiform() > .001
label variable hours_worked "Hours Worked per Week"
gen wage = rnormal(100, 30) * 1.2 * hours_worked 
replace wage = . if runiform() < .1 | employed != 1  
label variable wage "Weekly Wage (in local currency)"
* -----------------------------------
* Frequency Check: Enumerator ID
* -----------------------------------
tabulate enum_id, missing
graph bar (count), over(enum_id, sort(1) descending label(angle(45))) ///
    title("Number of Interviews per Enumerator") ///
    ytitle("Number of Interviews")

* -----------------------------------
* Frequency Check: Start Hour
* -----------------------------------
gen hour_start = hh(start_time)
tabulate hour_start, missing
graph bar (count), over(hour_start, sort(1)) ///
    title("Start Time Distribution (by Hour)") ///
    ytitle("Interview Count")

* -----------------------------------
* Frequency Check: End Hour
* -----------------------------------
gen hour_end = hh(end_time)
tabulate hour_end, missing
graph bar (count), over(hour_end, sort(1)) ///
    title("End Time Distribution (by Hour)") ///
    ytitle("Interview Count")

* -----------------------------------
* Frequency Check: Duration Groups
* -----------------------------------
gen duration_group = .
replace duration_group = 1 if duration_sec < 2000
replace duration_group = 2 if duration_sec >= 2000 & duration_sec < 3000
replace duration_group = 3 if duration_sec >= 3000 & duration_sec < 4000
replace duration_group = 4 if duration_sec >= 4000
label define duration_grp_lbl 1 "Under 2000s" 2 "2000–2999s" 3 "3000–3999s" 4 "4000s and above"
label values duration_group duration_grp_lbl
tabulate duration_group, missing

graph bar (count), over(duration_group, label(angle(45))) ///
    title("Interview Duration Distribution") ///
    ytitle("Number of Interviews")


* Convert start_time and end_time to Stata time format if not already
format start_time %tc
format end_time %tc

* Calculate actual survey duration from timestamps (in seconds)
gen actual_duration_sec = (end_time - start_time) / 1000

* Compare with recorded duration_sec
gen duration_diff = duration_sec - actual_duration_sec

* Summary statistics to check the discrepancies
summarize duration_sec actual_duration_sec duration_diff

* Flag entries with major mismatches (optional)
gen large_mismatch = abs(duration_diff) > 5  // flag if >5 seconds difference

* List examples with mismatches (optional)
list caseid enum_id start_time end_time duration_sec actual_duration_sec duration_diff ///
     if large_mismatch == 1, sepby(enum_id)

* Visualize difference (optional)
histogram duration_diff, bin(50) normal ///
    title("Difference between Recorded and Actual Duration (in seconds)")

