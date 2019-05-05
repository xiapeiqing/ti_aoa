function [est_iqPhsRad,QoSiqErrRad,QoS] = studyIQseperately(complexdata)
if nargin == 1
    strDescription = '';
end
[fc_est,~] = unwrapIQ2freqEst(complexdata);
% QoSworst,QoS: no unit, Err_reconstruction/RMS_signal
[est_iPhsRad,iQoSworst,iQoS,~] = algo_adaptiveAlldataCorr(real(complexdata),fc_est,'inphase');
[est_qPhsRad,qQoSworst,qQoS,~] = algo_adaptiveAlldataCorr(imag(complexdata),fc_est,'QuadrPh');
alignedVal = modmPitoPi([est_iPhsRad est_qPhsRad-pi/2]);
QoSiqErrRad = abs(diff(alignedVal));
est_iqPhsRad = mean(alignedVal);
QoS = max([iQoS qQoS]);