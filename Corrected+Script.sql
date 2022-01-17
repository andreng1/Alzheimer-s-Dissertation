--Author: Chor Him Ng (Andre) --Create Date: 06/08/2021
--Project ID: SAIL1074V
--Title: Predicing diagnosis of Alzheimer's disease with supervised machine learning models

--Part 1: Extracting necessary data

--P1.1 Cut down original datasets by number of columns
--Deaths Data (ADDE)
CREATE TABLE SAILW1074V.ADDE_DEATHS_CUTDOWN AS (
	SELECT ALF_PE,
		   DEATH_DT,
		   DEATH_DT_VALID,
		   DEC_SEX_CD,
		   DEATH_HEALTH_ORG_CD,
		   DEC_AGE 
	FROM SAIL1074V.ADDE_DEATHS_20200628 ad
	ORDER BY ALF_PE) WITH DATA;

--Hospital Data (PEDW)
--Diagnosis table
CREATE TABLE SAILW1074V.PEDW_DIAG_CUTDOWN AS(
	SELECT PROV_UNIT_CD,
		   SPELL_NUM_PE,
		   EPI_NUM,
		   DIAG_NUM,
		   DIAG_CD	
	FROM SAIL1074V.PEDW_DIAG_20200628 pd 
	ORDER BY PROV_UNIT_CD, SPELL_NUM_PE, EPI_NUM) WITH DATA;

--Episode table
CREATE TABLE SAILW1074V.PEDW_EPISODE_CUTDOWN AS(
	SELECT PROV_UNIT_CD,
		   SPELL_NUM_PE,
		   EPI_NUM,
		   EPI_STR_DT,
		   EPI_END_DT,
		   AGE_EPI_STR_YR,
		   DIAG_CD_1234,
		   OPER_CD	
	FROM SAIL1074V.PEDW_EPISODE_20200628 pe 
	ORDER BY PROV_UNIT_CD, SPELL_NUM_PE, EPI_NUM) WITH DATA;


--Spell table
CREATE TABLE SAILW1074V.PEDW_SPELL_CUTDOWN AS(
	SELECT PROV_UNIT_CD,
		   SPELL_NUM_PE,
		   ALF_PE,
		   GNDR_CD,
		   RES_DHA_CD,
		   ADMIS_DT,
		   ADMIS_MTHD_CD,
		   DISCH_DT,
		   DISCH_MTHD_CD,
		   DISCH_DESTINATION_CD,
		   ADMIS_SPEC_CD,
		   DISCH_SPEC_CD	
	FROM SAIL1074V.PEDW_SPELL_20200628 ps 
	ORDER BY PROV_UNIT_CD, SPELL_NUM_PE, ALF_PE) WITH DATA;


--Demographics Data (WDSD)
--Demographics administration registry - personal/individual attributes
CREATE TABLE SAILW1074V.WDSD_AR_PERS_CUTDOWN AS(
	SELECT ALF_PE,
		   PERS_ID_PE,
		   WOB,
		   DOD,
		   GNDR_CD	
	FROM SAIL1074V.WDSD_AR_PERS_20200705 wap 
	ORDER BY ALF_PE, PERS_ID_PE	) WITH DATA;

--Demographics address/geographic/char LSOA2011 (Cleaned)
CREATE TABLE SAILW1074V.WDSD_LSOA2011_CUTDOWN AS(
	SELECT ALF_PE,
		   START_DATE,
		   END_DATE,
		   WIMD_2014_QUINTILE
	FROM SAIL1074V.WDSD_CLEAN_ADD_GEOG_CHAR_LSOA2011_20200705 wcagcl 
	ORDER BY ALF_PE, START_DATE) WITH DATA;


--GP Data (WLGP)
--GP registry - median (cleaned)
CREATE TABLE SAILW1074V.WLGP_REG_MEDIAN_CUTDOWN AS(
	SELECT ALF_PE,
		   START_DATE,
		   END_DATE
	FROM SAIL1074V.WLGP_CLEAN_GP_REG_MEDIAN_20200401 wcgrm 
	ORDER BY ALF_PE, START_DATE) WITH DATA;


--IGNORE BELOW - GP ALF event table is too big to cutdown (use up too much I/O usage)
--GP event data - ALF (cleaned)
--CREATE TABLE SAILW1074V.WLGP_EVENT_ALF_CUTDOWN AS(
--	SELECT ALF_PE,
--		   PRAC_CD_PE,
--		   LOCAL_NUM_PE,
--		   GNDR_CD,
--		   WOB,
--		   REG_CAT_CD,
--		   EVENT_DT,
--		   EVENT_CD_VRS,
--		   EVENT_CD,
--		   EVENT_VAL,
--		   EPISODE,
--		   "SEQUENCE"	
--	FROM SAIL1074V.WLGP_GP_EVENT_ALF_CLEANSED_20200401 wgeac 
--	ORDER BY ALF_PE, PRAC_CD_PE, LOCAL_NUM_PE) WITH DATA;


--GP patient data - ALF (cleaned)
CREATE TABLE SAILW1074V.WLGP_PATIENT_ALF_CUTDOWN AS(
	SELECT ALF_PE,
		   PRAC_CD_PE,
		   LOCAL_NUM_PE,
		   OPT_OUT_FLG
	FROM SAIL1074V.WLGP_PATIENT_ALF_CLEANSED_20200401 wpac 
	ORDER BY ALF_PE, PRAC_CD_PE, LOCAL_NUM_PE) WITH DATA;


------------------------------------
--Part 2: Data Pre-processing - Checking & filtering data

--P2.1 Deaths data
--Check if there are any rows of ALF_PE that are NULL 
SELECT COUNT(*) FROM SAILW1074V.ADDE_DEATHS_CUTDOWN adc
	WHERE adc.ALF_PE IS NULL;
--Result: 35542 rows with ALF_PE null (out of 804430 total rows) 
--Check if any of the null rows are invalid
SELECT COUNT(*) FROM SAILW1074V.ADDE_DEATHS_CUTDOWN adc
	WHERE adc.ALF_PE IS NULL
	AND DEATH_DT_VALID = 'Invalid';
--Result: zero
--Remove NULL values from ALF_PE
DELETE FROM SAILW1074V.ADDE_DEATHS_CUTDOWN adc
	WHERE adc.ALF_PE IS NULL;
--Leaving with 768888 ALF_PEs with death dates

--Checking other columns with NULL rows
--Checking for death dates that are NULL 
SELECT * FROM SAILW1074V.ADDE_DEATHS_CUTDOWN adc
	WHERE adc.DEATH_DT IS NULL
	ORDER BY ALF_PE;
--Result: 14 rows
SELECT * FROM SAILW1074V.ADDE_DEATHS_CUTDOWN adc
	WHERE adc.DEATH_DT_VALID =  'Invalid'
	ORDER BY ALF_PE;
--Turns out these are the same 14 ALF_PE with invalid death records
SELECT * FROM SAILW1074V.ADDE_DEATHS_CUTDOWN adc
	WHERE adc.DEATH_DT_VALID =  'Invalid' AND
		  adc.DEATH_DT IS NULL;
--Delete these 14 invalid records
DELETE FROM SAILW1074V.ADDE_DEATHS_CUTDOWN adc
	WHERE adc.DEATH_DT_VALID = 'Invalid' OR
		  adc.DEATH_DT IS NULL;

--Check for other columns with NULL
SELECT * FROM SAILW1074V.ADDE_DEATHS_CUTDOWN adc
	WHERE adc.DEATH_DT_VALID IS NULL;
--none
SELECT * FROM SAILW1074V.ADDE_DEATHS_CUTDOWN adc
	WHERE adc.DEC_AGE IS NULL;
--none
SELECT COUNT(*) FROM SAILW1074V.ADDE_DEATHS_CUTDOWN adc
	WHERE adc.DEATH_HEALTH_ORG_CD IS NULL;
--144107 rows (out of 804430 total rows) 
--(Will NOT remove rows due to missing health org code)
--can be imputed but not necessary

--Check if any ALF_PE has both a valid and invalid death date
SELECT ALF_PE, COUNT(DISTINCT DEATH_DT_VALID) AS DISTDTHVA 
FROM SAILW1074V.ADDE_DEATHS_CUTDOWN adc
GROUP BY ALF_PE
ORDER BY DISTDTHVA DESC;
--All rows should return with 1
--Result: None

--Check if there are duplicates of ALF_PE
SELECT ALF_PE, COUNT(DISTINCT ALF_PE) AS DISTALF 
FROM SAILW1074V.ADDE_DEATHS_CUTDOWN adc
GROUP BY ALF_PE
ORDER BY DISTALF DESC;
--All rows should return with 1
--Result: No duplicate ALF_PE

--After cleansing left the dataset with 768874 ALF_PEs/rows
SELECT COUNT(*) FROM SAILW1074V.ADDE_DEATHS_CUTDOWN adc;

--Checking for impossible death dates (as of the day of analysis August 2021)
SELECT * FROM SAILW1074V.ADDE_DEATHS_CUTDOWN 
	WHERE YEAR(DEATH_DT) > 2022 OR
		  YEAR(DEATH_DT) < 1880;
--Result: none

--Checking for impossible age
SELECT * FROM SAILW1074V.ADDE_DEATHS_CUTDOWN 
	WHERE DEC_AGE < 0 OR
		  DEC_AGE > 120;
--Result: none

--Checking for impossible DEC_SEX_CD 
SELECT * FROM SAILW1074V.ADDE_DEATHS_CUTDOWN 
	WHERE DEC_SEX_CD > 2 OR
		  DEC_SEX_CD < 1;
--Result: none


--P2.2 Demographics data
--Note: In WDSD_AR_PERS_CUTDOWN, each row has a unique ALF_PE
--Whereas in WDSD_LSOA2011_CUTDOWN each ALF_PE can have multiple rows
--Note: END_DATES can be null or forever (9999-01-01) because someone may not have moved

--WDSD_AR_PERS_CUTDOWN datatset
--Checking there is no duplicate ALF_PE and PERS_ID_PE
SELECT COUNT(*) FROM SAILW1074V.WDSD_AR_PERS_CUTDOWN wapc;
SELECT COUNT(DISTINCT ALF_PE) FROM SAILW1074V.WDSD_AR_PERS_CUTDOWN wapc;
SELECT COUNT(DISTINCT PERS_ID_PE) FROM SAILW1074V.WDSD_AR_PERS_CUTDOWN wapc;
--no duplicates

--Checking null values in each column
SELECT * FROM SAILW1074V.WDSD_AR_PERS_CUTDOWN wapc 
	WHERE ALF_PE IS NULL;
SELECT * FROM SAILW1074V.WDSD_AR_PERS_CUTDOWN wapc 
	WHERE PERS_ID_PE IS NULL;
SELECT * FROM SAILW1074V.WDSD_AR_PERS_CUTDOWN wapc 
	WHERE WOB IS NULL;
SELECT * FROM SAILW1074V.WDSD_AR_PERS_CUTDOWN wapc 
	WHERE GNDR_CD IS NULL;
--Result (from all above columns): none

--Checking WOB is always before DOD
SELECT * FROM SAILW1074V.WDSD_AR_PERS_CUTDOWN wapc
	WHERE YEAR(WOB) > YEAR(DOD);
--Result: none
--Checking gender code is either 1 or 2
SELECT * FROM SAILW1074V.WDSD_AR_PERS_CUTDOWN wapc
	WHERE GNDR_CD > 2;
--Result: 28 records with GNDR_CD '8'
--Deleting these records as it is only a handful
DELETE FROM SAILW1074V.WDSD_AR_PERS_CUTDOWN wapc
	WHERE GNDR_CD > 2;

