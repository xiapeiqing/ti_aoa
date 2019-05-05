function res = add_pm_pi(val1,val2,val1cnt,val2cnt)
assert(nargin == 2 || nargin == 4);
if nargin == 2
    val1cnt = 1;
    val2cnt = 1;
end
newvalRelativeToVal1 = modmPitoPi(val2-val1)*val2cnt/(val1cnt+val2cnt);
newval = newvalRelativeToVal1 + val1;
res = modmPitoPi(newval);