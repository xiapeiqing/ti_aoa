function [timestampMs,AntArrayAx,packetId,RFchannel,RSSI,IFsample] = loadM2RbBinaryLog(...
    InputBinaryLogfilename,OutputTxtLogfile)
global X;
valid = true;
globalSettings();
if nargin < 2
    OutputTxtLogfile = '';
end
if nargin < 1
    InputBinaryLogfilename = '../Host_workspaces/datalog/Log_000_00000_00.dat';
end
close all;fclose all;

fidBinaryInput = fopen(InputBinaryLogfilename);
binaryLogContent = fread(fidBinaryInput);
fclose(fidBinaryInput);
LogfileBlkBytes = X.RawDatProtocol.bufSPIpacketLEN + X.LogTimestampBytes;
sectionCnt = length(binaryLogContent)/LogfileBlkBytes;
assert(length(binaryLogContent) == LogfileBlkBytes*sectionCnt);
timestampMs = zeros(1,sectionCnt);
AntArrayAx = zeros(1,sectionCnt); 
packetId = zeros(1,sectionCnt); 
RFchannel = zeros(1,sectionCnt);
RSSI = zeros(1,sectionCnt);
IFsample = zeros(512,sectionCnt);
if isempty(OutputTxtLogfile)
    fidOutputTxtLogfile = NaN;
else
    fidOutputTxtLogfile = fopen(OutputTxtLogfile,'w');
end
CRCvalidPkt = 0;
for secii = 0:sectionCnt-1
    thisSection = binaryLogContent(secii*LogfileBlkBytes+1:(secii+1)*LogfileBlkBytes);
    timestampMs(secii+1) = typecast(uint8(thisSection(1:X.LogTimestampBytes)),'int32');
    thisSection = thisSection(X.RawDatProtocol.ByteAntArray+1:end);
    assert(length(thisSection) == X.RawDatProtocol.bufSPIpacketLEN);
    crc8result = computeCRC8(thisSection(5:end-1));
    if crc8result == thisSection(end)
        CRCvalidPkt = CRCvalidPkt + 1;
        AntArrayAx(secii+1) = thisSection(X.RawDatProtocol.ByteAntArray+1); 
        packetId(secii+1) = thisSection(X.RawDatProtocol.BytePktId+1); 
        RFchannel(secii+1) = thisSection(X.RawDatProtocol.ByteRfChan+1);
        RSSI(secii+1) = typecast(uint8(thisSection(X.RawDatProtocol.SNR_BYTE0+1)),'int8');
        %RSSI(:,secii+1) = typecast(uint8(thisSection(X.RawDatProtocol.SNR_BYTE0+1:X.RawDatProtocol.AOA_SAMPLES_BYTE0)), 'uint32');
        IFsample(:,secii+1) = analyzePacket(...
            thisSection(X.RawDatProtocol.ByteAntArray+1),...
            thisSection(X.RawDatProtocol.BytePktId+1),...
            thisSection(X.RawDatProtocol.ByteRfChan+1),...
            thisSection(X.RawDatProtocol.AOA_SAMPLES_BYTE0+1:end-1),...
            fidOutputTxtLogfile);
    else
        fprintf(1,'crc error, local computed:%d rcvd:%d,preamble:%s %d,%d,%d\n',...
            crc8result,thisSection(end),char(thisSection(1:4)),thisSection(5),thisSection(6),thisSection(7));
    end
end
%fprintf(1,'%d out of %d valid packets\n',CRCvalidPkt,sectionCnt);
assert(CRCvalidPkt >= sectionCnt*0.99);
    
if ~isempty(OutputTxtLogfile)
    fclose(fidOutputTxtLogfile);
end
end

function IFcomplexSamp = analyzePacket(AntArrayAx, packetId, channel, acPacket, fidOutput)
global X;
if nargin < 5
    fidOutput = NaN;
end
u8Packet = uint8(acPacket);
y = typecast(u8Packet, 'int16');
IFcomplexSamp = double(y(1:2:end))+1j*double(y(2:2:end));
IFcomplexSamp = IFcomplexSamp(:);
for lineii = 0:length(IFcomplexSamp)-1
    if ~isnan(fidOutput)
        fprintf(fidOutput,'%2.1f  %2.1f\n',y(lineii*2+1),y(lineii*2+2));
    end
end
if CMathHelper.shallwePlot(X.plotLevel.VERBOSE)
    figure;
    subplot(231);plot(abs(IFcomplexSamp),'.-');xlabel('4Msps');ylabel('mag');title(sprintf('Array%d Pkt%d CH%d',AntArrayAx, packetId, channel));
    subplot(232);plot(phase(IFcomplexSamp),'.-');xlabel('4Msps');ylabel('Phs(rad)');
    subplot(233);plot(diff(phase(IFcomplexSamp)),'.-');xlabel('4Msps');ylabel('\delta Phs(rad)');
    subplot(234);plot(y(1:2:end),'.-');xlabel('4Msps');ylabel('i');
    subplot(235);plot(y(2:2:end),'.-');xlabel('4Msps');ylabel('q');
end
end