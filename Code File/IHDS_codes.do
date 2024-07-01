clear all
capture log close 


******************************************************
                //Term Paper

/* Created by: Richa Jha
   Purpose: To study the IHDS dataset for empirical work
   Objective: Effect of sanitisation on education and enrolment 
*/
*******************************************************


**********************************PART-I****************************************
**************************DATA CLEANING & MERGING*******************************

/**************SCHOOL-LEVEL DATASET*****************/ 

use "36151-0009-Data.dta", clear

*Studying the dataset
describe 

*Keeping relevant variables
keep STATEID DISTID PSUID SCHOOLID SO42C PS16A1 PS13A

rename SO42C T_clean
rename PS16A1 T_girls
rename PS13A classrooms


*Creating a unique key

foreach var in STATEID DISTID PSUID {
	tostring `var', replace force
	}

gen IDPSU = STATEID + DISTID + PSUID
label variable IDPSU "Unique PSU ID"

*Saving the dataset

save supplementary_data, replace


/************INDIVIDUAL-LEVEL DATASET***************/

use "36151-0001-Data.dta", clear

*Studying the dataset
describe 

foreach var in ED2 ED4 ED5 CH2 ID11 ID13 {
	tab `var'
}

*Keeping relevant variables
keep STATEID DISTID PSUID HHID RO3 RO5 ED2 ED5 ED12 ID11 ID13 INCOME NPERSONS 

rename RO3 Gender 
rename RO5 Age
rename ED2 Literacy
rename ED12 Highest_degree
rename ID11 Religion
rename ID13 Caste
rename INCOME Income
rename NPERSONS hh_size 
rename ED5 current_enrolled

*Creating a unique key

foreach var in STATEID DISTID PSUID {
	tostring `var', replace force
	}

gen IDPSU = STATEID + DISTID + PSUID
label variable IDPSU "Unique PSU ID"

*saving the dataset 
save main_data, replace

/***************MERGING DATASETS*****************/ 
use main_data, clear
merge m:m IDPSU using supplementary_data

drop if _merge != 3

save master_data, replace


*********************************PART-II****************************************
********************************ANALYSIS****************************************

*Defining the age bracket
keep  if Age >= 5 & Age <= 18

*Dividing income variable into different quintles
xtile income_quintile = Income, nquantiles(4)
label define quintiles 1 "1st Quintile" 2 "2nd Quintile" 3 "3rd Quintile" 4 "4th Quintile" 
label values income_quintile quintiles
drop Income


/***************Summary Statistics*******************/

*Gender
tabstat Literacy current_enrolled, by(Gender) statistics(mean sd)

*Income 
tabstat Literacy current_enrolled, by(income_quintile) statistics(mean sd)

*Caste
tabstat Literacy current_enrolled, by(Caste) statistics(mean sd)

*Religion
tabstat Literacy current_enrolled, by(Religion) statistics(mean sd)


*Dummy for caste variable 
gen caste = (Caste == 1 | Caste == 2)
label variable caste "Dummy variable 1 high caste 0 backward caste"
label define caste 0 "Other 0" 1 "High Caste 1"
label values caste caste

*Dummy for religion variable
gen religion = (Religion == 2)
label variable religion "Dummy for 1 muslim 0 otherwise"
label define religion 0 "Other 0" 1 "Muslim 1"
label values religion religion

*Restricting the sample geography 
destring STATEID, replace force
drop if inlist(STATEID, 01, 11, 12, 14, 15, 16, 17, 30, 32)


*Dropping the missing observations 
foreach var in current_enrolled hh_size income_quintile T_clean caste religion {
	drop if `var' == . 
	}

drop if T_clean == 9
	
*Redefining the gender variable 
recode Gender (1 = 0) (2 = 1), generate(Female)
label define Female 1 "Female 1" 0 "Male 0"
label values Female Female
drop Gender


*Redefining the separate female toilets variable 
recode T_girls (1 = 0) (2 = 1), generate(fem_toilet)
label define fem_toilet 0 "Common 0" 1 "Separate 1"
label values fem_toilet fem_toilet
label variable fem_toilet "Females have separate or common toilets"


*Interaction term for female and income quintles 
gen Q1 = (income_quintile == 1)
label variable Q1 "Dummy for first income quartile"
gen FemaleQ1 = Female * Q1
label variable FemaleQ1 "Females in first income quartile"


gen Q2 = (income_quintile == 2)
label variable Q2 "Dummy for second income quartile"
gen FemaleQ2 = Female * Q2
label variable FemaleQ2 "Females in second income quartile"

gen Q3 = (income_quintile == 3)
label variable Q3 "Dummy for Third income quartile"
gen FemaleQ3 = Female * Q3
label variable FemaleQ3 "Females in third income quartile"


*Keeping only necessary variables 
drop STATEID DISTID Religion Caste IDPSU SCHOOLID _merge Highest_degree Literacy PSUID HHID

/******Regression results for clean toilets**********/

**LPM regression**
reg current_enrolled T_clean caste religion Q1 Q2 Q3 Female FemaleQ1 FemaleQ2 FemaleQ3 hh_size, robust
est store LPM11
outreg2 using "results_table.xlsx", replace word excel ctitle(Coefficients, Standard Errors)

**LPM regression with fixed effects**
reg current_enrolled T_clean caste religion Q1 Q2 Q3 Female FemaleQ1 FemaleQ2 FemaleQ3 hh_size i.classrooms, robust
est store LPMFE1
outreg2 using "results_table.xlsx", append word excel ctitle(Coefficients, Standard Errors)


/******Regression results for separate toilets********/

*dropping missing values for common/seperate toilets for females
drop if fem_toilet == .

**LPM regression**
reg current_enrolled T_clean fem_toilet caste religion Q1 Q2 Q3 Female FemaleQ1 FemaleQ2 FemaleQ3 hh_size, robust
est store LPM21
outreg2 using "results_table.xlsx", append word excel ctitle(Coefficients, Standard Errors)



**LPM regression with fixed effects**
reg current_enrolled T_clean fem_toilet caste religion Q1 Q2 Q3  Female FemaleQ1 FemaleQ2 FemaleQ3 hh_size i.classrooms, robust
est store LPMFEF21
outreg2 using "results_table.xlsx", append word excel ctitle(Coefficients, Standard Errors)


**Probit Model**
probit current_enrolled T_clean fem_toilet caste religion Female FemaleQ1 FemaleQ2 FemaleQ3 Q1 Q2 Q3 hh_size, robust
est store probitmodel
outreg2 using "probitresults_table.xlsx", replace word excel ctitle(Coefficients, Standard Errors)



********************************END OF DO-FILE**********************************
********************************************************************************