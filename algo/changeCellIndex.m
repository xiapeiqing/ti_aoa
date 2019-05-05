function newdat = changeCellIndex(olddat,index)
assert(length(olddat) == length(index));
newdat = cell(size(olddat));
for ii = 1:length(index)
    newdat{ii} = olddat{index(ii)};
end
end