--Checking for impossible dates
SELECT * FROM SAILW1074V.WDSD_AR_PERS_CUTDOWN wapc 
	WHERE YEAR(WOB) > 2022 OR
		  YEAR(WOB) < 1870 OR
		  YEAR(DOD) > 2022 OR
		  YEAR(DOD) < 1870;
--Result: none

--Check for impossible gender codes
SELECT * FROM SAILW1074V.WDSD_AR_PERS_CUTDOWN wapc 
	WHERE GNDR_CD > 2 OR
		  GNDR_CD < 1;
--Result: none
		 
--WDSD_LSOA2011_CUTDOWN dataset
--Checking number of unique ALF_PEs
SELECT COUNT(*) FROM WDSD_LSOA2011_CUTDOWN wlc2; --11780909 rows
SELECT COUNT(DISTINCT ALF_PE) FROM WDSD_LSOA2011_CUTDOWN wlc2; --5286155 unique ALF_PE

--Checking end date is always after start date
SELECT * FROM SAILW1074V.WDSD_LSOA2011_CUTDOWN wlc 
	WHERE START_DATE > END_DATE;

--Check for impossible START dates
SELECT COUNT(*) FROM SAILW1074V.WDSD_LSOA2011_CUTDOWN wlc 
	WHERE YEAR(START_DATE ) > 2022 OR
		  YEAR(START_DATE ) < 1870;

--Checking null values in each column
SELECT COUNT(DISTINCT ALF_PE) FROM SAILW1074V.WDSD_LSOA2011_CUTDOWN wlc
	WHERE START_DATE IS NULL;
SELECT COUNT(DISTINCT ALF_PE) FROM SAILW1074V.WDSD_LSOA2011_CUTDOWN wlc
	WHERE END_DATE IS NULL;
SELECT COUNT(DISTINCT ALF_PE) FROM SAILW1074V.WDSD_LSOA2011_CUTDOWN wlc
	WHERE WIMD_2014_QUINTILE IS NULL;
--Result (from all three columns): none

--Checking WIMD is always between 1 to 5
SELECT * FROM SAILW1074V.WDSD_LSOA2011_CUTDOWN wlc
	WHERE WIMD_2014_QUINTILE > 5 OR
		  WIMD_2014_QUINTILE < 1;
--Result: none

--Checking if the same person had moved, the area code END_DATE of the
--earlier address is before or same as the next START_DATE
WITH temp2 AS(
SELECT *, 
	LAG(ALF_PE, 1) OVER(ORDER BY ALF_PE, START_DATE) AS LAST_ALF,
	LAG(END_DATE, 1) OVER(ORDER BY ALF_PE, START_DATE) AS LAST_END_DT
FROM SAILW1074V.WDSD_LSOA2011_CUTDOWN wlc)
SELECT * FROM temp2
	WHERE ALF_PE = LAST_ALF AND
		  START_DATE <= LAST_END_DT;
--Result: none

--This leaves..		 
SELECT COUNT(*) FROM SAILW1074V.WDSD_LSOA2011_CUTDOWN wlc; --11780909 rows
SELECT COUNT(*) FROM SAILW1074V.WDSD_AR_PERS_CUTDOWN wapc; --547609 rows


--P2.3 Hospital datasets
--Notes:
--1) Hospital datasets are too large to join
--2) pdc.DIAG_CD is not the same as pec.DIAG_CD_1234. 
--3) For the same SPELL_NUM_PE, each episode (EPI_NUM) can have multiple diagnosis,
--and each diagnosis (DIAG_NUM) can have multiple DIAG_CD
--(eg. one diagnosis (DIAG_NUM) give 4 codes(DIAG_CD), therefore giving 4 rows)


--PEDW_DIAG_CUTDOWN dataset
SELECT * FROM SAILW1074V.PEDW_DIAG_CUTDOWN pdc 
ORDER BY PROV_UNIT_CD, SPELL_NUM_PE, EPI_NUM, DIAG_NUM;

--Check for NULL values in each column
SELECT * FROM SAILW1074V.PEDW_DIAG_CUTDOWN pdc 
WHERE PROV_UNIT_CD IS NULL;
--Result: none
SELECT * FROM SAILW1074V.PEDW_DIAG_CUTDOWN pdc 
WHERE SPELL_NUM_PE IS NULL;
--Result: 2 rows
SELECT * FROM SAILW1074V.PEDW_DIAG_CUTDOWN pdc 
WHERE EPI_NUM IS NULL;
--Result: none
SELECT * FROM SAILW1074V.PEDW_DIAG_CUTDOWN pdc 
WHERE DIAG_NUM IS NULL;
--Result: none
SELECT * FROM SAILW1074V.PEDW_DIAG_CUTDOWN pdc 
WHERE DIAG_CD IS NULL;
--Result: none
--Delete the null rows
DELETE FROM SAILW1074V.PEDW_DIAG_CUTDOWN pdc 
	WHERE SPELL_NUM_PE IS NULL;
--Check again
SELECT * FROM SAILW1074V.PEDW_DIAG_CUTDOWN pdc 
WHERE SPELL_NUM_PE IS NULL;

--Check for impossible EPI_NUM or DIAG_NUM
SELECT * FROM SAILW1074V.PEDW_DIAG_CUTDOWN pdc
	WHERE EPI_NUM < 1 OR
	      EPI_NUM > 150 OR
	      DIAG_NUM < 1 OR
	      DIAG_NUM > 150;
--Result: none

--Check for duplicates in DIAG_NUM per EPI_NUM, SPELL_NUM_PE AND
--PROV_UNIT_CD
--Note: Each episode (EPI_NUM) have a maximum of 14 diagnosis)
WITH temp3 AS(
SELECT PROV_UNIT_CD,
	   SPELL_NUM_PE,
	   EPI_NUM,
	   COUNT(DISTINCT DIAG_NUM) AS distinct_num, 
	   --shows number of unique DIAG_NUM within each EPI_NUM, SPELL_NUM_PE AND PROV_UNIT_CD
	   COUNT(DIAG_NUM) AS num
   	   --shows total number of DIAG_NUM within each EPI_NUM, SPELL_NUM_PE AND PROV_UNIT_CD
FROM SAILW1074V.PEDW_DIAG_CUTDOWN pdc
GROUP BY PROV_UNIT_CD,
		 SPELL_NUM_PE,
		 EPI_NUM
ORDER BY distinct_num DESC)
SELECT * FROM temp3
	WHERE num <> distinct_num
	--If DIAG_NUM is unique then it should not return anything;
--Result: none

--Check for duplicates in DIAG_CD per EPI_NUM, SPELL_NUM_PE and PROV_UNIT_CD
WITH temp4 AS(
SELECT PROV_UNIT_CD,
	   SPELL_NUM_PE,
	   EPI_NUM,
	   COUNT(DISTINCT DIAG_CD) AS distinct_num, 
	   --shows number of unique DIAG_NUM within each EPI_NUM, SPELL_NUM_PE AND PROV_UNIT_CD
	   COUNT(DIAG_CD) AS num
   	   --shows total number of DIAG_NUM within each EPI_NUM, SPELL_NUM_PE AND PROV_UNIT_CD
FROM SAILW1074V.PEDW_DIAG_CUTDOWN pdc
GROUP BY PROV_UNIT_CD,
		 SPELL_NUM_PE,
		 EPI_NUM
ORDER BY distinct_num DESC)
SELECT COUNT(*) FROM temp4
	WHERE num <> distinct_num;
--280954 rows (out of 90415472) with duplicate diagnosis code within the EPI_NUM, 
--SPELL_NUM_PE and PROV_UNIT_CD (Not going to remove because unlikely to affect study
--and mutliple instances of the same condition can happen within the same episode 
--(eg.a cut))


--PEDW_EPISODE_CUTDOWN dataset
--Note: 
--1) Each PROV_UNIT_CD can have multiple rows of thee same SPELL_NUM_PE
--2) When PROV_UNIT_CD, SPELL_NUM_PE, EPI_NUM combines they beome a composite primary key
--(aka there are no duplicates)
SELECT COUNT(*) FROM SAILW1074V.PEDW_EPISODE_CUTDOWN pec; --25735477 rows

--Checking for rows with episode end date earlier than start date
SELECT COUNT(*) FROM SAILW1074V.PEDW_EPISODE_CUTDOWN pec 
	WHERE EPI_END_DT < EPI_STR_DT;
--Result: 945 rows
--Delete these rows
DELETE FROM SAILW1074V.PEDW_EPISODE_CUTDOWN pec 
	WHERE EPI_END_DT < EPI_STR_DT;

--Check for impossible dates and EPI_NUM
SELECT * FROM SAILW1074V.PEDW_EPISODE_CUTDOWN pec 
	WHERE EPI_NUM < 1 OR
		  EPI_NUM > 150 OR
		  YEAR(EPI_STR_DT) < 1870 OR
		  YEAR(EPI_STR_DT) > 2022 OR
		  YEAR(EPI_END_DT) < 1870 OR
		  YEAR(EPI_END_DT) > 2022;
--Result: 24 rows with EPI_END_DT 2999-12-31
--Delete these rows
DELETE FROM SAILW1074V.PEDW_EPISODE_CUTDOWN pec 
	WHERE YEAR(EPI_END_DT) > 2022;

--Check for impossible age
SELECT * FROM SAILW1074V.PEDW_EPISODE_CUTDOWN pec 
	WHERE AGE_EPI_STR_YR < 0 OR
		  AGE_EPI_STR_YR > 120;
--Result: 357 rows
--Delete these rows
DELETE FROM SAILW1074V.PEDW_EPISODE_CUTDOWN pec 
	WHERE AGE_EPI_STR_YR < 0 OR
		  AGE_EPI_STR_YR > 120;

--Check the EPI_STR_DT of the later episode is after the EPI_END_DT of the earlier episode
WITH temp5 AS(
	SELECT *, 
		LEAD(PROV_UNIT_CD, 1) OVER(ORDER BY PROV_UNIT_CD, SPELL_NUM_PE, EPI_NUM) AS NEXT_PROV,
		LEAD(SPELL_NUM_PE, 1) OVER(ORDER BY PROV_UNIT_CD, SPELL_NUM_PE, EPI_NUM) AS NEXT_SPELL,
		LEAD(EPI_NUM, 1) OVER(ORDER BY PROV_UNIT_CD, SPELL_NUM_PE, EPI_NUM) AS NEXT_EPI,
		LEAD(EPI_STR_DT, 1) OVER(ORDER BY PROV_UNIT_CD, SPELL_NUM_PE, EPI_NUM) AS NEXT_STR_DT
	FROM SAILW1074V.PEDW_EPISODE_CUTDOWN pec
	ORDER BY PROV_UNIT_CD, SPELL_NUM_PE, EPI_NUM, EPI_STR_DT)	
SELECT COUNT(*) FROM temp5
	WHERE PROV_UNIT_CD = NEXT_PROV AND
		  SPELL_NUM_PE = NEXT_SPELL AND
		  NEXT_EPI > EPI_NUM AND
		  NEXT_STR_DT < EPI_END_DT;
--Result: 9294 rows
--Unlikely to affect study therefore these rows are ignored


--Check for NULL values in each column
SELECT * FROM SAILW1074V.PEDW_EPISODE_CUTDOWN pec 
	WHERE PROV_UNIT_CD IS NULL;
--Result: none
SELECT * FROM SAILW1074V.PEDW_EPISODE_CUTDOWN pec
	WHERE SPELL_NUM_PE IS NULL;
--Result: 1 row
SELECT * FROM SAILW1074V.PEDW_EPISODE_CUTDOWN pec
	WHERE EPI_NUM IS NULL;
