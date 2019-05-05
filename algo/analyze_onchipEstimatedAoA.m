function analyze_onchipEstimatedAoA()
%logfilename = './data/1AoAmountedOnRPi/aoa_antennaHorizontal';cycles = 2;
%logfilename = './data/aoa_dataVertical'; % arrow pointing to zenith
%logfilename = './data/aoa_dataVertical2cycles';
%logfilename = './data/aoa_dataVertical2cycles1';cycles = 2;
%logfilename = './data/aoa_dataVertical10cycles';cycles = 10;
%logfilename = './data/3RPi_on_base/aoa2cycles';cycles = 2;
%logfilename = './data/5_increasePwr/aoa2cycles';cycles = 2;
%logfilename = './data/6_AoAhorizontallyTop_arrow2tag/aoa2cycles';cycles = 2;
%logfilename = './data/6_AoAhorizontallyTop_arrow2tag/aoa10cycles';cycles = 10;
%logfilename = './data/7_goback2verticalMount/aoa2cycles';cycles = 2;
logfilename = '../Host_workspaces/datalog/history/onChipAoAdata/7_goback2verticalMount/aoa10cycles';cycles = 10;


close all;
if ~exist([logfilename '.mat'],'file')
[~,LogStr]=system(['grep -e "{\"aoa\":" ' logfilename '.txt | sed ''s/^.*{"aoa"://''']);
fid = fopen('exp.txt','w');
fprintf(fid,'%s\n',LogStr);
fclose(fid);
dataset = sscanf(LogStr,'%d, "rssi": %d, "antenna": %d, "channel": %d}\n',[4,inf])';
save([logfilename '.mat'],'dataset');
end
%%
load([logfilename '.mat']);
cycleRng = [0,1]; %[0,0.5;0.5,1;0,1];
aoaDegAll = dataset(:,1);
RssiAll = dataset(:,2);
antennaAll = dataset(:,3);
channelAll = dataset(:,4);
angleOnly = false;%true;%false;
for rngChoiceii = 1:size(cycleRng,1)
    for antennaii = 1:2
        hFig = figure('Name',sprintf('%s,ant%d',logfilename,antennaii),'NumberTitle','off');
        indexAntii = find(antennaAll==antennaii);
        aoaDeg = aoaDegAll(indexAntii);
        rssi = RssiAll(indexAntii);
        RFchannel = channelAll(indexAntii);
        xaxis = (1:length(indexAntii))/length(indexAntii)*cycles;
        selectedRngIndex = find(mod(xaxis,1)<cycleRng(rngChoiceii,2) & mod(xaxis,1)>cycleRng(rngChoiceii,1));
        if ~angleOnly
            subplot(3,1,1);
        end
        plot(xaxis(selectedRngIndex),aoaDeg(selectedRngIndex),'.-');grid on;
        ylabel('deg');
        xlim([0,cycles]);
        if ~angleOnly
            subplot(3,1,2);
            plot(xaxis(selectedRngIndex),rssi(selectedRngIndex),'.-');grid on;
            ylabel('dB');
            xlim([0,cycles]);
            subplot(3,1,3);
            plot(xaxis(selectedRngIndex),RFchannel(selectedRngIndex),'.-');grid on;
            ylabel('RF CH');
            xlim([0,cycles]);
        end
        savePlot(hFig,sprintf('%s_ant%d_%d',logfilename,antennaii,rngChoiceii));
    end
end
end

