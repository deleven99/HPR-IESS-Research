function R=analyse_dispatch(data,cfg)
D=data.DISPATCHLOAD; P=data.DISPATCHPRICE;
D=D(hpr.num(D,'RUNNO')==1 & hpr.num(D,'INTERVENTION')==0,:);
P=P(hpr.num(P,'RUNNO')==1 & hpr.num(P,'INTERVENTION')==0,:);
D.Time=hpr.time(D.SETTLEMENTDATE); P.Time=hpr.time(P.SETTLEMENTDATE);
hpr.check_unique(D,{'Time','DUID'},'dispatch');
hpr.check_unique(P,{'Time','REGIONID'},'regional prices');
R.dispatch=D; R.prices=P;
if ~isempty(data.DUDETAILSUMMARY)
    writetable(data.DUDETAILSUMMARY,fullfile(cfg.outputFolder,'registration_records.csv'));
end
if ~isempty(data.BIDDUIDDETAILS)
    writetable(data.BIDDUIDDETAILS,fullfile(cfg.outputFolder,'fcas_registration_records.csv'));
end
T=table;
for uid=cfg.duids
    a=sortrows(D(D.DUID==uid,:),'Time');
    av=hpr.num(a,'AVAILABILITY'); en=hpr.num(a,'TOTALCLEARED');
    f=nan(height(a),numel(cfg.services));
    for j=1:numel(cfg.services), f(:,j)=hpr.num(a,char(cfg.services(j))); end
    active=any(f>cfg.enabledTolerance,2);
    if isempty(a), continue; end
    rows=table(uid,height(a),min(a.Time),max(a.Time), ...
        first_time(a.Time,av>cfg.enabledTolerance),last_time(a.Time,av>cfg.enabledTolerance), ...
        first_time(a.Time,abs(en)>cfg.enabledTolerance),last_time(a.Time,abs(en)>cfg.enabledTolerance), ...
        first_time(a.Time,active),last_time(a.Time,active), ...
        'VariableNames',{'DUID','Records','FirstRecord','LastRecord','FirstAvailable', ...
        'LastAvailable','FirstNonzeroTarget','LastNonzeroTarget','FirstFCAS','LastFCAS'});
    T=[T;rows];
end
R.timeline=T; writetable(T,fullfile(cfg.outputFolder,'transition_evidence.csv'));
R.transition=NaT;
new=D(D.DUID=="HPR1",:);
candidate=new.Time(hpr.num(new,'AVAILABILITY')>cfg.enabledTolerance & year(new.Time)==2024);
if ~isempty(candidate), R.transition=min(candidate); end
assert(~isnat(R.transition),'HPR:Transition','No available HPR1 record in 2024.');
if dateshift(R.transition,'start','day')~=cfg.transitionDay
    error('HPR:TransitionMismatch','Observed date %s differs from configured date. Review transition_evidence.csv.',char(R.transition));
end
Q=table; S=table; State=table; Daily=table; Boot=table;
R.windows=struct;
for ndays=cfg.windows
    pre=(cfg.transitionDay-days(ndays)+minutes(5):minutes(5):cfg.transitionDay)';
    post=(cfg.transitionDay+days(1)+minutes(5):minutes(5):cfg.transitionDay+days(1+ndays))';
    sides={build(pre,true,D,P,cfg),build(post,false,D,P,cfg)};
    for side=1:2
        w=sides{side}; label=string({'before','after'}); label=label(side);
        R.windows.(sprintf('days%d',ndays)).(label)=w;
        writetable(w,fullfile(cfg.outputFolder,sprintf('intervals_%dd_%s.csv',ndays,label)));
        for j=1:numel(cfg.services)
            service=char(cfg.services(j)); x=w.(service); good=isfinite(x);
            S=[S;table(ndays,label,string(service),height(w),sum(good),mean(x,'omitnan'), ...
                median(x,'omitnan'),hpr.quantile(x,.95),max(x,[],'omitnan'), ...
                pct(x(good)>cfg.enabledTolerance),mean(w.([service 'RRP']),'omitnan'), ...
                'VariableNames',{'Days','Period','Service','ExpectedIntervals','ValidIntervals', ...
                'MeanMW','MedianMW','P95MW','MaxMW','EnabledPct','MeanPrice'})];
        end
        for th=cfg.thresholdsMW
            st=state(w.PowerMW,th);
            for sn=["charging","near_zero","discharging"]
                mask=st==sn;
                for j=1:numel(cfg.services)
                    x=w.(cfg.services(j)); g=mask & isfinite(x);
                    State=[State;table(ndays,label,th,sn,cfg.services(j),sum(mask),sum(g), ...
                        mean(x(g),'omitnan'),pct(x(g)>cfg.enabledTolerance), ...
                        'VariableNames',{'Days','Period','ThresholdMW','State','Service', ...
                        'StateIntervals','ValidServiceIntervals','MeanMW','EnabledPct'})];
                end
            end
        end
        day=dateshift(w.Time-minutes(5),'start','day');
        for date=unique(day)'
            m=day==date;
            row=table(ndays,label,date,sum(m),sum(w.DispatchComplete(m)),mean(w.RRP(m),'omitnan'), ...
                mean(w.PowerMW(m),'omitnan'),'VariableNames', ...
                {'Days','Period','Day','Intervals','DispatchValid','MeanRRP','MeanTargetMW'});
            for j=1:numel(cfg.services), row.(cfg.services(j))=mean(w.(cfg.services(j))(m),'omitnan'); end
            Daily=[Daily;row];
        end
        q=table(ndays,label,height(w),sum(w.DispatchComplete),sum(w.PriceComplete), ...
            sum(~isfinite(w.PowerMW)),mean(w.RRP,'omitnan'),mean(w.PowerMW,'omitnan'), ...
            'VariableNames',{'Days','Period','ExpectedIntervals','DispatchComplete','PriceComplete', ...
            'MissingPower','MeanEnergyPrice','MeanTargetMW'});
        Q=[Q;q];
    end
    for j=1:numel(cfg.services)
        a=Daily(Daily.Days==ndays & Daily.Period=="before",:);
        b=Daily(Daily.Days==ndays & Daily.Period=="after",:);
        a=a(a.DispatchValid==288,:); b=b(b.DispatchValid==288,:);
        [lo,hi]=boot(a.(cfg.services(j)),b.(cfg.services(j)),cfg);
        delta=mean(sides{2}.(cfg.services(j)),'omitnan')-mean(sides{1}.(cfg.services(j)),'omitnan');
        Boot=[Boot;table(ndays,cfg.services(j),delta,lo,hi,height(a),height(b), ...
            'VariableNames',{'Days','Service','MeanDifferenceMW','DailyBootstrapLo','DailyBootstrapHi', ...
            'CompleteDaysBefore','CompleteDaysAfter'})];
    end