--Result: none
SELECT COUNT(*) FROM SAILW1074V.PEDW_EPISODE_CUTDOWN pec
	WHERE EPI_STR_DT IS NULL;
--Result: 573 rows
SELECT COUNT(*) FROM SAILW1074V.PEDW_EPISODE_CUTDOWN pec
	WHERE EPI_END_DT IS NULL;
--Result: none
SELECT COUNT(*) FROM SAILW1074V.PEDW_EPISODE_CUTDOWN pec
	WHERE AGE_EPI_STR_YR IS NULL;
--Result: 3617 rows (Will not remove due to having to control features)
SELECT COUNT(*) FROM SAILW1074V.PEDW_EPISODE_CUTDOWN pec
	WHERE DIAG_CD_1234 IS NULL AND 
		  OPER_CD IS NULL;
--Result: 782230 rows
DELETE FROM SAILW1074V.PEDW_EPISODE_CUTDOWN pec
	WHERE SPELL_NUM_PE IS NULL OR
		  EPI_STR_DT IS NULL OR
		  (DIAG_CD_1234 IS NULL AND 
		  OPER_CD IS NULL);
		 
 
--PEDW_SPELL_CUTDOWN dataset
SELECT COUNT(*) FROM SAILW1074V.PEDW_SPELL_CUTDOWN psc; --22689204 rows
SELECT COUNT(DISTINCT ALF_PE) FROM SAILW1074V.PEDW_SPELL_CUTDOWN psc --3495127 unique ALF_PEs

--Check for null values in all columns
SELECT COUNT(*) FROM SAILW1074V.PEDW_SPELL_CUTDOWN psc
	WHERE PROV_UNIT_CD IS NULL;
--Result: none
SELECT COUNT(*) FROM SAILW1074V.PEDW_SPELL_CUTDOWN psc
	WHERE SPELL_NUM_PE IS NULL;
--Result: 1 row
SELECT COUNT(*) FROM SAILW1074V.PEDW_SPELL_CUTDOWN psc
	WHERE ALF_PE IS NULL;
--Result: 1042413
SELECT COUNT(*) FROM SAILW1074V.PEDW_SPELL_CUTDOWN psc
	WHERE GNDR_CD IS NULL;
--Result: 611
SELECT COUNT(*) FROM SAILW1074V.PEDW_SPELL_CUTDOWN psc
	WHERE RES_DHA_CD IS NULL;
--Result: 32201
SELECT COUNT(*) FROM SAILW1074V.PEDW_SPELL_CUTDOWN psc
	WHERE ADMIS_DT IS NULL;
--Result: 72
SELECT COUNT(*) FROM SAILW1074V.PEDW_SPELL_CUTDOWN psc
	WHERE ADMIS_MTHD_CD IS NULL;
--Result: 913
SELECT COUNT(*) FROM SAILW1074V.PEDW_SPELL_CUTDOWN psc
	WHERE DISCH_DT IS NULL;
--Result: 21343
SELECT COUNT(*) FROM SAILW1074V.PEDW_SPELL_CUTDOWN psc
	WHERE DISCH_MTHD_CD IS NULL;
--Result: none
SELECT COUNT(*) FROM SAILW1074V.PEDW_SPELL_CUTDOWN psc
	WHERE DISCH_DESTINATION_CD IS NULL;
--Result: 30548
SELECT COUNT(*) FROM SAILW1074V.PEDW_SPELL_CUTDOWN psc
	WHERE ADMIS_SPEC_CD IS NULL;
--Result: none
SELECT COUNT(*) FROM SAILW1074V.PEDW_SPELL_CUTDOWN psc
	WHERE DISCH_SPEC_CD IS NULL;
--Result: none
--Delete the rows if SPELL_NUM_PE or ALF_PE are null
DELETE FROM SAILW1074V.PEDW_SPELL_CUTDOWN psc
	WHERE SPELL_NUM_PE IS NULL OR
		  ALF_PE IS NULL;

--Check GNDR_CD remains the same for each ALF_PE
--Note: The results show only 6 records, meaning GNDR_CD is likely to be
--biological genders at birth
WITH temp8 AS(
SELECT *, 
	LAG(ALF_PE, 1) OVER (ORDER BY PROV_UNIT_CD, SPELL_NUM_PE, ALF_PE, ADMIS_DT) AS LAG_ALF,
	LAG(GNDR_CD, 1) OVER (ORDER BY PROV_UNIT_CD, SPELL_NUM_PE, ALF_PE, ADMIS_DT) AS LAG_GNDR 
FROM SAILW1074V.PEDW_SPELL_CUTDOWN psc)
SELECT * FROM temp8
WHERE ALF_PE = LAG_ALF AND 
	  GNDR_CD <> LAG_GNDR;
--Result: REMOVED FOR FILE-OUT REQUEST

--CODE & COMMENTS REMOVED DUE TO CONTAINING PERSONAL IDENTIFIERS
--(due to privacy concerns for file-out requests)

--Check number of rows with GNDR_CD not '1' or '2'
--Note: GNDR_CD '9' is unknown
SELECT COUNT(*) FROM SAILW1074V.PEDW_SPELL_CUTDOWN psc
	WHERE GNDR_CD > '2' OR 
		  GNDR_CD < '1'; --2186 rows
--Set all these rows to NULL
UPDATE SAILW1074V.PEDW_SPELL_CUTDOWN psc
SET GNDR_CD = NULL
WHERE GNDR_CD > '2' OR 
	  GNDR_CD < '1';

SELECT COUNT(*) FROM SAILW1074V.PEDW_SPELL_CUTDOWN psc
	WHERE GNDR_CD IS NULL;
--There are now 2534 rows with NULL GNDR_CD
--Ignoring the null gender codes as it is not important

--Checking for rows where discharge date is before adminstering date
SELECT * FROM SAILW1074V.PEDW_SPELL_CUTDOWN psc 
	WHERE ADMIS_DT > DISCH_DT;
--Results: 133 rows
--Delete these rows
DELETE FROM SAILW1074V.PEDW_SPELL_CUTDOWN psc
	WHERE ADMIS_DT > DISCH_DT;

--Checking for impossible dates
SELECT * FROM SAILW1074V.PEDW_SPELL_CUTDOWN psc 
	WHERE YEAR(ADMIS_DT) > 2022 OR
		  YEAR(ADMIS_DT) < 1880 OR
		  YEAR(DISCH_DT) > 2022 OR
		  YEAR(DISCH_DT) < 1880;
--Result: 9 rows
--Delete these rows
DELETE FROM SAILW1074V.PEDW_SPELL_CUTDOWN psc 
	WHERE YEAR(ADMIS_DT) > 2022 OR
		  YEAR(ADMIS_DT) < 1880 OR
		  YEAR(DISCH_DT) > 2022 OR
		  YEAR(DISCH_DT) < 1880;


--P2.4 GP Data
--Note: WLGP_EVENT_ALF_CLEANSED_20200401 will be the primary GP dataset used (NOT WLGP_EVENT)
--IMPORTANT NOTE: WLGP_EVENT_ALF_CLEANSED_20200401 will be cleaned in the defining
--cases and defining controls section instead as it is too large
		 
--WLGP_REG_MEDIAN_CUTDOWN dataset
--Note: There are duplicate ALF_PEs (Multiple GP registers per person)
--Check for null ALF_PE
SELECT COUNT(*) FROM SAILW1074V.WLGP_REG_MEDIAN_CUTDOWN wrmc
	WHERE ALF_PE IS NULL;
--Result: none
--Check for null dates
SELECT COUNT(*) FROM SAILW1074V.WLGP_REG_MEDIAN_CUTDOWN wrmc
	WHERE START_DATE IS NULL OR
		  END_DATE IS NULL;
--Result: none

--Check for impossible dates
--Check for null ALF_PE
SELECT COUNT(*) FROM SAILW1074V.WLGP_REG_MEDIAN_CUTDOWN wrmc
	WHERE YEAR(START_DATE) > 2022 OR
		  YEAR(START_DATE) < 1980 OR
		  YEAR(END_DATE) > 2022 OR
		  YEAR(END_DATE) < 1980 ;
--Result: none

--Check for start dates always before end date
SELECT COUNT(*) FROM SAILW1074V.WLGP_REG_MEDIAN_CUTDOWN wrmc
	WHERE START_DATE > END_DATE;
--Result: none


--WLGP_PATIENT_ALF_CUTDOWN Dataset
--Filter out only the ALF_PEs that have OPT_OUT_FLG AS 'Y'
DELETE FROM SAILW1074V.WLGP_PATIENT_ALF_CUTDOWN wpac
	WHERE OPT_OUT_FLG IS NULL;
--Check the dataset
SELECT COUNT(*) FROM SAILW1074V.WLGP_PATIENT_ALF_CUTDOWN wpac
	WHERE OPT_OUT_FLG IS NOT NULL;
--75 rows

--Check for null ALF_PE
SELECT COUNT(*) FROM SAILW1074V.WLGP_PATIENT_ALF_CUTDOWN wpac 
	WHERE ALF_PE IS NULL;
--Delete these rows
DELETE FROM SAILW1074V.WLGP_PATIENT_ALF_CUTDOWN wpac 
	WHERE ALF_PE IS NULL;

--Check for duplicates
SELECT COUNT(*) FROM SAILW1074V.WLGP_PATIENT_ALF_CUTDOWN wpac; --73 rows
SELECT COUNT(DISTINCT ALF_PE) FROM SAILW1074V.WLGP_PATIENT_ALF_CUTDOWN wpac; --69 unique ALF_PEs
--Delete the duplicates:
--1st) Look at the four repeating ALF_PEs
SELECT *, 
	   ROW_NUMBER() OVER (PARTITION BY ALF_PE
	   					  ORDER BY ALF_PE, PRAC_CD_PE, LOCAL_NUM_PE)
	   morbseq
	   --create morbseq
FROM SAILW1074V.WLGP_PATIENT_ALF_CUTDOWN wpac
ORDER BY morbseq DESC;
--2nd) Delete the AlF_PEs

--CODE & COMMENTS REMOVED DUE TO CONTAINING PERSONAL IDENTIFIERS
--(due to privacy concerns for file-out requests)

--This leaves 69 distinct ALF_PEs that wants to be opted out from the study


------------------------------------
--Part 3: Define cases
--Note: There are two groups of datasets that can give cases: 
--WLGP_GP_EVENT_ALF_CLEANSED with its additonal GP data, and the PEDW datasets
--The tables will need to be joined(eg. the three hospital datasets, the GP datasets)
--Once the two groups of datasets are cleaned and joined into two tables,
--the two tables will join by ALF_PE to remove duplicates.
--The joined table will then be used as a full list of Alzheimer's patients within the 
--domain and time restrictions.
--Another table will be created in part 4 for feature selection.		 

		 
--P3.1 Extract the read codes (V2) and ICD 10 codes from SAILREFRV that mentions alzheimer's
--Create a table that includes the READ CODES for Alzheimer's (cases)
CREATE TABLE SAILW1074V.AZ_READ_CODES AS (
SELECT * FROM SAILREFRV.READ_CD rc 
	WHERE READ_DESC LIKE '%lzheimer%'
	ORDER BY READ_CD) WITH DATA;

--There are AZ read codes that are unrelated or not for my targeted question on AZ only
--(13Y7. - Alzheimer's society member AND Eu002 - Dementia in Alzheimer's dis, atypical 
--or mixed type)
--Remove these rows
DELETE FROM SAILW1074V.AZ_READ_CODES
	WHERE READ_CD = '13Y7.' OR
	      READ_CD = 'Eu002';

