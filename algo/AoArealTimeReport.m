function AoAsmoothedDeg = AoArealTimeReport(hack2processExistFile,newLUT)
if nargin < 2
    newLUT = true;
else
    newLUT = false;
end
standaloneCall = false;
if nargin < 1
    close all;
    hack2processExistFile = true; % true false
    standaloneCall = true;
else
    hack2processExistFile = false;
end

global X;
if newLUT
    etlogFolder = 0;
else
    etlogFolder = 6;
end
algo = 'drop2AndCompared';
LUTdatasetCategory = 'Lab';
[~,strProcessedResultFolder,~,~] = globalSettings_datasetSpecific(LUTdatasetCategory,etlogFolder);
BLDCctrlCmd = 0;
close all;
fileCnt = 0;

upate it later!!!!! savedResultFile = sprintf('%sanaRTaoa_%d_%s.mat',strProcessedResultFolder,etlogFolder,algo);
if ~exist(savedResultFile,'file')
    while 1
        python2matlabStatusFile = [X.realtimeLogFolder 'pcPython2matlabLUTrawdataRdy.txt'];
        if exist(python2matlabStatusFile,'file')
            pause(5);
            delete(python2matlabStatusFile);
            break;
        else
            pause(1);
        end
    end
end
[muLUTs,sigmaLUTs,LUTangleDeg,allmuRSSI,allstdRSSI] = buildLUT(LUTdatasetCategory,etlogFolder,'Log_*.dat',algo);
if ~hack2processExistFile
    writeBLDCcmdFile(0);
end
logIndex0 = 0;
if hack2processExistFile
    allLogs = dir([X.realtimeLogFolder 'LogGovernerMode*.dat']);
    result = zeros(length(allLogs)*X.datasetSpecific.AoArcvSPIlogPktCnt/2,2);
else
    result = zeros(10000,2);
end
while 1
    if ~rawDataRdy() && ~hack2processExistFile
        pause(0.1)
    else
        while 1
            if exist([X.realtimeLogFolder 'LogGovernerMode.dat'],'file') || hack2processExistFile
                pause(0.1);
                break;
            end
        end
        if hack2processExistFile
            if logIndex0+1 > length(allLogs)
                break;
            end
            currFileName = [X.realtimeLogFolder allLogs(logIndex0+1).name];
        else
            currFileName = sprintf('%sLogGovernerMode%2d.dat',X.realtimeLogFolder,logIndex0);
            movefile([X.realtimeLogFolder 'LogGovernerMode.dat'],currFileName);
        end
        sdgfsdfgsdgsdfgsd [valid,PhsDiffRad,PhsStd,muRSSI,stdRSSI,ValidSampleRatio,antArrSDpairsPhs] = ProcessBatch128uS_log(currFileName,'',hack2processExistFile);
        if valid
            for pktii = 1:X.datasetSpecific.AoArcvSPIlogPktCnt/2
                meas = squeeze(antArrSDpairsPhs(:,pktii,:));
                meas = meas(:)';
                PosDeg = estimatePos(muLUTs,sigmaLUTs,LUTangleDeg,meas,'drop2AndCompared');
                thisres = [BLDCctrlCmd, PosDeg];
                result(logIndex0*X.datasetSpecific.AoArcvSPIlogPktCnt/2+pktii,:) = thisres;
            end
            BLDCctrlCmd = Pos2ctrl(PosDeg,BLDCctrlCmd,logIndex0);
            writeBLDCcmdFile(BLDCctrlCmd);
            logIndex0 = logIndex0 + 1;
        else
            if ~hack2processExistFile
                writeBLDCcmdFile(BLDCctrlCmd);
            end
        end
    end
end
truthDeg = mod(result(:,1)/14,360);
estDeg = result(:,2);
visualizeAoAeachPkt(estDeg,truthDeg,'realtimeAoA','realtimeAoA');
end

function BLDCctrlCmd = Pos2ctrl(PosDeg,lastBLDCctrlCmd,logIndex0)
    subii0 = mod(logIndex0,19);
    integerPart = floor(logIndex0/19);
    BLDCctrlCmd = (integerPart*360+subii0*10)*14;
end

function writeBLDCcmdFile(BLDCctrlDeg)
global X;
fid = fopen([X.realtimeLogFolder 'tmp.txt'],'w');
fprintf(fid,'%d\n',round(BLDCctrlDeg));
fclose(fid);
movefile([X.realtimeLogFolder 'tmp.txt'],[X.realtimeLogFolder X.matlab2pcPythonCmdFile]);
end
    
function getDataFromRPi()
global X;
% /usr/bin/ssh: /home/dev/Programs/matlab2016b/bin/glnxa64/libcrypto.so.1.0.0: no version information available (required by /usr/bin/ssh)
% /usr/bin/ssh: /home/dev/Programs/matlab2016b/bin/glnxa64/libcrypto.so.1.0.0: no version information available (required by /usr/bin/ssh)
% OpenSSL version mismatch. Built against 100020ef, you have 100010bf
% scpCmd = sprintf('sshpass -p "M2Robots" scp pi@192.168.31.211:/home/pi/code/remote_dbg/AoArcvSPI/LogGovernerMode.dat %s',X.realtimeLogFolder);
system('../Host_workspaces/utilities/shellUtilityUbuntu/cp_RPi_governorModeData');
startTime = now;
while true
    if (now-startTime)*86400 > 3
        break;
    end
    datfile = ls([X.realtimeLogFolder 'LogGovernerMode.dat']);
end
end

function rdy = rawDataRdy()
global X;
python2matlabStatusFile = [X.realtimeLogFolder X.pcPython2matlabStatusRptFile];
if exist(python2matlabStatusFile,'file')
    rdy = true;
    delete(python2matlabStatusFile);
else
    rdy = false;
end
end
    
    