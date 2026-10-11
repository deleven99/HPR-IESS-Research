function T=missing_files(data,inv,cfg,constraints)
T=table;
types=["DISPATCHLOAD","DISPATCHPRICE","DUDETAILSUMMARY","BIDDUIDDETAILS", ...
    "BIDPEROFFER_D","BIDDAYOFFER_D","DISPATCH_FCAS_REQ","DISPATCHCONSTRAINT","GENCONDATA"];
for type=types
    present=isfield(data,char(type)) && ~isempty(data.(type));
    for monthNumber=[9,10]
        token=sprintf('2024%02d010000',monthNumber);
        monthPresent=any(contains(upper(inv.Path),type) & contains(inv.Path,token));
        if ~(present && monthPresent)
            T=add(T,"2024 case",type,string(token), ...
                "Check coverage; core dispatch/price required, other modules optional",archive_url(2024,monthNumber,type));
        end
    end
end
if nargin>=4
    v=constraints.missingDefinitions;
    if isfield(constraints,'versionChecks')
        v=constraints.versionChecks(~constraints.versionChecks.DefinitionFound,:);
    end
    if ~isempty(v)
    dates=v.EffectiveDate;
    if ~isdatetime(dates), dates=hpr.time(dates); end
    months=unique(dateshift(dates(~isnat(dates)),'start','month'));
    for monthIndex=1:numel(months)
        archiveDate=months(monthIndex);
        T=add(T,"Historic constraint definition","GENCONDATA",string(archiveDate), ...
            "Needed to interpret the referenced equation; rerun after downloading", ...
            archive_url(year(archiveDate),month(archiveDate),"GENCONDATA"));
    end
    end
end
for m=[3,4,5,6]
    token=sprintf('2026%02d010000',m);
    dispatch=false;
    if isfield(data,'DISPATCHLOAD') && ~isempty(data.DISPATCHLOAD)
        d=data.DISPATCHLOAD; dt=hpr.time(d.SETTLEMENTDATE);
        dispatch=any(year(dt)==2026 & month(dt-minutes(5))==m & d.DUID=="HPR1");
    end
    if ~dispatch
        T=add(T,"Optional 2026 supplement","DISPATCHLOAD",string(token), ...
            "Only needed if the matching later-month price comparison is retained",archive_url(2026,m,"DISPATCHLOAD"));
    end
end
for type=["SPDCONNECTIONPOINTCONSTRAINT","SPDREGIONCONSTRAINT","SPDINTERCONNECTORCONSTRAINT","GENCONSETINVOKE","GENCONSETTRK"]
    if ~any(contains(upper(inv.Path),type))
        T=add(T,"Optional full equation attribution",type,"2024-09 and 2024-10", ...
            "Future extension: coefficients/invocation; current module gives context only", ...
            directory_url(2024,9)+" ; "+directory_url(2024,10));
    end
end
writetable(T,fullfile(cfg.outputFolder,'missing_files.csv'));
end
function T=add(T,scope,type,period,reason,url)
T=[T;table(scope,type,period,reason,url,'VariableNames',{'Scope','Table','Period','Reason','DownloadURL'})];
end
function u=archive_url(y,m,type)
base=directory_url(y,m);
if y<2024 || (y==2024 && m<9)
    file=sprintf('PUBLIC_DVD_%s_%04d%02d010000.zip',type,y,m);
else
    file=sprintf('PUBLIC_ARCHIVE%%23%s%%23FILE01%%23%04d%02d010000.zip',type,y,m);
end
u=base+string(file);
end
function u=directory_url(y,m)
u=string(sprintf('https://nemweb.com.au/Data_Archive/Wholesale_Electricity/MMSDM/%04d/MMSDM_%04d_%02d/MMSDM_Historical_Data_SQLLoader/DATA/',y,y,m));
end
