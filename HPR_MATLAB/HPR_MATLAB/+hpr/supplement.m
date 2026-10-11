function R=supplement(data,cfg)
R=struct('available',false,'coverage',table);
D=data.DISPATCHLOAD; P=data.DISPATCHPRICE;
if isempty(D), return; end
t=hpr.time(D.SETTLEMENTDATE);
sel=D.DUID=="HPR1" & year(t)>=2025 & hpr.num(D,'RUNNO')==1 & hpr.num(D,'INTERVENTION')==0;
D=D(sel,:); t=t(sel);
if isempty(D), return; end
pt=hpr.time(P.SETTLEMENTDATE); keep=hpr.num(P,'RUNNO')==1 & hpr.num(P,'INTERVENTION')==0;
P=P(keep,:); pt=pt(keep);
T=table;
mon=dateshift(t-minutes(5),'start','month');
for date=unique(mon)'
    m=mon==date; a=D(m,:); at=t(m);
    [match,ix]=ismember(at,pt); pr=hpr.num(P,'RRP'); prices=nan(height(a),1); prices(match)=pr(ix(match));
    expected=days(dateshift(date,'start','month','next')-date)*288;
    x=hpr.num(a,'INITIAL_ENERGY_STORAGE');
    T=[T;table(date,expected,height(a),sum(match),sum(isfinite(x)),sum(x==0), ...
        mean(prices,'omitnan'),'VariableNames',{'Month','ExpectedIntervals','DispatchRecords', ...
        'MatchedPriceIntervals','ValidStoredEnergy','ZeroStoredEnergyReports','MeanMatchedPrice'})];
end
R.available=true; R.coverage=T;
writetable(T,fullfile(cfg.outputFolder,'later_period_coverage.csv'));
end
