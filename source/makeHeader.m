function makeHeader(prepare, compile)
%Generates the header files edf2mex.h which contains necessary mex structures and functions
% to read data from C structures defined in edf_data.h and load them into similarly organized
% mxArray structures.
%
% To use this, make sure that the variable 'Headers' points to the directory that includes the 
% edf header files (edf.h, edftypes.h, edf_data.h). And 'APIDir' points to the edfapi directory 
% then type 'makeHeader' at the matlab command line. Make sure these are for the same
% version of edfapi.dll you intend to use. The output is a C header file, edf2mex.h.
% If compile is set to true, makeHeader will attempt to compile the edfmex
% for you.

%     Copyright (C) 2009  Christopher K. Kovach, 2015 Christopher K. Kovach & Jonas Knöll
% 
%     This program is free software: you can redistribute it and/or modify
%     it under the terms of the GNU Affero General Public License as published by
%     the Free Software Foundation, either version 3 of the License, or
%     (at your option) any later version.
% 
%     This program is distributed in the hope that it will be useful,
%     but WITHOUT ANY WARRANTY; without even the implied warranty of
%     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%     GNU Affero General Public License for more details.
% 
%     You should have received a copy of the GNU Affero General Public License
%     along with this program.  If not, see <http://www.gnu.org/licenses/>. 

if nargin < 2
    compile=true;
end
if nargin < 1
    prepare=true;
end

if ismac
    Headers='/Library/Frameworks/edfapi.framework/Headers';
    APIDir='/Library/Frameworks/edfapi.framework';
    APIName='edfapi';
    OSCompileOptions={'LDFLAGS="\$LDFLAGS -framework edfapi"'};    
elseif ispc
    Headers='C:\Program Files (x86)\SR Research\EyeLink\EDF_Access_API\Example';
    APIDir='C:\Program Files (x86)\SR Research\EyeLink\EDF_Access_API\lib\win64';
    APIName='edfapi64';
    OSCompileOptions={['-L' APIDir],['-l' APIName]};
elseif isunix
    error('Please add the default paths for unix...')
end