--Create a table that includes the ICD10 CODES for Alzheimer's (cases)
CREATE TABLE SAILW1074V.AZ_ICD10_CODES AS (
SELECT * FROM SAILREFRV.ICD10_DIAG_CD idc  
	WHERE DIAG_DESC_3 LIKE '%lzheimer%'
	ORDER BY DIAG_CD) WITH DATA;

--Again, there are AZ ICD10 codes that are unrelated or not for my targeted question on AZ only
DELETE FROM SAILW1074V.AZ_ICD10_CODES
	WHERE DIAG_CD = 'F002'; --Dementia in Alzheimer's disease, atypical or mixed type

--Extract read codes and ICD 10 codes for Alzheimer's by the drug donepezil
SELECT * FROM SAILREFRV.READ_CD rc 
	WHERE READ_DESC LIKE '%onepenzil' OR 
		  READ_DESC LIKE '%ricept'
	ORDER BY READ_CD;
--No READ codes found by using the drug Donepezil Hydrochloride (dementia treating drug)
--(Trade name: Donepezil, Aricept, Aricept Evess)
SELECT * FROM SAILREFRV.ICD10_DIAG_CD idc  
	WHERE DIAG_DESC_3 LIKE '%onepenzil' OR 
		  DIAG_DESC_3 LIKE '%ricept'
	ORDER BY DIAG_CD;
--No ICD10 codes found by using the drug Donepezil Hydrochloride (dementia treating drug)
--(Trade name: Donepezil, Aricept, Aricept Evess)
--Attempting with another drug - Galantamine Hydrobromide
SELECT * FROM SAILREFRV.READ_CD rc 
	WHERE READ_DESC LIKE '%alantamine'
	ORDER BY READ_CD;
SELECT * FROM SAILREFRV.ICD10_DIAG_CD idc  
	WHERE DIAG_DESC_3 LIKE '%alantamine';
--No read codes or ICD10 codes found using dementia drugs


--P3.2a Extract the cases from GP ALF dataset
--1st) Extract GP rows where the event code is the same as the alzheimer's read codes
--2nd) Create a morbseq by ALF_PE to show when was the FIRST diagnosis of Alzheimer's
CREATE TABLE SAILW1074V.AZ_CASES_GP AS(
SELECT wgeac.ALF_PE,
	   wgeac.PRAC_CD_PE,
	   wgeac.LOCAL_NUM_PE,
	   wgeac.GNDR_CD,
	   wgeac.WOB,
	   wgeac.REG_CAT_CD,
	   wgeac.EVENT_DT,
	   wgeac.EVENT_CD_VRS,
	   wgeac.EVENT_CD,
	   wgeac.EVENT_VAL,
	   wgeac.EPISODE,
	   wgeac."SEQUENCE",
	   (((YEAR(wgeac.EVENT_DT) - YEAR(wgeac.WOB))*365 + --This piece of code here calculates
	    			(MONTH(wgeac.EVENT_DT) - MONTH(wgeac.WOB))*30 + -- the AZ diagnosis age
	    			(DAY(wgeac.EVENT_DT) - DAY(wgeac.WOB)))/365) --because there's no age column)
	   AGE,
	   ROW_NUMBER() OVER (PARTITION BY ALF_PE
	   					  ORDER BY ALF_PE, EVENT_DT)
	   MORBSEQ
FROM SAIL1074V.WLGP_GP_EVENT_ALF_CLEANSED_20200401 wgeac
INNER JOIN SAILW1074V.AZ_READ_CODES arc
	ON wgeac.EVENT_CD = arc.READ_CD
ORDER BY ALF_PE, EVENT_DT, PRAC_CD_PE, LOCAL_NUM_PE)WITH DATA;

--Count the number of unique ALF_PE (aka number of people with AZ)
SELECT COUNT(DISTINCT ALF_PE) FROM SAILW1074V.AZ_CASES_GP;
--Result: 32685 distinct ALF_PE
--Note: If i included mixed dementia with alzheimer's the 
--resulting number of distinct ALF_PE is 36091


--P3.2b Extract the cases from the hospital datasets (Primary dataset: PEDW_DIAG_CUTDOWN)
--Note: PEDW_DIAG should have all the diagnosis from PEDW_ EPISODE, theoretically.

--Because the PEDW dataset is not joined yet (it is too big),
--the AZ rows from PEDW_DIAG will be filtered out first and joined with other PEDW datasets
CREATE TABLE SAILW1074V.AZ_CASES_PEDW AS(
SELECT psc.ALF_PE,
	   psc.GNDR_CD,
	   pdc.*, 
	   pec.EPI_STR_DT,
	   pec.AGE_EPI_STR_YR,
	   pec.OPER_CD,
	   psc.DISCH_DT,
	   psc.DISCH_MTHD_CD,
	   ROW_NUMBER() OVER (PARTITION BY psc.ALF_PE
	   					  ORDER BY psc.ALF_PE, pec.EPI_STR_DT, pdc.EPI_NUM, pdc.DIAG_NUM)
	   MORBSEQ --create morbseq
FROM PEDW_DIAG_CUTDOWN pdc
INNER JOIN AZ_ICD10_CODES aic --Filter out the rows with AZ ICD10 codes in PEDW_DIAG
	ON pdc.DIAG_CD = aic.DIAG_CD
INNER JOIN PEDW_EPISODE_CUTDOWN pec --Join with PEDW_EPISODE dataset
	ON pdc.PROV_UNIT_CD = pec.PROV_UNIT_CD AND
	   pdc.SPELL_NUM_PE = pec.SPELL_NUM_PE AND
	   pdc.EPI_NUM = pec.EPI_NUM
INNER JOIN PEDW_SPELL_CUTDOWN psc --Join with PEDW_SPELL dataset
	ON pdc.PROV_UNIT_CD = psc.PROV_UNIT_CD AND
	   pdc.SPELL_NUM_PE = psc.SPELL_NUM_PE 
ORDER BY psc.ALF_PE,
		 pec.EPI_STR_DT,
		 pdc.EPI_NUM, 
		 pdc.DIAG_NUM) WITH DATA;


--------------
--P3.3a Clean AZ_CASES_GP dataset and apply domain & time restrictions
--Check for NULL ALF_PE
SELECT COUNT(*) FROM SAILW1074V.AZ_CASES_GP acg
	WHERE ALF_PE IS NULL;
--Result: 235 rows
DELETE FROM SAILW1074V.AZ_CASES_GP acg
	WHERE ALF_PE IS NULL;

--Remove non-index AZ diagnosis
DELETE FROM SAILW1074V.AZ_CASES_GP acg
	WHERE MORBSEQ <> '1';
--Check the dataset
SELECT COUNT(*) FROM SAILW1074V.AZ_CASES_GP acg; --32685 rows

--Check that all read code versions to be V2
SELECT COUNT(*) FROM SAILW1074V.AZ_CASES_GP acg
	WHERE EVENT_CD_VRS <> 2;
--Result: none

--Apply time restrictions
--Count the number of cases that can be modelled with
SELECT COUNT(*) FROM SAILW1074V.AZ_CASES_GP acg
	WHERE YEAR(EVENT_DT) >= 2015 AND
		  YEAR(EVENT_DT) <= 2019; 
--Result: 10340 cases
--Delete the cases not within the time restriction (2015-2019)
DELETE FROM SAILW1074V.AZ_CASES_GP
	WHERE YEAR(EVENT_DT) > 2019 OR
		  YEAR(EVENT_DT) < 2015;
--Check the number of rows remaining
SELECT COUNT(*) FROM SAILW1074V.AZ_CASES_GP acg; --10340 rows

--Other checks:
--Check for incorrect gender codes
SELECT * FROM SAILW1074V.AZ_CASES_GP acg
	WHERE GNDR_CD < 1 OR
		  GNDR_CD > 2;
--Result: none

--Check for impossible/unresonable years for WOB (week of birth)
SELECT * FROM SAILW1074V.AZ_CASES_GP acg
	WHERE YEAR(WOB) < 1870 OR
	      YEAR(WOB) > 2003;
--Result: 7 cases of children (less than 16 years old) with AZ event codes
--Delete these rows
DELETE FROM SAILW1074V.AZ_CASES_GP
	WHERE YEAR(WOB) < 1870 OR
	      YEAR(WOB) > 2003;
	     
--Apply age restrictions (18 years old or older)
SELECT COUNT(*) FROM SAILW1074V.AZ_CASES_GP
	WHERE AGE >= 18;
--Result: 10326 rows out of 10333 rows
--Delete rows that are non-adults
DELETE FROM SAILW1074V.AZ_CASES_GP
	WHERE AGE < 18;


--P3.3b Clean the cases extracted from AZ_CASES_PEDW
SELECT COUNT(*) FROM SAILW1074V.AZ_CASES_PEDW acp;
--Total rows: 181191 rows
		  
SELECT COUNT(*) FROM SAILW1074V.AZ_CASES_PEDW acp
	WHERE MORBSEQ = '1'; 
--Result: 40713 unique ALF_PEs

--Filter out index cases
SELECT COUNT(*) FROM SAILW1074V.AZ_CASES_PEDW
	WHERE MORBSEQ <> '1';
--Result: 140478 rows
--Delete the non-index cases
DELETE FROM SAILW1074V.AZ_CASES_PEDW
	WHERE MORBSEQ <> '1';
--Check number of rows left:
SELECT COUNT(*) FROM SAILW1074V.AZ_CASES_PEDW acp;
--Result: 40713 rows

--Check for null values
SELECT COUNT(*) FROM SAILW1074V.AZ_CASES_PEDW
	WHERE ALF_PE IS NULL OR
		  PROV_UNIT_CD IS NULL OR
		  SPELL_NUM_PE IS NULL OR
		  EPI_STR_DT IS NULL OR
		  DIAG_CD IS NULL;
--Result: none

--Check for patients that died before the time restriction (Before 2015)
SELECT COUNT(*) FROM SAILW1074V.AZ_CASES_PEDW acp
	WHERE DISCH_MTHD_CD = '4' AND  --DISCH_MTHD_CD = '4' means patient passed away
		  YEAR(DISCH_DT) < 2015;
--Result: 3180
DELETE FROM SAILW1074V.AZ_CASES_PEDW acp
	WHERE DISCH_MTHD_CD = '4' AND
	      YEAR(DISCH_DT) < 2015;
	     
--Check for inccorect gender codes (not '1' or '2')
SELECT COUNT(*) FROM SAILW1074V.AZ_CASES_PEDW acp 
	WHERE GNDR_CD > 2 OR
		  GNDR_CD < 1;
--Result: none

--Check that discharge date is always after or same as admin date
SELECT * FROM SAILW1074V.AZ_CASES_PEDW acp
	WHERE EPI_STR_DT > DISCH_DT;
--Result: 7 rows
DELETE FROM SAILW1074V.AZ_CASES_PEDW acp
	WHERE EPI_STR_DT > DISCH_DT;

--Apply time restrictions (between 2015 to 2019)
SELECT COUNT(*) FROM SAILW1074V.AZ_CASES_PEDW acp
	WHERE YEAR(EPI_STR_DT) >= 2015 AND
		  YEAR(EPI_STR_DT) <= 2019;
--Result: 11434 ALF_PEs
DELETE FROM SAILW1074V.AZ_CASES_PEDW acp
	WHERE YEAR(EPI_STR_DT) < 2015 OR
		  YEAR(EPI_STR_DT) > 2019;
--Check how many rows are left:
SELECT COUNT(*) FROM SAILW1074V.AZ_CASES_PEDW acp;
--Result: 11434 rows

--Apply age restrictions (18+)
SELECT COUNT(*) FROM SAILW1074V.AZ_CASES_PEDW acp
	WHERE AGE_EPI_STR_YR >= 18 OR
		  AGE_EPI_STR_YR > 120;
