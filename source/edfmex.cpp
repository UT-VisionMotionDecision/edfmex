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

//#pragma once


//#define _CRTDBG_MAP_ALLOC
//#include <stdlib.h>
//#include <crtdbg.h>
#include <stdio.h>
#include <iostream>
#include <string>
#include "edfmex.h"
#include "edf2mex.h"

 BuildMexArrays::~BuildMexArrays() //The rest of this class is defined in edf2mex.h
{
    edf_close_file(edfptr);
    
 };
 
 int BuildMexArrays::PopulateArrays( int Offset, int MaxRec) 
{	
	int modtest = 0;
	int done = 0;
	int stepsize = 100; //size of displayed steps is 100./stepsize
	
	std::string curr_version;
	curr_version.assign(edf_get_version());

	std::string  str1 ("EDFMEX is compiled for this version of the EDF API:\n\n");
	std::string str2 ("\n\nYou must use run makeHeader.m and recompile EDFMEX with header files and\nlibraries for current version:\n\n");
	std::string errstr;
	errstr = str1 + build_version + str2 + curr_version;
	
	if ( curr_version.compare(build_version) ) mexErrMsgTxt( errstr.c_str() );

	mexPrintf("Loading:%3i%%",0);

	for (int i = 0 ; ( MaxRec == 0 && i < Nrec ) || i < MaxRec  ; i++ )	
	{
		IncrementRecord();
		if (Offset == 0 || i >= Offset) 
		{
			AppendRecord();
			done = ( i - Offset + 1) * stepsize / (Nrec - Offset); 
			if ( done  >  modtest )
			{
				mexPrintf("\b\b\b\b%3i%%",done*100/stepsize);
				mexEvalString("drawnow");
				modtest++;
			};
		};

	};
    
	mexPrintf("\n");
	char headertext[1000];
	
	edf_get_preamble_text(edfptr, headertext, 1000);
	mxAddField(OutputMexObject,"HEADER");
	mxSetField(OutputMexObject,0,"HEADER",mxCreateString(headertext));
	mxAddField(OutputMexObject,"FILENAME");
	mxSetField(OutputMexObject,0,"FILENAME",mxCreateString(FileName));
    
	return 0;

};

int load_events = 1;
int consistency_check = 1;
mwSize countN;

int err = 0;

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{
    int MaxRec = 0;
    int Offset = 0;
    
	char FileName[200];

	int chk;
	chk = mxGetString(prhs[0], FileName, mxGetNumberOfElements(prhs[0])+1);
	if (chk == 1) mexErrMsgTxt("Not a valid string");
	
    const mxArray * load_samples;
	
    if (  nrhs >= 2) Offset = *mxGetPr(prhs[1]);
	if (  nrhs >= 3) MaxRec = *mxGetPr(prhs[2]);
	if (  nrhs >= 4){
        load_samples = prhs[3];
    }else{
        load_samples = mxCreateDoubleScalar(1);
    }
	if (  nrhs >= 5) load_events = *mxGetPr(prhs[4]);
	if (  nrhs >= 6) consistency_check   = *mxGetPr(prhs[5]);

	BuildMexArrays BuildMex( FileName , (int) consistency_check , (int) load_events  ,load_samples);
    
	BuildMex.PopulateArrays( Offset, MaxRec );
	BuildMex.CreateMexStruc();

    
	plhs[0] = BuildMex.OutputMexObject;
	 
	nlhs = 1;

	//_CrtDumpMemoryLeaks();


};
	