end
R.statistics=S; R.states=State; R.daily=Daily; R.uncertainty=Boot; R.quality=Q;
writetable(S,fullfile(cfg.outputFolder,'service_statistics.csv'));
writetable(State,fullfile(cfg.outputFolder,'state_sensitivity.csv'));
writetable(Daily,fullfile(cfg.outputFolder,'daily_statistics.csv'));
writetable(Boot,fullfile(cfg.outputFolder,'window_sensitivity_and_bootstrap.csv'));
writetable(Q,fullfile(cfg.outputFolder,'quality_checks.csv'));
R.standardized=standardized(R.windows.days21.before,R.windows.days21.after,cfg);
writetable(R.standardized,fullfile(cfg.outputFolder,'common_support_comparison.csv'));
R.storage=storage_audit(D,cfg);
writetable(R.storage,fullfile(cfg.outputFolder,'stored_energy_quality.csv'));
if cfg.checkReference, reference_check(S,cfg); end
end

function w=build(t,legacy,D,P,cfg)
w=table(t,'VariableNames',{'Time'});
if legacy
    g=align(D(D.DUID=="HPRG1",:),t); l=align(D(D.DUID=="HPRL1",:),t);
    w.PowerMW=hpr.num(g,'TOTALCLEARED')-hpr.num(l,'TOTALCLEARED');
    w.InitialMW=hpr.num(g,'INITIALMW')-hpr.num(l,'INITIALMW');
    w.GenTargetMW=hpr.num(g,'TOTALCLEARED'); w.LoadTargetMW=hpr.num(l,'TOTALCLEARED');
    for j=1:numel(cfg.services)
        s=char(cfg.services(j)); w.(s)=hpr.num(g,s)+hpr.num(l,s);
    end
    w.StoredEnergyMWh=nan(height(w),1);
else
    a=align(D(D.DUID=="HPR1",:),t);
    w.PowerMW=hpr.num(a,'TOTALCLEARED'); w.InitialMW=hpr.num(a,'INITIALMW');
    w.GenTargetMW=max(w.PowerMW,0); w.LoadTargetMW=max(-w.PowerMW,0);
    for j=1:numel(cfg.services), s=char(cfg.services(j)); w.(s)=hpr.num(a,s); end
    w.StoredEnergyMWh=hpr.num(a,'INITIAL_ENERGY_STORAGE');
end
p=align(P,t);
w.RRP=hpr.num(p,'RRP');
for j=1:numel(cfg.services)
    s=char(cfg.services(j))+"RRP"; w.(s)=hpr.num(p,char(s));
end
w.State=state(w.PowerMW,1);
w.DispatchComplete=all(isfinite(w{:,cellstr(cfg.services)}),2) & isfinite(w.PowerMW);
w.PriceComplete=all(isfinite(w{:,cellstr(cfg.services+"RRP")}),2) & isfinite(w.RRP);
end