--Result: 11433 rows
--Delete the ###### that is not within the age restriction
DELETE FROM SAILW1074V.AZ_CASES_PEDW acp
	WHERE AGE_EPI_STR_YR < 18 OR
		  AGE_EPI_STR_YR > 120;

--Number of ALF_PEs that fits within the case category
SELECT COUNT(*) FROM SAILW1074V.AZ_CASES_PEDW acp;
--Result: 11433 ALF_PEs


------------------------------------------------------------------------------------

--Correction starts here

------------------------------------------------------------------------------------
--------------
--P3.4 Creating a full list of Alzheimer's patients that fit within the time and domain
--restrictions from the two tables (GP data WLGP & Hospital data PEDW).


CREATE TABLE SAILW1074V.C_AZ_CASES AS(
SELECT (CASE
			WHEN acp.ALF_PE IS NULL
			THEN acg.ALF_PE
			ELSE acp.ALF_PE
		END) AS ALF_PE,
	   (CASE
	   		WHEN acg.GNDR_CD IS NULL
	   		THEN acp.GNDR_CD
	   		ELSE acg.GNDR_CD
	   	END) AS GNDR_CD,
	   (CASE
	   		WHEN (acp.EPI_STR_DT <= acg.EVENT_DT) OR
	   			  acg.EVENT_DT IS NULL
	   		THEN acp.EPI_STR_DT
	   		ELSE acg.EVENT_DT
	    END) AS DIAG_DT,
	   acp.DIAG_CD AS ICD_CD,
	   acg.EVENT_CD AS READ_CD,
	   (CASE
	   		WHEN (acp.AGE_EPI_STR_YR < acg.AGE) OR
	   			  acg.AGE IS NULL
	   		THEN acp.AGE_EPI_STR_YR
	   		ELSE acg.AGE
	    END) AS AGE
FROM SAILW1074V.AZ_CASES_GP acg 
FULL OUTER JOIN SAILW1074V.AZ_CASES_PEDW acp
ON acg.ALF_PE = acp.ALF_PE
ORDER BY ALF_PE) WITH DATA;


--Check number of rows
SELECT COUNT(*) FROM SAILW1074V.C_AZ_CASES; --18182 rows

--Quick check
SELECT COUNT(*) FROM SAILW1074V.C_AZ_CASES
	WHERE (READ_CD IS NULL AND ICD_CD IS NULL) OR
		   ALF_PE IS NULL OR
		   GNDR_CD IS NULL OR
		   DIAG_DT IS NULL;
--Result: none

--Creating a column named 'CASES' and set all to '1'
--This column will allow the identification of cases ('1') and controls ('0') later on
--1st) Create the column 'CASES'
ALTER TABLE SAILW1074V.C_AZ_CASES
ADD COLUMN CASES NUMERIC;
--2nd) Edit '1' onto the column 'CASES'
UPDATE SAILW1074V.C_AZ_CASES
SET CASES = 1;


--------------
--P3.5 Create cases table ready for feature selection

--P3.5 Implement WIMD (Deprivation) score for ALF_PE in WDSD_LSOA2011_CUTDOWN
--Note: If there are multiple deprivation scores for one ALF_PE, the score is chosen based on
--where the person is living at at the time of diagnosis
CREATE TABLE SAILW1074V.C_AZ_CASES2 AS(
SELECT ac.*,
	   wlc.WIMD_2014_QUINTILE AS DEP_SCORE
FROM SAILW1074V.C_AZ_CASES ac
LEFT JOIN SAILW1074V.WDSD_LSOA2011_CUTDOWN wlc
ON ac.ALF_PE = wlc.ALF_PE AND
   ac.DIAG_DT >= wlc.START_DATE AND
   ac.DIAG_DT <= wlc.END_DATE) WITH DATA;

--Check that there are no duplicates
SELECT COUNT(*) FROM SAILW1074V.C_AZ_CASES2; --18182
SELECT COUNT(DISTINCT ALF_PE) FROM SAILW1074V.C_AZ_CASES2; --18182

--Check for null deprivation scores
SELECT COUNT(*) FROM SAILW1074V.C_AZ_CASES2
	WHERE DEP_SCORE IS NULL;
--Result: 1617 rows
--Delete these rows
DELETE FROM SAILW1074V.C_AZ_CASES2
	WHERE DEP_SCORE IS NULL;

--Checking if any of the cases died before 2015.
WITH temp AS(
SELECT azc.*,
	   adc.DEATH_DT
FROM C_AZ_CASES2 azc
INNER JOIN ADDE_DEATHS_CUTDOWN adc
ON azc.ALF_PE = adc.ALF_PE)
SELECT * FROM temp
	WHERE YEAR(DEATH_DT) < 2015;
--Result: none

--Check the dataset
SELECT COUNT(*) FROM SAILW1074V.C_AZ_CASES2; 
--Resukt: 16565 rows


--This table - AZ_CASES2 contains all the AZ ALF_PEs (aka All cases) and their necessary info for
--dataset linkage and info for category matched sampling controls.


------------------------------------
--Part 4: Feature extraction (Extract the 50 most common read codes)

--P4.1 Creating a table showing the most common 200 read codes found in AZ patients 5 years
--prior to the diagnosis (aka most common read codes found in cases)
CREATE TABLE SAILW1074V.C_MOST_FREQ_RD_CDS AS(
WITH temp AS(
--The following joins the C_AZ_CASES2 file with WLGP_ALF_EVENT based on common ALF_PEs
SELECT ac2.*,
	   wgeac.EVENT_CD,
	   wgeac.EVENT_DT,
	   (((YEAR(DIAG_DT) - YEAR(EVENT_DT))*365) +
	   	((MONTH(DIAG_DT) - MONTH(EVENT_DT))*30) +
	   	(DAY(DIAG_DT) - MONTH(EVENT_DT))) AS TIMERES 
	   	--This gives the number of days between diagnosis and event
FROM SAILW1074V.C_AZ_CASES2 ac2
INNER JOIN SAIL1074V.WLGP_GP_EVENT_ALF_CLEANSED_20200401 wgeac
ON ac2.ALF_PE = wgeac.ALF_PE AND
   ac2.GNDR_CD = wgeac.GNDR_CD
ORDER BY ac2.ALF_PE, wgeac.EVENT_DT)
SELECT EVENT_CD,
	   COUNT(*) AS CD_COUNT
FROM temp
WHERE TIMERES > 1825 --skipping 5 years worth of data for the prediction.
	GROUP BY EVENT_CD
ORDER BY CD_COUNT DESC --IMPORTANT NOTE: ORDER BY DOES NOT WORK WHEN CREATING TABLE
LIMIT 200)WITH DATA; --NEED TO MANUALLY ARRANGE IT IN THE TABLE VIEW

--Check the list MOST_FREQ_RD_CDS
--Need to remove EVENT_CD that is blank and 'ZZZZZ'
DELETE FROM SAILW1074V.C_MOST_FREQ_RD_CDS
	WHERE EVENT_CD = 'ZZZZZ' OR
		  EVENT_CD = '';

--Check for any AZ read codes in the MOST_FREQ_RD_CDS
SELECT mfrc.EVENT_CD,
	   arc.READ_CD
FROM C_MOST_FREQ_RD_CDS mfrc 
INNER JOIN AZ_READ_CODES arc
ON mfrc.EVENT_CD = arc.READ_CD;
--Result: No AZ diagnosis codes

--Check code descriptions
SELECT mfrc.*,
	   rc.READ_DESC
FROM C_MOST_FREQ_RD_CDS mfrc
INNER JOIN SAILREFRV.READ_CD rc
ON mfrc.EVENT_CD = rc.READ_CD
ORDER BY mfrc.CD_COUNT DESC;
--*Note: Data driven approach means limited feature selection,
--therefore will ignore the seemingly not-so-useful read codes 
-- (eg. 229.. - O/E - hieght)

--There were a couple of features that DID NOT HAVE DESCRIPTIONS
--Remove those rows
DELETE FROM SAILW1074V.C_MOST_FREQ_RD_CDS mfrc
	WHERE EVENT_CD LIKE 'PCSDT' OR 
		  EVENT_CD LIKE 'EMISA' OR
		  EVENT_CD LIKE '8B314';


--Limit to the most frequent *50* read codes
DELETE FROM SAILW1074V.C_MOST_FREQ_RD_CDS mfrc
	WHERE CD_COUNT < 69000; 
	--The cut-off point for 50 most freq read codes
	--Reminder: the CD_COUNT needs to be ordered manually in table-view


------------------------------------
--Part 5: Define Controls (Category matched sampling)

--Checking how many cases there are for each group (aka same gender, dep score, age)
SELECT GNDR_CD, DEP_SCORE, AGE, COUNT(*) AS NUM FROM AZ_CASES2
GROUP BY GNDR_CD, DEP_SCORE, AGE
ORDER BY NUM DESC
--Result: Max 90 cases in one group
--This means for a ratio of 5 controls to 1 case, 450 cases per group is needed

--P5.1 - Compile a list of randomly selected ALF_PEs from WLGP_ALF_EVENT.
--And then join this list of random ALF_PEs with other tables to retrieve information
--such as their deprevation level, age category, sex while applying domain & time
--restrictions.
CREATE TABLE SAILW1074V.CONTROLS AS(
WITH temp11 AS(
	SELECT wgeac.ALF_PE,
	   		wgeac.GNDR_CD,
	   		YEAR(wgeac.WOB) AS YOB, --Year of birth
	  		wlc.WIMD_2014_QUINTILE,
	   		ROW_NUMBER() OVER (PARTITION BY wgeac.ALF_PE
	   					  ORDER BY wgeac.EVENT_DT)
	   		AS morbseq, --this will be used to make sure there is no duplicate ALF_PE
	   		RAND() AS rand_num
	FROM SAIL1074V.WLGP_GP_EVENT_ALF_CLEANSED_20200401 wgeac
	INNER JOIN SAILW1074V.WDSD_LSOA2011_CUTDOWN wlc
	ON wgeac.ALF_PE = wlc.ALF_PE AND
	   YEAR(wgeac.WOB) > --##### AND --##Maximum age of AD cases MASKED FOR FILE OUT
	   YEAR(wgeac.WOB) < 2001 AND --Making sure the person is an adult at least by 2019
	   wgeac.EVENT_CD_VRS = '2' AND-- Making sure when feature selecting its using read code v2
	   wgeac.GNDR_CD <= 2 AND --Making sure there are no impossible gender code
	   wgeac.GNDR_CD >= 1 AND
	   YEAR(wlc.START_DATE) < 2015 AND --Making sure the person did not move address during
	   YEAR(wlc.END_DATE) > 2019),      --when the cases were being diagnosed
temp12 AS(
	SELECT * FROM temp11
	WHERE morbseq = 1),
--The following ensures the control is not dead and is not in AZ_CASES2
temp13 AS(
	SELECT *,
		   --The following count the number of controls within a group 
	   	   --(aka same year of birth ,gender,dep score)
		   ROW_NUMBER() OVER (PARTITION BY GNDR_CD, WIMD_2014_QUINTILE, YOB 
		   								   --Note the order above
			   					  ORDER BY rand_num)
		   AS GROUP_COUNT
	FROM temp12)
SELECT ALF_PE,
	   GNDR_CD,
	   YOB,
	   WIMD_2014_QUINTILE AS DEP_SCORE 
FROM temp13
WHERE GROUP_COUNT < 800 --Reducing the number of rows (*realistically i need max 450 rows for
						--a ratio of 1 case to 5 controls, but more rows will be deleted later)
ORDER BY GNDR_CD, DEP_SCORE, YOB) WITH DATA;

