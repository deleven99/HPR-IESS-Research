function T=read_public_prices(path,cfg)
wanted=["SETTLEMENTDATE","RUNNO","INTERVENTION","REGIONID","RRP",cfg.services+"RRP"];
reader=java.io.BufferedReader(java.io.InputStreamReader(java.io.FileInputStream(char(path)),'UTF-8'));
cleanup=onCleanup(@() reader.close());
rows={}; n=0; names=strings(1,0); ix=[]; regionIndex=0; isRegion=false;
while true
    line=reader.readLine(); if isempty(line), break; end
    fields=split(string(char(line)),',')'; fields=erase(fields,'"');
    if fields(1)=="I"
        isRegion=numel(fields)>3 && fields(2)=="DREGION";
        if isRegion
            names=fields; regionIndex=find(names=="REGIONID",1);
            [present,ix]=ismember(wanted,names); ix(~present)=0;
        end
    elseif fields(1)=="D" && isRegion && numel(fields)>=regionIndex && fields(regionIndex)==cfg.region
        values=strings(1,numel(wanted)); good=ix>0 & ix<=numel(fields);
        values(good)=fields(ix(good)); n=n+1; rows{n}=values;
    end
end
if n==0, T=table; else, T=array2table(vertcat(rows{:}),'VariableNames',cellstr(wanted)); end
end
