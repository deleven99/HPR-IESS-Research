function T = load_data(inv,type,cfg,ids)
hit = contains(upper(inv.Path),upper(type)) & ismember(inv.Extension,[".zip",".csv"]);
if type=="DISPATCHPRICE"
    hit=hit | (contains(upper(inv.Path),"PUBLIC_PRICES_") & ismember(inv.Extension,[".zip",".csv"]));
end
if type=="DISPATCHLOAD"
    [~,names,ext]=arrayfun(@(p) fileparts(p),inv.Path,'UniformOutput',false);
    plain=startsWith(upper(string(names)),"HPR1_") & string(ext)==".csv";
    hit=hit | plain;
end
sources=inv(hit,:);
keep=true(height(sources),1);
for k=1:height(sources)
    [~,stem,ext]=fileparts(sources.Path(k));
    if strcmpi(ext,'.csv')
        keep(k)=~any(endsWith(lower(sources.Path),lower(string(stem)+".zip")));
    end
end
for k=1:height(sources)
    [~,stem,ext]=fileparts(sources.Path(k));
    peers=endsWith(lower(sources.Path),lower(string(stem)+string(ext)));
    candidates=find(peers & keep);
    if numel(candidates)>1
        [~,best]=max(sources.Bytes(candidates));
        keep(candidates)=false; keep(candidates(best))=true;
    end
end
sources=sources(keep,:);
idToken="";
if ~isempty(ids), idToken=join(sort(ids),","); end
signature="reader-v3|"+string(cfg.version)+"|"+join(string(cfg.duids),",")+"|"+cfg.region+"|"+idToken;
for k=1:height(sources)
    signature=signature+"|"+sources.Path(k)+"|"+string(sources.Bytes(k))+"|"+string(sources.ModifiedSerial(k));
end
cache=fullfile(cfg.cacheFolder,char(type)+".mat");
if isfile(cache) && ~cfg.rebuildCache
    old=load(cache,'signature','T');
    if isequal(old.signature,signature)
        T=old.T; fprintf('%s: cached %d selected records.\n',type,height(T)); return
    end
end
T=table;
if isempty(sources)
    fprintf('%s: no input supplied.\n',type); return
end
for k=1:height(sources)
    fprintf('%s [%d/%d]: %s\n',type,k,height(sources),sources.Path(k));
    files=hpr.unpack(sources.Path(k),cfg.cacheFolder);
    for j=1:numel(files)
        if type=="DISPATCHPRICE" && contains(upper(files(j)),"PUBLIC_PRICES_")
            part=hpr.read_public_prices(files(j),cfg);
        else
            part=read_one(files(j),type,cfg,ids);
        end
        if isempty(part), continue; end
        T=hpr.union_tables(T,part);
    end
end
if ~isempty(T), T=unique(T,'rows','stable'); end
if type=="DISPATCHPRICE" && ~isempty(T)
    wanted=["SETTLEMENTDATE","RUNNO","INTERVENTION","REGIONID","RRP",cfg.services+"RRP"];
    for name=wanted
        if ~ismember(char(name),T.Properties.VariableNames), T.(name)=strings(height(T),1); end
    end
    T=unique(T(:,cellstr(wanted)),'rows','stable');
end
save(cache,'T','signature','-v7.3');
fprintf('%s: %d selected records.\n',type,height(T));
end

function T=read_one(path,type,cfg,ids)
T=table;
[~,stem]=fileparts(path);
if startsWith(upper(string(stem)),"PUBLIC_PRICES_")
    if string(type)=="DISPATCHPRICE"
        T=hpr.read_public_prices(path,cfg);
    end
    return
end
fid=fopen(path,'r','n','UTF-8');
if fid<0, error('HPR:Read','Cannot open %s.',path); end
fileCleanup=onCleanup(@() fclose(fid));
first=fgetl(fid);
if ~ischar(first), return; end
if startsWith(first,'C,')
    header=fgetl(fid);
else
    header=first;
