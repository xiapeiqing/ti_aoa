function loadTIsampleAoAserialOutput()
% 1) collect serial output using any serail port logger, log file name TIsampleAoAserialOutput.txt 
% 2) run Host_workspaces/utilities/FileOperation/preprocessTIaoaExampleSerialOutput to generate file with AoA(deg) data only 
% 3) run this script to visualize it
%LogFile = '../Host_workspaces/datalog/TIsampleAoAserialOutput.txt';
aoaDeg = load('../Host_workspaces/datalog/TIaoa.txt');
figure;
subplot(211);
plot(aoaDeg);
subplot(212);
hist(aoaDeg);