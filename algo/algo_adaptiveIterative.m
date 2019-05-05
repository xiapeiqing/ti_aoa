% chapter7 in peiqing1/books/books original/Signal Processing, filter Books(implementation)/Dsp Applications Using C & Tms320c6X Dsk
% FIGURE 7.6. Adaptive filter program compiled with Borland C/C+ + (adaptc.c).
function algo_adaptiveIterative()
close all;
beta = 0.01;
N = 1; % N=1 means 2 tap filter, which is OK for sine wave signal.aadaxxxx descend
TotalSampleCnt = 4e4;
Fc = 1000;
Fs = 8000;
W = zeros(1,N+1);
referenceSig = zeros(N+1,1);
results = zeros(TotalSampleCnt+1,4);
for T = 0:TotalSampleCnt
    %start adaptive algorithm
    referenceSig(1) = sin(2*pi*T*Fc/Fs);
    desiredSig = 2*cos(2*pi*T*Fc/Fs);
    Y = W*referenceSig;
    % calculate filter output
    E = desiredSig - Y;
    % calculate error signal
    for I = N:-1:0
        W(I+1) = W(I+1) + beta*E*referenceSig(I+1);
        if I ~= 0
            referenceSig(I+1) = referenceSig(I);
        end
    end
    results(T+1,1) = T/Fs; % time axis
    results(T+1,2) = desiredSig; % desired
    results(T+1,3) = Y; % y output
    results(T+1,4) = E; % e
    disp(W);
end
figure;
subplot(311);plot(results(:,1),results(:,2));title('desired');
subplot(312);plot(results(:,1),results(:,3));title('y output');
subplot(313);plot(results(:,1),results(:,4));title('e');
