function val = modmPitoPi(val)
% works for scalar, vector and matrix
val = mod(val,2*pi);
index = find(val > pi);
val(index) = val(index) - 2*pi;
% while val <= -pi
%     val = val + 2*pi;
% end
% while val > pi
%     val = val - 2*pi;
% end
end