--Calculate the number of distinct ALF_PEs for controls 
SELECT COUNT(*) FROM SAILW1074V.CONTROLS;
--Result: 580493
--Ensuring there is no duplicate ALF_PE
SELECT COUNT(DISTINCT ALF_PE) FROM SAILW1074V.CONTROLS;
--Result: 580493 - no duplicates


--P5.2 - Continuing the application of domain restrictions (eg. alive, no history of AZ and
--other dementias, are not already assigned as an AZ 'case')

--Checking if the person in the CONTROLS table is alive by joining with ADDE_DEATH_CUTDOWN
WITH temp AS(
SELECT c.*
FROM SAILW1074V.CONTROLS c
INNER JOIN SAILW1074V.ADDE_DEATHS_CUTDOWN adc
ON c.ALF_PE = adc.ALF_PE)
SELECT COUNT(*) FROM temp;
--Result: 5803 rows
--Delete these rows
DELETE FROM SAILW1074V.CONTROLS c
WHERE c.ALF_PE IN (SELECT adc.ALF_PE FROM SAILW1074V.ADDE_DEATHS_CUTDOWN adc)

--Check if the person in the CONTROLS table also exist in the AZ_CASES2 table
WITH temp AS(
SELECT c.*
FROM SAILW1074V.CONTROLS c
INNER JOIN SAILW1074V.AZ_CASES2 ac2
ON c.ALF_PE = ac2.ALF_PE)
SELECT COUNT(*) FROM temp;
--Resutl: 1067 rows
--Delete these rows
DELETE FROM SAILW1074V.CONTROLS c
WHERE c.ALF_PE IN (SELECT ac2.ALF_PE FROM SAILW1074V.AZ_CASES2 ac2);

--Recount how many controls left
SELECT COUNT(*) FROM SAILW1074V.CONTROLS;
--Result: 573623

--Create a new column 'CASES' which will = '0', denoting these are controls
ALTER TABLE SAILW1074V.CONTROLS
ADD COLUMN CASES NUMERIC;
--Add the '0'
UPDATE SAILW1074V.CONTROLS
SET CASES = 0;


--P5.2a Check that the ALF_PEs do not have other dementias
--1st) Create a list of dementia read codes
CREATE TABLE SAILW1074V.DEMENTIA_CODES AS (
	SELECT * FROM SAILREFRV.READ_CD rc 
		WHERE READ_DESC LIKE '%ementia%'
		ORDER BY READ_CD) WITH DATA;
--Check the dementia codes manually
	
--2nd) Check if the controls have any records of dementia read codes
CREATE TABLE SAILW1074V.TEMP_DEM_PATIENTS AS(
WITH temp15 AS(
	--The following joins the WLGP_EVENT_ALF data with the controls table to find
	--all the event codes of each 'control' ALF_PE
	SELECT c.*,
		   wgeac.EVENT_CD,
		   wgeac.EVENT_DT,
		   wgeac.EVENT_VAL
	FROM SAILW1074V.CONTROLS c
	INNER JOIN SAIL1074V.WLGP_GP_EVENT_ALF_CLEANSED_20200401 wgeac
	ON c.ALF_PE = wgeac.ALF_PE AND
	   c.GNDR_CD = wgeac.GNDR_CD)
--The following joins the newly created temp table with the dementia codes table
SELECT t15.*
FROM temp15 t15
INNER JOIN SAILW1074V.DEMENTIA_CODES dc
ON t15.EVENT_CD = dc.READ_CD) WITH DATA;

--3rd) Check how many controls have records of other dementias
SELECT COUNT(DISTINCT ALF_PE) FROM TEMP_DEM_PATIENTS tdp;
--Result: 7026 rows

--4th) Delete the rows and the temporary table (manually)
DELETE FROM SAILW1074V.CONTROLS c
WHERE c.ALF_PE IN (SELECT tdp.ALF_PE FROM SAILW1074V.TEMP_DEM_PATIENTS tdp);
--7026 rows deleted

--Recount how many controls left
SELECT COUNT(*) FROM SAILW1074V.CONTROLS;
--Result: 566597 rows left

--P5.2b - Checking if the controls have any AZ read codes
--1st) Create a temporary table
CREATE TABLE TEMP_AZ_RD_CDS AS(
WITH temp18 AS(
	--The following joins the WLGP_EVENT_ALF data with the controls table to find
	--all the event codes of each 'control' ALF_PE
	SELECT c.*,
		   wgeac.EVENT_CD,
		   wgeac.EVENT_DT,
		   wgeac.EVENT_VAL
	FROM SAILW1074V.CONTROLS c
	INNER JOIN SAIL1074V.WLGP_GP_EVENT_ALF_CLEANSED_20200401 wgeac
	ON c.ALF_PE = wgeac.ALF_PE AND
	   c.GNDR_CD = wgeac.GNDR_CD)
--The following joins the newly created temp table with the AZ read codes table
SELECT t18.*
FROM temp18 t18
INNER JOIN SAILW1074V.AZ_READ_CODES arc
ON t18.EVENT_CD = arc.READ_CD)WITH DATA;

--2nd) Check how many distinct ALF_PEs there are
SELECT COUNT(DISTINCT ALF_PE) FROM SAILW1074V.TEMP_AZ_RD_CDS;
--Result: 525 ALF_PEs

--3rd) Delete these rows in the CONTROLS table
DELETE FROM SAILW1074V.CONTROLS c
WHERE c.ALF_PE IN (SELECT tarc.ALF_PE FROM SAILW1074V.TEMP_AZ_RD_CDS tarc)
--Deleted 525 rows

--4th) Delete the TEMP_AZ_RD_CDS table manually


--P5.2c - Check for Alzheimer's ICD10 codes in the control group
--1st) Check how many rows
WITH temp19 AS (
	SELECT c.*,
		   pdc.DIAG_CD
	FROM SAILW1074V.CONTROLS c
	INNER JOIN SAILW1074V.PEDW_SPELL_CUTDOWN psc
	ON c.ALF_PE = psc.ALF_PE
	INNER JOIN SAILW1074V.PEDW_DIAG_CUTDOWN pdc
	ON pdc.PROV_UNIT_CD = psc.PROV_UNIT_CD AND
	   pdc.SPELL_NUM_PE = psc.SPELL_NUM_PE
	INNER JOIN SAILW1074V.AZ_ICD10_CODES aic
	ON pdc.DIAG_CD = aic.DIAG_CD)
SELECT COUNT(DISTINCT ALF_PE) FROM temp19;
--Result: 77 ALF_PEs
--2nd) Again, create a temporary table
CREATE TABLE TEMP_AZ_ICD_PATIENTS AS(
SELECT c.*,
		   pdc.DIAG_CD
	FROM SAILW1074V.CONTROLS c
	INNER JOIN SAILW1074V.PEDW_SPELL_CUTDOWN psc
	ON c.ALF_PE = psc.ALF_PE
	INNER JOIN SAILW1074V.PEDW_DIAG_CUTDOWN pdc
	ON pdc.PROV_UNIT_CD = psc.PROV_UNIT_CD AND
	   pdc.SPELL_NUM_PE = psc.SPELL_NUM_PE
	INNER JOIN SAILW1074V.AZ_ICD10_CODES aic
	ON pdc.DIAG_CD = aic.DIAG_CD) WITH DATA;

--Delete the rows in the control dataset
DELETE FROM SAILW1074V.CONTROLS c
WHERE c.ALF_PE IN (SELECT taip.ALF_PE FROM SAILW1074V.TEMP_AZ_ICD_PATIENTS taip);
--77 rows deleted

--3rd) Delete the table TEMP_AZ_ICD10_CDS manually

--Count controls left
SELECT COUNT(*) FROM SAILW1074V.CONTROLS;
--Result: 565995


------------------------
--Part 6 - Category match controls with cases
--THIS IS DONE IN R with the script 'fastmatchedcohort'

--P6.1 - Import the AZ_CASES2 and CONTROLS dataset in R
--And then export the created file C_CASE_CTRL back to SQL

--P6.2 - Category match controls to cases (*1 case to 5 controls)
--(Category matched by year of birth, gender and dep score)

--P6.3 - Import the matched dataset BACK TO SQL & check the dataset (called CASE_CTRL)
--Count the number of rows
SELECT COUNT(*) FROM SAILW1074V.C_CASE_CTRL cc;
--Result: 82825 - as expected because there were 16565 rows in AZ_CASES2 (16565 x 5 = 82825)

--Check for number of rows with cases that does not have enough controls
SELECT COUNT(*) FROM SAILW1074V.C_CASE_CTRL cc
	WHERE "ALF_PEy" IS NULL;
--Result: 5446 rows
--Note: It seems like those cases that were not able to match with a control resulted
--in the entire row being blank, as seen as below
SELECT COUNT(*) FROM SAILW1074V.C_CASE_CTRL cc
	WHERE "ALF_PEx" IS NULL;
--Result: 5446 rows
SELECT * FROM SAILW1074V.C_CASE_CTRL cc
	WHERE "ALF_PEx" IS NULL;
--Delete these rows
DELETE FROM SAILW1074V.C_CASE_CTRL cc
	WHERE "ALF_PEx" IS NULL;
--5446 rows deleted

--Check for duplicate controls (ALF_PEy)
SELECT COUNT(*) FROM SAILW1074V.C_CASE_CTRL cc;
--Result: 77379
SELECT COUNT(DISTINCT "ALF_PEy") FROM SAILW1074V.C_CASE_CTRL cc;
--Result: 77379 - no duplicates

--Note: "ALF_PEx" are cases, "ALF_PEy" are controls
--Check for other nulls
SELECT * FROM SAILW1074V.C_CASE_CTRL cc
	WHERE "ALF_PEx" IS NULL OR
		  "ALF_PEy" IS NULL OR
		  GNDR_CD IS NULL OR
		  YOB IS NULL OR
		  DEP_SCORE IS NULL OR
		  "CASESx" IS NULL OR
		  "CASESy" IS NULL;
--Result: none

--Check how many cases were able to find at least one control, but not enough controls (five)
WITH temp21 AS(
	SELECT cc.*,
		   ROW_NUMBER() OVER (PARTITION BY "ALF_PEx" ORDER BY "ALF_PEy")
		   AS MORBSEQ,
		   ROW_NUMBER() OVER (PARTITION BY "ALF_PEx" ORDER BY "ALF_PEy" DESC)
		   AS CONTROL_COUNT
	FROM SAILW1074V.C_CASE_CTRL cc)
SELECT COUNT(*) FROM temp21
	WHERE MORBSEQ = 1 AND 
		  CONTROL_COUNT <> 5;
--Result: 90 distinct cases
--Delete these cases as there were insufficient controls
--1st) Create a temporary table that contains all these cases with insufficient controls
CREATE TABLE TEMP_INSUF_CTRL AS(
WITH temp21 AS(
	SELECT cc.*,
		   ROW_NUMBER() OVER (PARTITION BY "ALF_PEx" ORDER BY "ALF_PEy")
		   AS MORBSEQ,
		   ROW_NUMBER() OVER (PARTITION BY "ALF_PEx" ORDER BY "ALF_PEy" DESC)
		   AS CONTROL_COUNT
	FROM SAILW1074V.C_CASE_CTRL cc)
SELECT * FROM temp21
	WHERE MORBSEQ = 1 AND 
		  CONTROL_COUNT <> 5)WITH DATA;
--2nd) Inner join with with original CASE_CTRL table to remove those cases
DELETE FROM SAILW1074V.C_CASE_CTRL cc
	WHERE cc."ALF_PEx" IN (SELECT tic."ALF_PEx" FROM SAILW1074V.TEMP_INSUF_CTRL tic);
--234 rows deleted
--3rd) Delete the temporary table manually