function a=align(A,t)
A=A(:,setdiff(A.Properties.VariableNames,{'REGIONID'},'stable'));
a=outerjoin(table(t,'VariableNames',{'Time'}),A,'Keys','Time','MergeKeys',true,'Type','left');
a=sortrows(a,'Time');
end
function s=state(p,threshold)
s=repmat("near_zero",size(p)); s(p<-threshold)="charging"; s(p>threshold)="discharging";
s(~isfinite(p))="missing";
end
function p=pct(mask)
if isempty(mask), p=NaN; else, p=100*mean(mask); end
end
function t=first_time(times,mask)
if any(mask), t=min(times(mask)); else, t=NaT; end
end
function t=last_time(times,mask)
if any(mask), t=max(times(mask)); else, t=NaT; end
end
function [lo,hi]=boot(a,b,cfg)
a=a(isfinite(a)); b=b(isfinite(b)); lo=NaN; hi=NaN;
if numel(a)<3 || numel(b)<3, return; end
rng(cfg.randomSeed,'twister');
d=mean(b(randi(numel(b),numel(b),cfg.bootstrapReplicates)),1)- ...
    mean(a(randi(numel(a),numel(a),cfg.bootstrapReplicates)),1);
q=hpr.quantile(d(:),[.025,.975]); lo=q(1); hi=q(2);
end
function T=standardized(a,b,cfg)
edges=unique(hpr.quantile([a.RRP;b.RRP],[.25,.5,.75]));
ka=key(a,edges); kb=key(b,edges); strata=intersect(unique(ka),unique(kb));
T=table;
for j=1:numel(cfg.services)
    s=cfg.services(j); va=a.(s); vb=b.(s);
    totals=[0,0]; weight=0; na=0; nb=0;
    for k=1:numel(strata)
        ma=ka==strata(k) & isfinite(va) & a.DispatchComplete & a.PriceComplete;
        mb=kb==strata(k) & isfinite(vb) & b.DispatchComplete & b.PriceComplete;
        n=min(sum(ma),sum(mb));
        if n<cfg.minimumStratumCount, continue; end
        totals=totals+n*[mean(va(ma)),mean(vb(mb))]; weight=weight+n;
        na=na+sum(ma); nb=nb+sum(mb);
    end
    if weight==0, means=[NaN,NaN]; else, means=totals/weight; end
    T=[T;table(s,means(1),means(2),means(2)-means(1),weight,na,nb, ...
        'VariableNames',{'Service','StandardizedBeforeMW','StandardizedAfterMW', ...
        'DifferenceMW','CommonWeight','IncludedBeforeIntervals','IncludedAfterIntervals'})];
end
end
function k=key(w,edges)
bin=ones(height(w),1);
for e=edges, bin=bin+(w.RRP>e); end
k=w.State+"|"+string(floor(hour(w.Time-minutes(5))/6))+"|"+string(bin);
k(~isfinite(w.RRP) | w.State=="missing")="missing";
end
function T=storage_audit(D,cfg)
T=table;
for uid=cfg.duids
    a=sortrows(D(D.DUID==uid,:),'Time'); x=hpr.num(a,'INITIAL_ENERGY_STORAGE');
    monthLabels=dateshift(a.Time-minutes(5),'start','month');
    for mon=unique(monthLabels)'
        m=monthLabels==mon; z=x(m); t=a.Time(m);
        valid=isfinite(z); zeroMask=valid & z==0;
        maxrun=0; run=0;
        for k=1:numel(z)
            if zeroMask(k) && (k==1 || t(k)-t(k-1)==minutes(5)), run=run+1;
            elseif zeroMask(k), run=1; else, run=0; end
            maxrun=max(maxrun,run);
        end
        T=[T;table(uid,mon,numel(z),sum(valid),sum(zeroMask),maxrun, ...
            min(z,[],'omitnan'),max(z,[],'omitnan'),'VariableNames', ...
            {'DUID','Month','Records','ValidStoredEnergy','ZeroReports','LongestZeroRun', ...
            'MinReportedMWh','MaxReportedMWh'})];
    end
end
end
function reference_check(S,cfg)
expected=[6.004,9.646;39.045,25.480;15.370,7.470;2.168,1.814; ...
    .093,.344;12.213,6.704;19.365,11.550;7.722,5.557;11.009,9.657;11.738,23.298];
T=table;
for j=1:numel(cfg.services)
    for side=1:2
        labels=["before","after"]; label=labels(side);
        r=S(S.Days==21 & S.Service==cfg.services(j) & S.Period==label,:);
        actual=r.MeanMW; pass=abs(actual-expected(j,side))<.001;
        T=[T;table(cfg.services(j),label,expected(j,side),actual,pass, ...
            'VariableNames',{'Service','Period','ReferenceRoundedMW','ComputedMW','WithinTolerance'})];
    end
end
writetable(T,fullfile(cfg.outputFolder,'reference_reconciliation.csv'));
if ~all(T.WithinTolerance)
    warning('HPR:Reference','Some results differ from prior archives. Inspect reconciliation and source inventory.');
end
end
