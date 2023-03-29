* Created 2023-02-16 by Rebecca Joseph, University of Nottingham
*************************************
* Name:	joinsplit.do
* Creator:	RMJ
* Date:	20230216	
* Desc: Splits prescription records into periods of overlapping exposure
*
* Notes: 
* Version History:
*	Date	Reference	Update
* 20220720	new file	DRAFT FILE CREATED
* 20220825	prep_polypharmacycount	Add formulation into the grouping 
* 20221003	prep_polypharmacycount	Additional steps for 1mpre and 1mpost datasets
* 20221003	prep_polypharmacycount	Add use USING to ~line 61 for efficiency
* 20221012	prep_polypharmacycount	(NEW VERSION) Just prep sliced dataset
* 20221012	prep_polypharmacycount_v2	Include issueseq to flag repeats	
* 20221012	prep_polypharmacycount_v2	Make 3 versions of count variable	
* 20221012	prep_polypharmacycount_v2	Write loop for combining all counts
* 20230209	prep_polypharmacycount_v2	Adapt for polypharm
* 20230209	prep_polypharmacycount_v2	Rename
* 20230209	prep_prescriptioncount	Calculate presc dur before splitting
* 20230209	prep_prescriptioncount	Remove previous code for number of prescs
* 20230213	prep_prescriptioncount	Write as program include dropping short overlaps
* 20230215	prep_prescriptioncount	Finish joinsplit version 2 allowing min overlap
* 20230216	prep_prescriptioncount	Finish clean version of script
* 20230216	prep_prescriptioncount	Drop/truncate AFTER running joinsplit
* 20230216	prep_prescriptioncount	Cut and save joinsplit as separate file
*************************************

**# DEFINE PROGRAM TO SPLIT THE DATASET AT OVERLAPS
	*** Splits follow-up into distinct periods of overlapping exposure:**
	*	AAAAAAAAAAAAA													*
	*	    BBBBB														*
	*																	*
	* Becomes															*
	*																	*
	*	AAAA															*
	*	    AAAAA														*
	*		BBBBB														*
	*	         AAAA													*
	*																	*
	* If minoverlap is specified (>1) then records are truncated 		*
	* (dropped) when the overlap is too short. The output can be used 	*
	* to find the maximum number of overlapping records having accounted*
	* for the min overlap. 												*
	* EXAMPLE:															*
	*	AAAAAA															*
	*	     BBBBBBBB													*
	*	        CCCC													*
	*  with minoverlap 2 becomes:										*
	*	AAAAA															*
	*	     BBB														*
	*	        BBBB													*
	*	        CCCC													*
	*	            B													*
	*	1111111122221 (prescription counts)								*
	*																	*	
	* IMPORTANT: the *duration* of the exposure windows may				*
	* get adjusted so if minoverlap>1 the output shouldn't be used		*
	* to calculate the exposure times for each combination.	e.g. below	*
	*																	*	
	* EXAMPLE 2:														*
	*	AAAAA															*
	*	   BBBBBBB														*
	*	    CCCC														*
	*  with minoverlap 2 becomes:										*
	*	AAAA															*
	*	   B															*
	*	    BBBB														*
	*	    CCCC														*
	*	        BB														*
	*	1112222211 (prescription counts)								*
	*																	*	
	*********************************************************************

*** Specify which variables to group prescriptions by.
*** Optionally, specify a minimum overlap. Records/overlaps that don't
*** reach this will be dropped.
capture program drop joinsplit
program define joinsplit
	
	version 17.0
	syntax , GROUPby(varlist) [MINOverlap(integer 1)]
	
	display "Minimum overlap: `minoverlap'"
	display "Group prescriptions by: `groupby'"
	
	** PART 1 - simplify by combining overlapping records for the same drug
	*** When two records overlap, sets start date of SECOND record to start date of FIRST,
	*** then drops the FIRST record. Repeats until there are no more overlaps.
	di as result "Combining sequential records"
	sort patid `groupby' start stop
	by patid `groupby': gen prevstop=stop[_n-1] if _n!=1
	count if start<=prevstop & prevstop!=.

	while `r(N)'>0 {
		by patid `groupby': replace start=start[_n-1] if start<=prevstop & _n!=1
		bys patid `groupby' start (stop): keep if _n==_N
		
		drop prevstop
		sort patid `groupby' start stop
		by patid `groupby': gen prevstop=stop[_n-1] if _n!=1
		count if start<=prevstop & prevstop!=.	
	}

	drop prevstop
	sort patid start stop `groupby'
	
	*** Having combined records, drop any durations<minoverlap
	gen dur_comb=stop-start
	drop if dur_comb<`minoverlap'
	drop dur_comb
	

	
	
	*** Loops until there are no more overlapping records to split
	*** !! always sort on start and stop
	
	** PART 2 - identifying when new overlapping prescriptions start
	di as result "Splitting at every instance of a new (overlapping) prescription"
	
	*** When there are overlapping records find the next DIFFERENT start date 
	*** (i.e. if two seq records have same start date, ignore & find next)
	*** If stop is after nextstart, duplicate.
	*** For original record, set stop date to nextstart
	*** For duplicate record, set start date to nextstart
	*** (i.e. splits the FIRST record into time BEFORE overlap and time during
	*** overlap.)
	*** If the overlap (i.e. DUPLICATE record) is shorter than minoverlap,
	*** drop it. The ORIGINAL record may be <minoverlap - this is ok.		
	sort patid start stop `groupby'
	by patid: gen nextstart=start[_n+1]
	by patid start: replace nextstart=nextstart[_N]
	
	count if nextstart<stop
		
	local counter 0	
	while `r(N)'!=0 {
	
		local counter = `counter' + 1
		di as result "Loop no: `counter'"
		
		gen exp=1
		replace exp=2 if nextstart<stop
		expand exp, gen(new)
		replace stop=nextstart if exp==2 & new==0
		replace start=nextstart if exp==2 & new==1
		
		drop if exp==2 & new==1 & (stop-start)<`minoverlap'	// here is where short overlaps are dropped
		
		drop nextstart exp new
		
		sort patid start stop `groupby'
		by patid: gen nextstart=start[_n+1]
		by patid start: replace nextstart=nextstart[_N]
		
		count if nextstart<stop
	
	}
	
	drop nextstart
	
	
	
	** PART 3 - identifying when previously overlapping prescriptions end
	di as result "Splitting at every instance of a (overlapping) prescription stopping"

	*** When there are records that start on the same day but stop on different 
	*** days, duplicate the SECOND record. For the original record, set stop to
	*** prevstop. For duplicate record, set start to prevstop.
	*** (i.e. splits the SECOND record into time during overlap and time AFTER
	*** overlap.)
	sort patid start stop `groupby'
	by patid: gen prevstart=start[_n-1]
	by patid: gen prevstop=stop[_n-1]
	
	count if start==prevstart & prevstop<stop
	
	local counter 0
	while `r(N)'!=0 {
		
		local counter = `counter' + 1
		di as result "Loop no: `counter'"
		
		gen exp=1
		replace exp=2 if start==prevstart & prevstop<stop
		expand exp, gen(new)
		replace stop=prevstop if new==0 & exp==2
		replace start=prevstop if new==1 & exp==2
		drop prevstart prevstop exp new

		sort patid start stop `groupby'
		by patid: gen prevstart=start[_n-1]
		by patid: gen prevstop=stop[_n-1]	
		
		count if start==prevstart & prevstop<stop
	
	}
	
	drop prevstart prevstop 
	
end
******	

