function [fc_est,complexPhsApproxRad] = unwrapIQ2freqEst(complexdata,strDescription,bPlot)
if nargin < 2
    strDescription = '';
end
if nargin < 3
    bPlot = false;
end
dataPntLen = length(complexdata);
mag = abs(complexdata);
% % phs=Xcoeff*complexPhsApproxRad
Xcoeff = [ones(dataPntLen,1) (0:dataPntLen-1)'];
phs = unwrap(angle(complexdata));
complexPhsApproxRad = Xcoeff\phs; % https://www.mathworks.com/help/matlab/data_analysis/linear-regression.html
Ereconstruct = phs-Xcoeff*complexPhsApproxRad;
if bPlot
    figure;
    subplot(321);plot(mag,'.-');ylabel('mag');title(strDescription);
    subplot(322);hist(mag,20);ylabel('mag');
    subplot(323);plot([phs Xcoeff*complexPhsApproxRad],'.-');ylabel('rad');legend('meas','estimated');xlabel(sprintf('[0,%d]',length(mag)-1));
    if complexPhsApproxRad(1) > 0
        title(sprintf('%4.3fx+%3.2f',complexPhsApproxRad(2),complexPhsApproxRad(1)));
    else
        title(sprintf('%4.3fx%3.2f',complexPhsApproxRad(2),complexPhsApproxRad(1)));
    end
    subplot(324);plot(Ereconstruct,'.-');ylabel('rad');title(sprintf('1^{st} order regression error, %2.1f',norm(Ereconstruct)/length(Ereconstruct)));
    subplot(325);plot(diff(phs),'.-');ylabel('diff meas(rad)');
end
complexPhsApproxRad(length(complexPhsApproxRad)+1) = norm(Ereconstruct)/length(Ereconstruct);
fc_est = abs(complexPhsApproxRad(2)/(2*pi)); % not in Hz, but in -0.5sampleClk=>0.5sampleClk
end