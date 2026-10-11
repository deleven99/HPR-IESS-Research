function t=time(s)
s=strip(string(s)); t=NaT(size(s));
ok=~ismissing(s) & strlength(s)>0;
s=replace(s,'/','-'); s=replace(s,'T',' ');
if any(ok)
    try
        t(ok)=datetime(s(ok),'InputFormat','yyyy-MM-dd HH:mm:ss');
    catch
        t(ok)=datetime(s(ok));
    end
end
t.Format='yyyy-MM-dd HH:mm:ss';
end
