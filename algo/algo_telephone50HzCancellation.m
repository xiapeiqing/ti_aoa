% chapter7 in peiqing1/books/books original/Signal Processing, filter Books(implementation)/Dsp Applications Using C & Tms320c6X Dsk
% FIGURE 7.9. Adaptive FIR filter program for noise cancellation (adaptnoise.c).
function algo_telephone50HzCancellation()
close all;
IterationCnt = 1e4;
VoiceFreqHz = 1500;
AChummingFreqHz = 50;
unknownAC_phsRad = 0.37*pi;
unknownAC_mag = 2.8;

beta = 1e-3;
N = 30;
SampleFreqHz = 10e3;
alloutput = zeros(1,IterationCnt);
w = zeros(1,N);
delay = zeros(1,N);
for loopii = 1:IterationCnt
    tSec = loopii/SampleFreqHz; 
    delay(1) = cos(2*pi*AChummingFreqHz*tSec); % cos(312 Hz) input to adapt FIR
    % init output of adapt filter
    yn = w*delay';
    % output of adaptive filter  
    E = sin(2*pi*VoiceFreqHz*tSec) + unknownAC_mag*sin(2*pi*AChummingFreqHz*tSec + unknownAC_phsRad) - yn; % ”error” signal=(d+n)-yn
    for i = N-1:-1:0
        w(i+1) = w(i+1) + beta*E*delay(i+1);%w[i] = w[i] + beta*E*delay[i]; //update weights
        if (i > 0)
            delay(i+1) = delay(i-1+1); %update delay samples
        end
    end
    alloutput(loopii) = E; %”error” signal overall output
end
figure;plot(alloutput);
exractLastNpnts= 1024;
figure;plot((-exractLastNpnts/2:exractLastNpnts/2-1)*SampleFreqHz/exractLastNpnts,abs(fftshift(fft(alloutput(end-exractLastNpnts+1:end)))),'.-');
end


