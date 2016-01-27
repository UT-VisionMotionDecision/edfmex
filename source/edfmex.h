/*
     Copyright (C) 2007  Christopher K. Kovach
 
     This program is free software: you can redistribute it and/or modify
     it under the terms of the GNU Affero General Public License as published by
     the Free Software Foundation, either version 3 of the License, or
     (at your option) any later version.
 
     This program is distributed in the hope that it will be useful,
     but WITHOUT ANY WARRANTY; without even the implied warranty of
     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
     GNU Affero General Public License for more details.
 
     You should have received a copy of the GNU Affero General Public License
     along with this program.  If not, see <http://www.gnu.org/licenses/>. 
*/



#pragma once

#ifndef single
#define single float
#endif


#include "mex.h"
#include "matrix.h"
#include <stdlib.h>
#include <vector>

#include "edf.h"
#include "edf_data.h"
#include "edftypes.h"



//Base class for the BuildMexArrays class (which is defined in edf2mex.h)
class BuildMexArraysBaseClass 
{

public:

	int DataCode;
	int fileError;
	int Nrec;
    bool loadSamples;
    bool loadEvents;
	char * FileName;
	const char * RecordTypes[100];

	EDFFILE* edfptr;
	ALLF_DATA * CurrRec;
	mxArray * OutputMexObject;
	int Initialize( char * filenamein , int consistency_check , int load_events  , int load_samples);
	
		
	int InitializeMexArrays();

	int CreateMexArrays();

	int IncrementRecord();

	int AppendRecord();  //defined in edf2mex.h

	int GetDataCode();
};



int BuildMexArraysBaseClass::IncrementRecord()
{
	DataCode = edf_get_next_data( edfptr);	//Calls eyelink API and steps to next record
//	CurrRec = edf_get_float_data( edfptr); 
	return 0;
};


int BuildMexArraysBaseClass::Initialize( char * filenamein, int consistency_check , int load_events  , int load_samples )
{
	fileError = 0;
	
	FileName = filenamein;

    try
    {
        edfptr = edf_open_file(FileName ,  consistency_check ,  load_events  ,  load_samples , &fileError);
        if (edfptr == NULL) throw 0;
    }
    catch(int)
    {
        mexErrMsgTxt("Failed to open file.");
    }
    Nrec = edf_get_element_count(edfptr); //Number of records
    
    loadSamples=load_samples;
    loadEvents=load_events;
    
	return 0;
};

int BuildMexArraysBaseClass::GetDataCode()
{
	return DataCode;
};