--Check how many cases are left
SELECT COUNT(DISTINCT "ALF_PEx") FROM SAILW1074V.C_CASE_CTRL cc;
--Result: 15429 cases with sufficient controls..
SELECT COUNT(*) FROM SAILW1074V.C_CASE_CTRL cc;
--Out of 77145 rows

--Done checking, now adding a unique identifier for each case-control group
ALTER TABLE SAILW1074V.C_CASE_CTRL
ADD COLUMN GROUP_ID INT;

UPDATE SAILW1074V.C_CASE_CTRL
SET GROUP_ID = (DENSE_RANK() OVER (ORDER BY "ALF_PEx"));

--This is used for the next part, joining the AZ diagnosis date back to the table
--as it was removed in R, due to a problem with the function "sqlsave()" in R and 
--columns with dates

--Create a new table SAILW1074V.CASE_CTRL2 
--(because using the UPDATE clause somehow was taking very long to load)
CREATE TABLE SAILW1074V.C_CASE_CTRL2 AS(
SELECT cc."ALF_PEx" AS CASE_ALF,
	   cc."ALF_PEy" AS CTRL_ALF,
	   ac2.DIAG_DT,
	   cc.GNDR_CD,
	   cc.YOB,
	   cc.DEP_SCORE,
	   cc."CASESx",
	   cc."CASESy",
	   cc.GROUP_ID
FROM SAILW1074V.C_CASE_CTRL cc
LEFT JOIN SAILW1074V.C_AZ_CASES2 ac2
ON cc."ALF_PEx" = ac2.ALF_PE)WITH DATA;


------------------------------------
--Part 7: Creating a platform file for both cases and controls with all the features

--P7.1 Create a platform table with all the controls and cases ALF_PE in one column
--1st) Create a table for cases 
CREATE TABLE C_CASE_CTRL3 AS(
	SELECT DISTINCT CASE_ALF AS ALF_PE,
		   DIAG_DT,
		   GNDR_CD,
		   YOB,
		   DEP_SCORE,
		   "CASESx" AS CASES,
		   GROUP_ID
	FROM SAILW1074V.C_CASE_CTRL2 cc2) WITH DATA;
	
--2nd) Create a temporary table for controls
CREATE TABLE TEMP_CC_CONTROLS AS(
	SELECT CTRL_ALF AS ALF_PE,
		   DIAG_DT,
		   GNDR_CD,
		   YOB,
		   DEP_SCORE,
		   "CASESy" AS CASES,
		   GROUP_ID
	FROM SAILW1074V.C_CASE_CTRL2 cc2) WITH DATA;

--3rd) Check the two tables
SELECT COUNT(*) FROM C_CASE_CTRL3;
--Result: 15429 rows - same as number of distinct ALF_PEs that are cases
SELECT COUNT(*) FROM TEMP_CC_CONTROLS;
--Result: 77145 - same as number of distinct ALF_PEs that are controls

--4th) Join the two tables together where "ALF_PE" contains both cases and controls
INSERT INTO C_CASE_CTRL3
SELECT * FROM TEMP_CC_CONTROLS;

--5th) Check that the tables are joined correctly
SELECT COUNT(*) FROM C_CASE_CTRL3;
--Result: 92574 rows - 77145 + 15429 = 92574 (no problems)
--Check the table
SELECT * FROM C_CASE_CTRL3 ORDER BY GROUP_ID;
SELECT COUNT(*) FROM C_CASE_CTRL3 WHERE CASES = 1;
--Result: 15429 rows 


--6th) Delete the temporary controls table manually (TEMP_CC_CONTROLS)


--P7.2 Combine this new file with WLGP_ALF_EVENT and MOST_FREQ_RD_CDS to look for
--whether the top 50 most common features found in cases are also in each ALF_PE
--(For both cases & controls)
CREATE TABLE C_CASE_CTRL_FEATURES AS (
WITH temp25 AS(
	SELECT cc3.ALF_PE,
		   cc3.GNDR_CD,
		   cc3.YOB,
		   cc3.DEP_SCORE,
		   cc3.CASES,
		   cc3.GROUP_ID,
		   wgeac.EVENT_CD,
		   wgeac.EVENT_DT,
		   wgeac.EVENT_VAL,
	   	   --the following calculates the days between DIAG_DT and EVENT_DT
		   (((YEAR(cc3.DIAG_DT) - YEAR(wgeac.EVENT_DT))*365)+
		    ((MONTH(cc3.DIAG_DT) - MONTH(wgeac.EVENT_DT))*30) +
		     (DAY(cc3.DIAG_DT) - DAY(wgeac.EVENT_DT)))
		   AS DAYSBETWEEN,
		   --the following creates a unique identifier for each row,
		   --this is used to prevent a problem in temp26 where
		   --morbseq = 1 might not be max EVENT_COUNT if there are multiple
		   --identical events on the same day 
		   ROW_NUMBER() OVER (ORDER BY cc3.ALF_PE, wgeac.EVENT_DT)
		   AS FILESEQ
	FROM SAIL1074V.WLGP_GP_EVENT_ALF_CLEANSED_20200401 wgeac
	INNER JOIN SAILW1074V.C_CASE_CTRL3 cc3
	ON cc3.ALF_PE = wgeac.ALF_PE
	INNER JOIN SAILW1074V.C_MOST_FREQ_RD_CDS mfrc
	ON wgeac.EVENT_CD = mfrc.EVENT_CD
	ORDER BY cc3.ALF_PE, wgeac.EVENT_CD, wgeac.EVENT_DT),
temp26 AS(
	SELECT ALF_PE,
		   GNDR_CD,
		   YOB,
		   DEP_SCORE,
		   CASES,
		   GROUP_ID,
		   EVENT_CD,
		   --The MEAN of the event value per code per ALF_PE are calculated
		   avg(EVENT_VAL) OVER (PARTITION BY ALF_PE, EVENT_CD)
		   AS AVG_EVT_VAL,
		   DAYSBETWEEN,
		   ROW_NUMBER() OVER (PARTITION BY ALF_PE, EVENT_CD
			   				  ORDER BY ALF_PE, EVENT_DT, FILESEQ)
		   AS MORBSEQ,
		   --count number of events of the same code
		   ROW_NUMBER() OVER (PARTITION BY ALF_PE, EVENT_CD
		   					  ORDER BY ALF_PE, EVENT_DT DESC, FILESEQ)
		   AS EVENT_COUNT
	FROM temp25
	WHERE DAYSBETWEEN >= 1825) --time restriction: removing the 5 years before AD diagnosis
SELECT ALF_PE,
	   GNDR_CD,
	   YOB,
	   DEP_SCORE,
	   CASES,
	   GROUP_ID,
	   EVENT_CD,
	   AVG_EVT_VAL,
	   EVENT_COUNT
FROM temp26
	WHERE MORBSEQ = 1) WITH DATA; --Morbseq = 1 to remove excess data and show number 
								  --of occurances of a particular event code of a 
								  --particular ALF_PE

--Check the dataset
SELECT COUNT(*) FROM SAILW1074V.C_CASE_CTRL_FEATURES ccf;
--Total number of rows: 2617392
SELECT COUNT(DISTINCT ALF_PE) FROM SAILW1074V.C_CASE_CTRL_FEATURES ccf;
--Total number of unique ALF_PEs left: 87139
SELECT COUNT(DISTINCT ALF_PE) FROM SAILW1074V.C_CASE_CTRL_FEATURES ccf
	WHERE CASES = 1;
--Number of unique cases that had at least one of these read codes: 13328
SELECT COUNT(DISTINCT ALF_PE) FROM SAILW1074V.C_CASE_CTRL_FEATURES ccf
	WHERE CASES = 0;
--Number of unique controls that had at least one of these read codes: 73811
--This means:
--15429 - 13328 = 2101 cases did NOT have one of the "most common" read codes
--77145 - 73811 = 3334 controls did NOT have one of the "most common" read codes


--P7.3 - Input these rows that did NOT have one of the "most common" read codes
--back into the dataset
--1st) Create a temporary table
CREATE TABLE SAILW1074V.TEMP_NO_RD_CDS AS(
SELECT ALF_PE,
	   GNDR_CD,
	   YOB,
	   DEP_SCORE,
	   CASES,
	   GROUP_ID
FROM SAILW1074V.C_CASE_CTRL3
	WHERE ALF_PE NOT IN
		(SELECT ALF_PE FROM SAILW1074V.C_CASE_CTRL_FEATURES))WITH DATA;

--Check the temp table
SELECT COUNT(*) FROM SAILW1074V.TEMP_NO_RD_CDS;
--Result: 5435 rows - which is exactly = 2101 + 3334

--2nd)Create the EVENT_CD, AVG_EVT_VAL and EVENT_COUNT columns in the temp table
ALTER TABLE SAILW1074V.TEMP_NO_RD_CDS
ADD COLUMN EVENT_CD CHAR;

ALTER TABLE SAILW1074V.TEMP_NO_RD_CDS
ADD COLUMN AVG_EVT_VAL NUMERIC;

ALTER TABLE SAILW1074V.TEMP_NO_RD_CDS
ADD COLUMN EVENT_COUNT NUMERIC;

--Set EVENT_COUNT to 0
UPDATE SAILW1074V.TEMP_NO_RD_CDS
SET EVENT_COUNT = 0;

--Set EVENT_CD to 'Z', as the EVENT_CD column in CASE_CTRL_FEATURES cannot be NULL
--Therefore, 'Z' will represent no event codes
UPDATE SAILW1074V.TEMP_NO_RD_CDS
SET EVENT_CD = 'Z';

--3rd) Insert them into the CASEE_CTRL_FEATURES table

INSERT INTO SAILW1074V.C_CASE_CTRL_FEATURES
SELECT * FROM SAILW1074V.TEMP_NO_RD_CDS;

--4th) Delete the TEMP_NO_RD_CDS table manually

--Check the CASE_CTRL_FEATURES dataset again
SELECT COUNT(*) FROM SAILW1074V.C_CASE_CTRL_FEATURES
	WHERE EVENT_CD = 'Z';
--Result: 5435
SELECT COUNT(DISTINCT ALF_PE) FROM SAILW1074V.C_CASE_CTRL_FEATURES;
--Result: 92574 - Perfect!

--Replace AVG_EVT_VAL that are 0 with NULL
UPDATE SAILW1074V.C_CASE_CTRL_FEATURES
SET AVG_EVT_VAL = NULL
WHERE AVG_EVT_VAL = '0';


--The C_CASE_CTRL_FEATURES dataset will now be imported to R for pivoting to a wide
--dataset, then train/test split, model with ML and results analysis
----------------------------------------------------------------------------------
--Part 8: Creating a balanced dataset (1 to 1 ratio between case & control)


--Cut down from CASE_CTRL_FEATURES which has 1 to 5 case control ratio to 1 to 1 ratio
--Create group_seq order by GROUP_ID, CASES DESC, ALF_PE so that each ALF_PE will
--have the same unique ID which repeats for every GROUP_ID
CREATE TABLE C_CASE_CTRL_FEATURES_BAL AS(
WITH temp26 AS (
SELECT *,
	   DENSE_RANK() OVER (PARTITION BY GROUP_ID
	   					  ORDER BY GROUP_ID, CASES DESC, ALF_PE)
	   AS GROUP_SEQ
FROM SAILW1074V.C_CASE_CTRL_FEATURES ccf)
SELECT ALF_PE,
	   GNDR_CD,
	   YOB,
	   DEP_SCORE,
	   CASES,
	   GROUP_ID,
	   EVENT_CD,
	   AVG_EVT_VAL,
	   EVENT_COUNT
FROM temp26
	WHERE GROUP_SEQ <= 2
ORDER BY GROUP_ID, CASES DESC) WITH DATA;


