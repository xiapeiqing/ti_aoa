function complex_data = loadTIexampleSTREAMdata(fname)
fclose all;
NUM_AOA_SAMPLES = 512;
complex_data = [];
MetaData = [];
if nargin == 0
    fname = 'C:\code\AoA\datalog\log1.txt';
end
fid=fopen(fname);
ComplexMeasCnt = 0;
fileLineCnt = 0;
state = 0; 
% 0: expect A1
% 1: expect p4,c37
% 2: expect (5, -3), NUM_AOA_SAMPLES lines
% 3: expect .
thisMetaData = zeros(1,3);
AOA_SAMPLEgroupDat = zeros(1,NUM_AOA_SAMPLES);
while 1
    tline = fgetl(fid);
    if ~ischar(tline)
        break;
    end
    fileLineCnt = fileLineCnt + 1;
    if fileLineCnt == 35
        tt = 1;
    end
    switch state
        case 0
            if tline(1) == 'A'
                decoded = sscanf(tline,'A%d\n');
                if length(decoded) == 1
                    thisMetaData = zeros(1,3);
                    thisMetaData(1) = decoded;
                    state = 1;
                end
            end
        case 1
            if tline(1) == 'p'
                ComplexMeasCnt = 0;
                decoded = sscanf(tline,'p%d,c%d\n');
                if length(decoded) == 2
                    thisMetaData(2:3) = decoded;
                    state = 2;
                else
                    state = 0;
                end
            else
                state = 0;
            end
        case 2
            decoded = sscanf(tline,'(%d, %d),');
            if length(decoded) == 2
                ComplexMeasCnt = ComplexMeasCnt + 1;
                AOA_SAMPLEgroupDat(ComplexMeasCnt) = decoded(1) + 1j*decoded(2);
            else
                state = 0;
            end
            if ComplexMeasCnt == NUM_AOA_SAMPLES
                state = 3;
            end 
        case 3
            if tline(1) == '.'
                complex_data = [complex_data;AOA_SAMPLEgroupDat];
                MetaData = [MetaData thisMetaData];
            else
                disp(tline);
            end
            state = 0;
    end
end
fclose(fid);
fprintf(1,'file has %d lines, %f%% valid\n',fileLineCnt,100*size(complex_data,1)*NUM_AOA_SAMPLES/fileLineCnt);
disp(size(complex_data));