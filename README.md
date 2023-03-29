# UoN_ExposureMatrix
Stata do-file that splits follow-up whenever a different exposure starts and stops, allowing counts of different exposures at a particular time to be calculated.

The files in this repository were designed and written by researchers at the University of Nottingham. They were created for projects funded by the National Institute for Health and Care Research Nottingham Biomedical Research Centre. Any views expressed are those of the author(s) and not necessarily those of the NIHR or the Department of Health and Social Care.

## Overview and user guide
The file joinsplit.do defines a program that splits a person's follow-up whenever a different exposure starts and stops. For example, considering a person's prescription history, they might have many prescription records for different medicines, each with a start and stop date. joinsplit will generate new records after cutting follow-up whenever a new medicine starts or existing medicine stops. This was developed so that the total number of medicines with active prescriptions at any particular time could be counted, but there may be uses beyond this. The code was developed using data from CPRD GOLD, but should run on any dataset in the correct format.

To use the code, first run "joinsplit.do" to define the program joinsplit. Then run joinsplit as described below.

## Requirements
* Stata
* A dataset with the following variables:

|variable name   |description|
|----------------|-----------|
|patid           |identifier for unique individuals in the dataset|
|start           |numerical start date|
|stop            |numerical stop date|
|[group variable]|one or more variables indicating different exposures, e.g. prodcode formulation|

## joinsplit
**Syntax**

`joinsplit, groupby(varlist) [minoverlap(integer 1)]`

**Options**
|option                   |description|
|-------------------------|-----------|
|**group**by(_varlist_)   |variable list indicating the different levels of exposure to group by|
|**mino**verlap(_integer_)|integer showing the minimum number of days that different exposures should overlap to be counted (default 1)|

**Description**

**joinsplit** was written so that the number of overlapping prescriptions for different medicines at any one time could be counted. Part of this was allowing a minimum duration of overlap, e.g. the number of different medicines that overlapped for at least 14 days. **joinsplit** splits an individual's follow-up into different periods according to which exposures had active prescriptions at that time. It does this by splitting follow-up whenever a different exposure starts or existing exposure stops. The resulting dataset allows the user to calculate the number of different medicines (or other exposures of interest) were present at any of the periods of follow-up. Changing the value of the option **minoverlap** allows the user to specify the minimum overlap of interest. If **minoverlap**>1, the durations of the time windows in the final dataset should not be calculated as some days are dropped in the process. Furthermore, the final duration for each window may be less than **minoverlap** - this is ok, the remaining records reflect the _total_ exposure time.

**Examples**

`joinsplit, groupby(prodcode)`

`joinsplit, groupby(drugnamecode formulation) minoverlap(14)`