--The C_CASE_CTRL_FEATURES_BAL dataset will also be imported to R for pivoting to a wide
--dataset, then train/test split, model with ML and results analysis
----------------------------------------------------------------------------------


--------------------------------------------------------------CORRECTION ENDS (FOR NOW)
--THE FOLLOWING SECTION IS NOT IN THE FILE-OUT REQUEST SQL FILE
----------------------------------------------------------------------------------
--Part 9: Results analysis
--Determining the meaning of the variables from the variable importance plot by bal_rfmodel3A

SELECT * FROM SAILREFRV.READ_CD rc 
		WHERE READ_CD LIKE '44E..' OR
			  READ_CD LIKE '44G3.' OR
			  READ_CD LIKE '451E.' OR
			  READ_CD LIKE '44J9.' OR
			  READ_CD LIKE '44E..' OR
			  READ_CD LIKE '44G3.' OR
			  READ_CD LIKE '44P6.' OR
			  READ_CD LIKE '44J9.' OR
			  READ_CD LIKE '44Q..' OR
			  READ_CD LIKE '44P5.' OR
			  READ_CD LIKE '451E.' OR
			  READ_CD LIKE '426..' OR
			  READ_CD LIKE '44P6.' OR
			  READ_CD LIKE '44M3.' OR
			  READ_CD LIKE '42J..' OR
			  READ_CD LIKE '44P5.' OR
			  READ_CD LIKE '44F..' OR
			  READ_CD LIKE '44P..' OR
			  READ_CD LIKE '42K..' OR
			  READ_CD LIKE '44Q..' OR
			  READ_CD LIKE '22K..' OR
			  READ_CD LIKE '44I5.' OR
			  READ_CD LIKE '42M..' OR
			  READ_CD LIKE '42N..' OR
			  READ_CD LIKE '423..' OR
			  READ_CD LIKE '42H..' OR
			  READ_CD LIKE '44M4.';



--Analysing results:
--Checking the difference of average event valuee between cases and controls on the top features

--For event value
--By mean
SELECT EVENT_CD, CASES, avg(AVG_EVT_VAL) FROM SAILW1074V.C_CASE_CTRL_FEATURES_BAL ccfb 
	WHERE EVENT_CD LIKE '44E..' OR
			  EVENT_CD LIKE '44G3.' OR
			  EVENT_CD LIKE '451E.' OR
			  EVENT_CD LIKE '44J9.' OR
			  EVENT_CD LIKE '44E..' OR
			  EVENT_CD LIKE '44G3.' OR
			  EVENT_CD LIKE '44P6.' OR
			  EVENT_CD LIKE '44J9.' OR
			  EVENT_CD LIKE '44Q..' OR
			  EVENT_CD LIKE '44P5.' OR
			  EVENT_CD LIKE '451E.' OR
			  EVENT_CD LIKE '426..' OR
			  EVENT_CD LIKE '44P6.' OR
			  EVENT_CD LIKE '44M3.' OR
			  EVENT_CD LIKE '42J..' OR
			  EVENT_CD LIKE '44P5.' OR
			  EVENT_CD LIKE '44F..' OR
			  EVENT_CD LIKE '44P..' OR
			  EVENT_CD LIKE '42K..' OR
			  EVENT_CD LIKE '44Q..' OR
			  EVENT_CD LIKE '22K..' OR
			  EVENT_CD LIKE '44I5.' OR
			  EVENT_CD LIKE '42M..' OR
			  EVENT_CD LIKE '42N..' OR
			  EVENT_CD LIKE '423..' OR
			  EVENT_CD LIKE '42H..' OR
			  EVENT_CD LIKE '44M4.'
GROUP BY EVENT_CD, CASES;
--Filter manually (cases = 1 then order by EVENT_CD, and the same for cases = 0)

--By median
SELECT EVENT_CD, CASES, median(AVG_EVT_VAL) FROM SAILW1074V.C_CASE_CTRL_FEATURES_BAL ccfb 
	WHERE EVENT_CD LIKE '44E..' OR
			  EVENT_CD LIKE '44G3.' OR
			  EVENT_CD LIKE '451E.' OR
			  EVENT_CD LIKE '44J9.' OR
			  EVENT_CD LIKE '44E..' OR
			  EVENT_CD LIKE '44G3.' OR
			  EVENT_CD LIKE '44P6.' OR
			  EVENT_CD LIKE '44J9.' OR
			  EVENT_CD LIKE '44Q..' OR
			  EVENT_CD LIKE '44P5.' OR
			  EVENT_CD LIKE '451E.' OR
			  EVENT_CD LIKE '426..' OR
			  EVENT_CD LIKE '44P6.' OR
			  EVENT_CD LIKE '44M3.' OR
			  EVENT_CD LIKE '42J..' OR
			  EVENT_CD LIKE '44P5.' OR
			  EVENT_CD LIKE '44F..' OR
			  EVENT_CD LIKE '44P..' OR
			  EVENT_CD LIKE '42K..' OR
			  EVENT_CD LIKE '44Q..' OR
			  EVENT_CD LIKE '22K..' OR
			  EVENT_CD LIKE '44I5.' OR
			  EVENT_CD LIKE '42M..' OR
			  EVENT_CD LIKE '42N..' OR
			  EVENT_CD LIKE '423..' OR
			  EVENT_CD LIKE '42H..' OR
			  EVENT_CD LIKE '44M4.'
GROUP BY EVENT_CD, CASES;
--Filter manually (cases = 1 then order by EVENT_CD, and the same for cases = 0)

-----
--For event COUNT
--By mean
SELECT EVENT_CD, CASES, avg(EVENT_COUNT) FROM SAILW1074V.C_CASE_CTRL_FEATURES_BAL ccfb 
	WHERE EVENT_CD = '44E..' OR
		  EVENT_CD = '44G3.' OR
		  EVENT_CD = '451E.' OR
		  EVENT_CD = '44J9.' OR
		  EVENT_CD = '44P6.' OR
		  EVENT_CD = '44Q..' OR
		  EVENT_CD = '44P5.'
GROUP BY EVENT_CD, CASES;
--Filter manually (cases = 1 then order by EVENT_CD, and the same for cases = 0)

--By median
SELECT EVENT_CD, CASES, median(EVENT_COUNT) FROM SAILW1074V.C_CASE_CTRL_FEATURES_BAL ccfb 
	WHERE EVENT_CD = '44E..' OR
		  EVENT_CD = '44G3.' OR
		  EVENT_CD = '451E.' OR
		  EVENT_CD = '44J9.' OR
		  EVENT_CD = '44P6.' OR
		  EVENT_CD = '44Q..' OR
		  EVENT_CD = '44P5.'
GROUP BY EVENT_CD, CASES;
--Filter manually (cases = 1 then order by EVENT_CD, and the same for cases = 0)


-----------------------
--Unbalanced dataset
--For event value
--By mean
SELECT EVENT_CD, CASES, avg(AVG_EVT_VAL) FROM SAILW1074V.CASE_CTRL_FEATURES ccf
	WHERE EVENT_CD = '44E..' OR
		  EVENT_CD = '44G3.' OR
		  EVENT_CD = '451E.' OR
		  EVENT_CD = '44J9.' OR
		  EVENT_CD = '44P6.' OR
		  EVENT_CD = '44P5.' OR
		  EVENT_CD = '44Q..' OR
		  EVENT_CD = '426..' OR
		  EVENT_CD = '42J..' OR
		  EVENT_CD = '44M3.' OR
		  EVENT_CD = '42M..' OR
		  EVENT_CD = '42A..' OR
		  EVENT_CD = '423..' OR
		  EVENT_CD = '42N..' OR
		  EVENT_CD = '44P..' OR
		  EVENT_CD = '42H..' OR
		  EVENT_CD = '246..' OR
		  EVENT_CD = '428..' OR
		  EVENT_CD = '22K..' OR
		  EVENT_CD = '42K..' OR
		  EVENT_CD = '44I5.' OR
		  EVENT_CD = '44J3.'
GROUP BY EVENT_CD, CASES;
--Filter manually (cases = 0 then order by EVENT_CD)

--By median
SELECT EVENT_CD, CASES, median(AVG_EVT_VAL) FROM SAILW1074V.CASE_CTRL_FEATURES ccf
	WHERE EVENT_CD = '44E..' OR
		  EVENT_CD = '44G3.' OR
		  EVENT_CD = '451E.' OR
		  EVENT_CD = '44J9.' OR
		  EVENT_CD = '44P6.' OR
		  EVENT_CD = '44P5.' OR
		  EVENT_CD = '44Q..' OR
		  EVENT_CD = '426..' OR
		  EVENT_CD = '42J..' OR
		  EVENT_CD = '44M3.' OR
		  EVENT_CD = '42M..' OR
		  EVENT_CD = '42A..' OR
		  EVENT_CD = '423..' OR
		  EVENT_CD = '42N..' OR
		  EVENT_CD = '44P..' OR
		  EVENT_CD = '42H..' OR
		  EVENT_CD = '246..' OR
		  EVENT_CD = '428..' OR
		  EVENT_CD = '22K..' OR
		  EVENT_CD = '42K..' OR
		  EVENT_CD = '44I5.' OR
		  EVENT_CD = '44J3.'
GROUP BY EVENT_CD, CASES;
--Filter manually (cases = 0 then order by EVENT_CD)

SELECT * FROM SAILW1074V.CASE_CTRL_FEATURES ccf
WHERE EVENT_CD = '451E.' AND
	  CASES = '0';

--For event count
--By mean
SELECT EVENT_CD, CASES, avg(EVENT_COUNT) FROM SAILW1074V.CASE_CTRL_FEATURES ccf 
	WHERE EVENT_CD = '44E..' OR
		  EVENT_CD = '44G3.' OR
		  EVENT_CD = '451E.' OR
		  EVENT_CD = '44J9.' OR
		  EVENT_CD = '44P6.' OR
		  EVENT_CD = '44Q..' OR
		  EVENT_CD = '44P5.' OR
		  EVENT_CD = '44J3.'
GROUP BY EVENT_CD, CASES;
--Filter manually (cases = 0 then order by EVENT_CD)

--By median
SELECT EVENT_CD, CASES, median(EVENT_COUNT) FROM SAILW1074V.CASE_CTRL_FEATURES ccf
	WHERE EVENT_CD = '44E..' OR
		  EVENT_CD = '44G3.' OR
		  EVENT_CD = '451E.' OR
		  EVENT_CD = '44J9.' OR
		  EVENT_CD = '44P6.' OR
		  EVENT_CD = '44Q..' OR
		  EVENT_CD = '44P5.' OR
		  EVENT_CD = '44J3.'
GROUP BY EVENT_CD, CASES;
--Filter manually (cases = 0 then order by EVENT_CD)


----------------------------------------------------------------------------------
--END OF SCRIPT
----------------------------------------------------------------------------------


----------------------------------------------------------------------------------
--Notes:
--LAG function example
SELECT *, LAG(WOB, 1) OVER (ORDER BY ALF_PE) AS test FROM SAILW1074V.DEMOGRAPHICS dm;

--Create a file sequence
SELECT ROW_NUMBER() OVER (ORDER BY ALF_PE) AS fileseq, dm.*
FROM SAILW1074V.DEMOGRAPHICS dm

CREATE SEQUENCE SAILW1074V.fileseq
START WITH 1
INCREMENT BY 1;

--INSERT IS FOR ROWS
INSERT INTO SAILW1074V.DEMOGRAPHICS (ALF_PE)
	VALUES(NEXT VALUE FOR fileseq);

DROP SEQUENCE fileseq;

--ALTER IS FOR COLUMNS
ALTER TABLE SAILW1074V.DEMOGRAPHICS
	ADD test INTEGER;


