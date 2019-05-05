function newpath = processPath(oldpath)
newpath = oldpath;
newpath(find(newpath=='\'))='/';
if newpath(end) ~= '/'
    newpath = [newpath '/'];
end
end