if prepare
    loadlibrary([APIDir filesep APIName],[Headers filesep 'edf.h']);
    edfapi_version = calllib(APIName,'edf_get_version');
    unloadlibrary(APIName);


    %RecTypes contains information about which structure type definitions to
    %search for in the edf_data.h header. 

    %FSAMPLE type
    RecTypes.FSAMPLE.codes = {'SAMPLE_TYPE'} ;	%Constants which code for an event type that uses this structure
    RecTypes.FSAMPLE.allf_code= 'fs';           %field of ALLF_DATA union corresponding to this structure

    %FEVENT type
    RecTypes.FEVENT.codes = {'STARTPARSE','ENDPARSE','BREAKPARSE','STARTBLINK ','ENDBLINK','STARTSACC',...
        'ENDSACC','STARTFIX','ENDFIX','FIXUPDATE','MESSAGEEVENT','STARTSAMPLES','ENDSAMPLES','STARTEVENTS','ENDEVENTS'};
    RecTypes.FEVENT.allf_code= 'fe';

    %IOEVENT type
    RecTypes.IOEVENT.codes= {'BUTTONEVENT','INPUTEVENT','LOST_DATA_EVENT'}; 
    RecTypes.IOEVENT.allf_code= 'io'; 

    %RECORDINGS type
    RecTypes.RECORDINGS.codes = {'RECORDING_INFO'};
    RecTypes.RECORDINGS.allf_code = 'rec';


    %%%%%%%%%%%%%%%%%%%%%%%
    %
    % Parse edf_data.h to find all data structures described in RecTypes
    %

    fid = fopen([Headers filesep 'edf_data.h']);
    header1 = char(fread(fid,'*uchar')');
    fclose(fid);

    rectype = fieldnames(RecTypes);

    for i = 1:length(rectype)   
        RecTypes.(rectype{i}).vars = getStructTypes(header1,rectype{i}); %C structure defined in edf_data.h
    end


    %%%%%%
    %
    % Start making the header file, edf2mex.h
    %

    fid = fopen('edf2mex.h','w');

    fprintf(fid,'\n\nconst char *  build_version = "%s";\n\n',edfapi_version);

    fprintf(fid,'\nclass BuildMexArrays : public BuildMexArraysBaseClass\n{\n\n');



    fprintf(fid,'\npublic:\n\nint PopulateArrays( int Offset = 0, int MaxRec = 0 );\n');
    fprintf(fid,'\n~BuildMexArrays();\n');


    for i = 1:length(rectype)
        fprintf(fid,'\nint Nof%s;',rectype{i});
        fprintf(fid,'\nint Nmax%s;',rectype{i});
        fprintf(fid,'\nmxArray * mx%s;',rectype{i});
    end

    nSampleFields = length({RecTypes.(rectype{~cellfun(@isempty,strfind(lower(rectype),'sample'))}).vars.var});
    fprintf(fid,'\nbool loadSampleField[%i];',nSampleFields);
    fprintf(fid,'\nint nSampleFields;');

    % % fprintf(fid,'\n\nstd::string build_version ("%s");',edfapi_version);
    % fprintf(fid,'\n\nstd::string build_version;');
    % fprintf(fid,'\nbuild_version.assign("%s");',edfapi_version);
    % fprintf(fid,'\n\string curr_version (%i,"0");',length(edfapi_version));
    % fprintf(fid,'\n\nchar * curr_version = edf_get_version();');
    % 
    % fprintf(fid,'\n\nif memcmp(build_version,curr_version,%i) mexErrMsgTxt("EDFMEX is compiled for version " + curr_version + " of EDFAPI.\\n You must use run makeHeader.m and recompile EDFMEX.");\n',length(edfapi_version));

    for i = 1:length(rectype)

    %     nfield='other';
    % 	if strcmp(rectype{i},'FSAMPLE')
    %     	nfield='samples';
    % 	elseif strcmp(rectype{i},'FEVENT')
    %         nfield='events';
    %     elseif strcmp(rectype{i},'RECORDINGS')
    %         nfield='recordings';
    % 	end


        if ~isfield(RecTypes.(rectype{i}),'vars'), continue, end;
        fprintf(fid,'\n\n\n/*************************************\n*\tFunctions and objects to handle events of type %s\n*************************************/',rectype{i});

          recfields = {RecTypes.(rectype{i}).vars.var};
          recfmt = {RecTypes.(rectype{i}).vars.type};
          recfmt = regexprep(recfmt,'byte','uint8');
          recfmt = regexprep(recfmt,'float','single');


        allf_code = RecTypes.(rectype{i}).allf_code;

        %Create a structure that contains data type arrays (which can be passed
        %to mex)

            fprintf(fid,'\n\n struct \t%stype\n{\n\tconst char * fieldnames[%i];',rectype{i}, length(recfields));
            if ~isempty(strfind(lower(rectype{i}),'sample'))

                for rf = 1:length(recfields)    
                        fprintf(fid,'\n\t%s* %s;',recfmt{rf},recfields{rf});
                end
            end
            fprintf(fid,'\n\n\t%stype(){\n',rectype{i});
            for j = 1:length(recfields)
                fprintf(fid,'\n\t\t\tfieldnames[%i] = "%s";',j-1,recfields{j});
            end

            fprintf(fid,'\n\t};\n\n} str%s;',rectype{i});


         %%%%%%%%%%%%%%%%%%%%%%%
         %
         % Functions to append data 
         %
        fprintf(fid,'\n\nint mx%sappend()\n{',rectype{i});

        if ~isempty(strfind(lower(rectype{i}),'sample'))


            for j = 1:length(recfields)
                fprintf(fid,'\n\tif(loadSampleField[%i])',j-1);
                dim = RecTypes.(rectype{i}).vars(j).dim ; 
                if dim(1) > 1
                     fprintf(fid,'\n\t\tmemcpy( &(str%s.%s[%i*Nof%s]) ,  &(CurrRec->%s.%s[0]), %i*sizeof(%s));',...
                        rectype{i},recfields{j},dim(1),rectype{i},allf_code ,recfields{j},dim(1),recfmt{j});             
                else
    %                     fprintf(fid,'\n\t str%s.%s[Nof%s] = CurrRec->%s.%s;',...
                        fprintf(fid,'\n\t\tmemcpy( &(str%s.%s[Nof%s]) , &(CurrRec->%s.%s), %i*sizeof(%s));',...
                            rectype{i},recfields{j},rectype{i},allf_code ,recfields{j},dim(1),recfmt{j});             
                end


            end
        else

            fprintf(fid,'\n\n\tif(Nmax%s<=Nof%s){',rectype{[i i]});
                fprintf(fid,'\n\t\tint oldMax = Nmax%s;',rectype{i});
                fprintf(fid,'\n\t\tNmax%s=1 + 1.1*Nmax%s;',rectype{[i i]});
                fprintf(fid,'\n\t\tmxSetData(mx%s, mxRealloc(mxGetData(mx%s), Nmax%s * %i *sizeof(mxArray *)));',rectype{[i i i]},length({RecTypes.(rectype{i}).vars.var})+1);
                fprintf(fid,'\n\t\tmxSetN(mx%s,Nmax%s);',rectype{[i i]});
                fprintf(fid,'\n\t\tfor(int i=oldMax; i<Nmax%s; i++){',rectype{i});
                    fprintf(fid,'\n\t\t\tfor(int j=0; j < %i; j++) {',length({RecTypes.(rectype{i}).vars.var})+1);
                              fprintf(fid,'\n\t\t\t\tmxSetFieldByNumber(mx%s, i, j, NULL);',rectype{i});
                    fprintf(fid,'\n\t\t\t}');
                fprintf(fid,'\n\t\t}');
            fprintf(fid,'\n\t}');

            for j = 1:length(recfields)
                dim = RecTypes.(rectype{i}).vars(j).dim ; 

                if strcmp(recfmt{j} , 'LSTRING')  
                       fprintf(fid,'\n\n\tif (CurrRec->%s.%s != NULL) mxSetField(mx%s, Nof%s, "%s",  mxCreateString(  &(CurrRec->%s.%s->c) ) );',...
                           allf_code ,recfields{j},rectype{[i i]}, recfields{j},allf_code ,recfields{j});

                else

                    fprintf(fid,'\n\n\tmxSetFieldByNumber(mx%s, Nof%s, %i,  mxCreateNumericMatrix(%i,1, mx%s_CLASS,mxREAL));',...
                    rectype{[i i]},j-1,dim(1),upper(recfmt{j}));
                    fprintf(fid,'\n\tmemcpy(mxGetData(mxGetFieldByNumber(mx%s, Nof%s, %i)) ,&(CurrRec->%s.%s),%i*sizeof(mx%s_CLASS) );',...
                    rectype{[i i]},j-1,allf_code,recfields{j},dim,upper(recfmt{j}));
                end


            end
            fprintf(fid,'\n\tmxSetField(mx%s, Nof%s, "codestring",  mxCreateString(GetRecordCodeStr(GetDataCode())));',rectype{[i i]});

        end

            fprintf(fid,'\n\n\tNof%s++;',rectype{i});

            fprintf(fid,'\n\n\treturn 0;\n\n};');


    end    


    fprintf(fid,'\n\nconst char * GetRecordTypeStr(int CODE)\n{');
    fprintf(fid,'\n\n\tswitch(CODE) {');

    for i = 1:length(rectype)
        reccodes = RecTypes.(rectype{i}).codes;

        for j = 1:length(reccodes)
            fprintf(fid,'\n\t\tcase %s:',reccodes{j});
        end
        fprintf(fid,'\n\t\t\treturn "%s";',rectype{i});
    end

    fprintf(fid,'\n\t}\n\n\treturn NULL;');

    fprintf(fid,'\n\n};\n\n');

    %%%%%%%%%%%%
    %
    %   Switch that decides which append function to call based on code

    fprintf(fid,'\n\nint AppendRecord()\n{');
    fprintf(fid,'\n\n\tCurrRec = edf_get_float_data( edfptr);'); 

    fprintf(fid,'\n\n\tswitch(DataCode) {');

    for i = 1:length(rectype)
        if ~isfield(RecTypes.(rectype{i}),'vars'), continue, end;
        reccodes = RecTypes.(rectype{i}).codes;

        for j = 1:length(reccodes)
            fprintf(fid,'\n\t\tcase %s:',reccodes{j});
        end

        if strcmp(rectype{i},'IOEVENT')
            %The data in FEVENT is actually relevant, just call both
            fprintf(fid,'\n\t\t\treturn mxFEVENTappend()+mx%sappend();',rectype{i});
        else
            fprintf(fid,'\n\t\t\treturn mx%sappend();',rectype{i});
        end
    end

    fprintf(fid,'\n\t}\n\n\treturn 0;');

    fprintf(fid,'\n\n};\n\n');

    %%%%%%%%%%
    %
    % Function that returns a string descriptor for each code

    fprintf(fid,'\n\nconst char * GetRecordCodeStr(int CODE)\n{');
    fprintf(fid,'\n\n\tswitch(CODE){');

    for i = 1:length(rectype)
        reccodes = RecTypes.(rectype{i}).codes;

        for j = 1:length(reccodes)
            fprintf(fid,'\n\t\tcase %s:',reccodes{j});
            fprintf(fid,'\n\t\t\treturn "%s";',reccodes{j});
        end
    end

    fprintf(fid,'\n\t}\n\n\treturn NULL;');

    fprintf(fid,'\n\n};\n\n');



    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % CONSTRUCTOR

    fprintf(fid,'\n\nBuildMexArrays( char * filenamein , int consistency_check , int load_events  , const mxArray * load_samples)\n{');

    for j = 1:length(rectype)

        fprintf(fid,'\n\tRecordTypes[%i] = "%s";',j-1,rectype{j});
    end

         fprintf(fid,'\n\n\tnSampleFields = %i;',nSampleFields);
         fprintf(fid,'\n\tint load_any_samples;');

         fprintf(fid,'\n\tmwSize nDims = mxGetNumberOfDimensions(load_samples);');
         fprintf(fid,'\n\tconst mwSize *dimSizes =  mxGetDimensions(load_samples);');
         fprintf(fid,'\n\tint length=1;');
         fprintf(fid,'\n\tfor( int j=0; j<nDims; j++){');
            fprintf(fid,'\n\t\tlength*=dimSizes[j];');
         fprintf(fid,'\n\t}');

         fprintf(fid,'\n\tif(mxIsDouble(load_samples)){');
             fprintf(fid,'\n\t\tdouble * load_samples_data = mxGetPr(load_samples);');
             fprintf(fid,'\n\t\tif(length==1){');
                fprintf(fid,'\n\t\t\tload_any_samples = load_samples_data[0];');
                fprintf(fid,'\n\t\t\tfor(int j=0;j<nSampleFields;j++){');
                    fprintf(fid,'\n\t\t\t\tloadSampleField[j] = load_any_samples;');
                fprintf(fid,'\n\t\t\t}');
             fprintf(fid,'\n\t\t}else{');
                 fprintf(fid,'\n\t\t\tfor(int j=0;j<nSampleFields;j++){');
                    fprintf(fid,'\n\t\t\t\tif(j<length){');
                        fprintf(fid,'\n\t\t\t\t\tloadSampleField[j] = load_samples_data[j];');
                        fprintf(fid,'\n\t\t\t\t\tif(loadSampleField[j]){');
                            fprintf(fid,'\n\t\t\t\t\t\tload_any_samples = true;');
                        fprintf(fid,'\n\t\t\t\t\t}');
                    fprintf(fid,'\n\t\t\t\t}else{');
                        fprintf(fid,'\n\t\t\t\t\tloadSampleField[j] = false;');
                    fprintf(fid,'\n\t\t\t\t}');
                fprintf(fid,'\n\t\t\t}');
             fprintf(fid,'\n\t\t}');

            fprintf(fid,'\n\t}else if(mxIsCell(load_samples)){');
                fprintf(fid,'\n\t\tchar* cellstr;');
                fprintf(fid,'\n\t\tfor(int k=0;k<nSampleFields;k++){');
                    fprintf(fid,'\n\t\t\tloadSampleField[k] = false;');
                    fprintf(fid,'\n\t\t\tfor(int j=0;j<length;j++){');
                        fprintf(fid,'\n\t\t\t\tcellstr = mxArrayToString(mxGetCell(load_samples,j));');
                        fprintf(fid,'\n\t\t\t\tif(strcmp(cellstr, strFSAMPLE.fieldnames[k])==0){');
                            fprintf(fid,'\n\t\t\t\t\tloadSampleField[k] = true;');
                            fprintf(fid,'\n\t\t\t\t\tbreak;');
                        fprintf(fid,'\n\t\t\t\t}');
                    fprintf(fid,'\n\t\t\t}');
            fprintf(fid,'\n\t\t}');
        fprintf(fid,'\n\t}');

    fprintf(fid,'\n\n\tInitialize( filenamein , consistency_check , load_events  , load_any_samples);\n');

    fprintf(fid,'\n\n\tOutputMexObject = mxCreateStructMatrix(1,1,%i,RecordTypes);\n',length(rectype));

    for i = 1:length(rectype)

        fprintf(fid, '\n\n\n\tNof%s = 0;', rectype{i});

        if ~isfield(RecTypes.(rectype{i}),'vars'), continue, end;

          recfields = {RecTypes.(rectype{i}).vars.var};
          recfmt = {RecTypes.(rectype{i}).vars.type};
          recfmt = regexprep(recfmt,'byte','uint8');
          recfmt = regexprep(recfmt,'float','single');

        if ~isempty(strfind(lower(rectype{i}),'sample'))

            fprintf(fid, '\n\n\n\tNmax%s = loadSamples? Nrec: 0;', rectype{i});

            fprintf(fid,'\n\n\t mx%s = mxCreateStructMatrix(1,1,%i,str%s.fieldnames);',rectype{i},length(recfields),rectype{i});

            for j = 1:length(recfields)

                dim = RecTypes.(rectype{i}).vars(j).dim ; 
                       fprintf(fid,'\n\n\tmxSetFieldByNumber( mx%s,0,%i,  mxCreateNumericMatrix(%i,loadSampleField[%i]?Nmax%s:0, mx%s_CLASS,mxREAL) );',...
                          rectype{i},j-1,dim(1),j-1, rectype{i},upper(recfmt{j}));
                        fprintf(fid,'\n\tstr%s.%s = (%s *) mxGetData( mxGetFieldByNumber(mx%s,0,%i) );',...
                        rectype{i},recfields{j},recfmt{j},rectype{i},j-1);
            end



        else
            if ~isempty(strfind(lower(rectype{i}),'fevent'))
                fprintf(fid, '\n\n\n\tNmax%s = loadSamples? Nrec*0.02: Nrec;', rectype{i});
                fprintf(fid, '\n\n\n\tNmax%s = loadEvents? Nmax%s: 2;', rectype{i},rectype{i});
            else
                fprintf(fid, '\n\n\n\tNmax%s = 10;', rectype{i});
            end

            fprintf(fid,'\n\n\t mx%s = mxCreateStructMatrix(1,Nmax%s,%i,str%s.fieldnames);',rectype{[i i]},length(recfields),rectype{i});
            fprintf(fid,'\n\n\t mxAddField(mx%s,"codestring");',rectype{i});


        end

    end

    fprintf(fid,'\n\n};');

    %%%%%%%%%%%%%%%%%%%%%%%%%%%
    %
    % Function that sets the output structure.

    fprintf(fid,'\n\nint CreateMexStruc()\n{');


    for i = 1:length(rectype)
        if ~isfield(RecTypes.(rectype{i}),'vars'), continue, end;

        if ~isempty(strfind(lower(rectype{i}),'sample'))
            recfields = {RecTypes.(rectype{i}).vars.var};
            recfmt = {RecTypes.(rectype{i}).vars.type};
            recfmt = regexprep(recfmt,'byte','uint8');
            recfmt = regexprep(recfmt,'float','single');

            for j = fliplr(1:length(recfields))
                fprintf(fid,'\n\tif(loadSampleField[%i]){',j-1);
                    fprintf(fid,'\n\t\tmxSetData( mxGetFieldByNumber( mx%s,0,%i), mxRealloc(mxGetData( mxGetFieldByNumber( mx%s,0,%i)), Nof%s *sizeof(mx%s_CLASS)));',rectype{i},j-1,rectype{i},j-1,rectype{i},upper(recfmt{j}));
                    fprintf(fid,'\n\t\tmxSetN(mxGetFieldByNumber(mx%s,0,%i),Nof%s);',rectype{i},j-1,rectype{i});
                fprintf(fid,'\n\t}else{');
                    fprintf(fid,'\n\t\tmxRemoveField(mx%s, %i);',rectype{i},j-1);
                fprintf(fid,'\n\t}');

            end
            fprintf(fid,'\n');
        else
         fprintf(fid,'\n\n\tmxSetData(mx%s, mxRealloc(mxGetData(mx%s), Nof%s * %i *sizeof(mxArray *)));', rectype{[i i i]},length({RecTypes.(rectype{i}).vars.var})+1);
         fprintf(fid,'\n\tmxSetN(mx%s,Nof%s);',rectype{[i i]});
        end
         fprintf(fid,'\n\tmxSetField(OutputMexObject,0,"%s",mx%s);',rectype{[i i]});

    end
    fprintf(fid,'\n\n\treturn 0;\n};');
    fprintf(fid,'\n\n};//end of class def\n\n');

    fclose(fid);
end

if compile
    mex('-largeArrayDims', 'edfmex.cpp', ['-I"' Headers '"'], '-output', ['"..' filesep 'edfmex"'], OSCompileOptions{:});
end

%%%%%%%%%%%%%%%%%

function D = getStructTypes(str,strDef)

% This function parses the variables inside the object identified by
% strDef.

a = regexp(str,sprintf('{([^}]*)}\\s*%s',strDef),'tokens');
b = regexp(a{1}{1},'\n[^\w/]*(\w+)\s*([^;]*)','tokens');
bs = cat(1,b{:});
types = bs(:,1);
vars = bs(:,2);

c = regexp(vars,'(\w+)\[?(\d*\s*\d*)\]?','tokens');


D = struct([]);
for i = 1:length(c)
    for j = 1:length(c{i})
        D(end+1).var = c{i}{j}{1};
        D(end).type = types{i};
        if isempty( c{i}{j}{2})
            D(end).dim = 1;
        else
            D(end).dim = str2double(c{i}{j}{2});
        end
    end
end