end
if ~ischar(header), return; end
names=erase(strtrim(split(string(header),',')'),'"');
mms=ismember(names(1),["I","RECORD","ROWTYPE"]);
if mms, names(1:4)=["ROWTYPE","DATASET","TABLE","SCHEMAVERSION"]; end
if ~any(ismember(names,["DUID","GENCONID","REGIONID","CONSTRAINTID"]))
    return
end
if type=="DISPATCHCONSTRAINT" && isempty(ids), return; end
opts=delimitedTextImportOptions('NumVariables',numel(names));
opts.Delimiter=',';
opts.VariableNames=cellstr(names);
opts=setvartype(opts,cellstr(names),'string');
opts.DataLines=[1 Inf];
opts.VariableNamesLine=0;
opts.ExtraColumnsRule='error';
opts.EmptyLineRule='skip';
opts.ConsecutiveDelimitersRule='split';
opts.LeadingDelimitersRule='keep';
if type=="DISPATCHCONSTRAINT"
    wanted=["ROWTYPE","SETTLEMENTDATE","RUNNO","INTERVENTION","CONSTRAINTID", ...
        "RHS","MARGINALVALUE","VIOLATIONDEGREE","GENCONID_EFFECTIVEDATE","GENCONID_VERSIONNO","LHS"];
    opts.SelectedVariableNames=cellstr(intersect(wanted,names,'stable'));
elseif type=="DISPATCH_FCAS_REQ"
    wanted=["ROWTYPE","SETTLEMENTDATE","RUNNO","INTERVENTION","GENCONID","REGIONID", ...
        "BIDTYPE","GENCONEFFECTIVEDATE","GENCONVERSIONNO","MARGINALVALUE"];
    opts.SelectedVariableNames=cellstr(intersect(wanted,names,'stable'));
end
switch type
    case {"DISPATCHLOAD","DUDETAILSUMMARY","BIDDUIDDETAILS","BIDPEROFFER_D","BIDDAYOFFER_D"}
        values=cfg.duids;
    case {"DISPATCHPRICE","DISPATCH_FCAS_REQ"}
        values=cfg.region;
    case "DISPATCHCONSTRAINT"
        values=ids';
    otherwise
        values=strings(1,0);
end
patterns=[","+values+",",","+string(char(34))+values+string(char(34))+","];
tmp=string(tempname(cfg.cacheFolder))+".csv";
tempCleanup=onCleanup(@() remove_temp(tmp));
parts={}; n=0; scanned=0; pending="";
fprintf('  HPR reader v3: text blocks + readtable; no datastore.\n');
while ~feof(fid)
    lines=textscan(fid,'%s',cfg.chunkRows,'Delimiter','\n', ...
        'Whitespace','','EndOfLine','\n','ReturnOnError',false);
    raw=string(lines{1});
    if isempty(raw), break; end
    raw=regexprep(raw,'\r$',''); scanned=scanned+numel(raw);
    [records,pending]=complete_records(raw,pending);
    if mms
        changed=startsWith(records,'I,') & records~=string(header);
        if any(changed)
            error('HPR:Schema','Changed CSV schema inside %s. Review this input.',path);
        end
        records=records(startsWith(records,'D,'));
    end
    if ~isempty(values), records=records(contains(records,patterns)); end
    if ~isempty(records)
        out=fopen(tmp,'w','n','UTF-8');
        if out<0, error('HPR:Write','Cannot create temporary chunk file.'); end
        writerCleanup=onCleanup(@() fclose(out));
        fprintf(out,'%s\n',char(join(records,newline)));
        clear writerCleanup
        b=readtable(tmp,opts);
        switch type
            case {"DISPATCHLOAD","DUDETAILSUMMARY","BIDDUIDDETAILS","BIDPEROFFER_D","BIDDAYOFFER_D"}
                b=b(ismember(b.DUID,cfg.duids),:);
            case {"DISPATCHPRICE","DISPATCH_FCAS_REQ"}
                b=b(b.REGIONID==cfg.region,:);
            case "DISPATCHCONSTRAINT"
                b=b(ismember(b.CONSTRAINTID,ids),:);
        end
        if ~isempty(b), n=n+1; parts{n}=b; end
    end
    if mod(scanned,10*cfg.chunkRows)==0
        fprintf('  scanned %d physical lines, retained chunks %d\n',scanned,n);
        drawnow;
    end
end
if strlength(pending)>0
    error('HPR:CSVQuotes','Unclosed quoted CSV record at end of %s.',path);
end
if n>0, T=vertcat(parts{:}); end
end

function [records,pending]=complete_records(raw,pending)
odd=mod(count(raw,string(char(34))),2)==1;
if strlength(pending)==0 && ~any(odd), records=raw; return; end
records=strings(numel(raw),1); n=0;
for k=1:numel(raw)
    if strlength(pending)==0
        if odd(k), pending=raw(k); else, n=n+1; records(n)=raw(k); end
    else
        pending=pending+newline+raw(k);
        if odd(k), n=n+1; records(n)=pending; pending=""; end
    end
end
records=records(1:n);
end

function remove_temp(path)
if isfile(path), delete(path); end
end
