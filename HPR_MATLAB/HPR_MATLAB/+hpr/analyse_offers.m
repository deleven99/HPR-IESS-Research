function R=analyse_offers(data,dispatch,cfg)
R=struct('available',false,'summary',table,'shapes',table);
B=data.BIDPEROFFER_D; A=data.BIDDAYOFFER_D;
if isempty(B) || isempty(A)
    fprintf('Offer module skipped: interval quantities and daily prices are both needed.\n'); return
end
B.Time=hpr.time(B.INTERVAL_DATETIME);
B.TradingDay=hpr.time(B.SETTLEMENTDATE); A.TradingDay=hpr.time(A.SETTLEMENTDATE);
hpr.check_unique(B,{'TradingDay','DUID','BIDTYPE','DIRECTION','Time'},'interval bids');
hpr.check_unique(A,{'TradingDay','DUID','BIDTYPE','DIRECTION'},'daily bids');
kb=offerkey(B); ka=offerkey(A); [matched,ix]=ismember(kb,ka);
E=table(B.Time,B.TradingDay,B.DUID,B.BIDTYPE,B.DIRECTION,matched, ...
    'VariableNames',{'Time','TradingDay','DUID','Service','Direction','DailyPriceMatched'});
E.MaxAvail=hpr.num(B,'MAXAVAIL');
band=nan(height(B),10);
for k=1:10
    name=sprintf('BANDAVAIL%d',k); band(:,k)=hpr.num(B,name);
    prices=nan(height(B),1); v=hpr.num(A,sprintf('PRICEBAND%d',k));
    prices(matched)=v(ix(matched)); E.(sprintf('PriceBand%d',k))=prices;
end
E.BandSum=sum(band,2); E.SimpleCeilingMW=min(E.MaxAvail,E.BandSum);
for name=["ENABLEMENTMIN","LOWBREAKPOINT","HIGHBREAKPOINT","ENABLEMENTMAX"]
    E.(name)=hpr.num(B,char(name));
end
E.EnergyLimit=hpr.num(B,'ENERGYLIMIT');
D=dispatch.dispatch;
kd=string(D.Time)+"|"+D.DUID; ke=string(E.Time)+"|"+E.DUID;
[dm,di]=ismember(ke,kd);
target=hpr.num(D,'TOTALCLEARED'); E.NativeTargetMW=nan(height(E),1);
E.NativeTargetMW(dm)=target(di(dm)); E.EnabledMW=nan(height(E),1);
for s=cfg.services
    m=dm & E.Service==s; v=hpr.num(D,char(s)); E.EnabledMW(m)=v(di(m));
end
E.OfferedEnvelopeAtTargetMW=hpr.trapezoid(E.NativeTargetMW,E.MaxAvail, ...
    E.ENABLEMENTMIN,E.LOWBREAKPOINT,E.HIGHBREAKPOINT,E.ENABLEMENTMAX,E.BandSum);
E.UtilizationOfSimpleCeiling=nan(height(E),1);
good=E.SimpleCeilingMW>0 & isfinite(E.EnabledMW);
E.UtilizationOfSimpleCeiling(good)=E.EnabledMW(good)./E.SimpleCeilingMW(good);
E.DirectionApplicable=true(height(E),1);
reg=ismember(E.Service,["RAISEREG","LOWERREG"]) & E.DUID=="HPR1";
E.DirectionApplicable(reg)=false;
E.UtilizationOfSimpleCeiling(~E.DirectionApplicable)=NaN;
E.DiagnosticAboveEnvelope=double(E.EnabledMW>E.OfferedEnvelopeAtTargetMW+1e-3 & ...
    E.DirectionApplicable & isfinite(E.OfferedEnvelopeAtTargetMW));
E.DiagnosticAboveSimpleCeiling=double(E.EnabledMW>E.SimpleCeilingMW+1e-3 & E.DirectionApplicable);
E.DiagnosticAboveEnvelope(reg)=NaN; E.DiagnosticAboveSimpleCeiling(reg)=NaN;
C=hpr.combine_regulation(E); CS=hpr.regulation_statistics(C,cfg);
writetable(C,fullfile(cfg.outputFolder,'combined_regulation_checks.csv'));
writetable(CS,fullfile(cfg.outputFolder,'combined_regulation_statistics.csv'));
writetable(E,fullfile(cfg.outputFolder,'matched_offer_records.csv'));
S=table; Missing=table; Shapes=table;
for ndays=cfg.windows
    for label=["before","after"]
        w=dispatch.windows.(sprintf('days%d',ndays)).(label);
        if label=="before", units=["HPRG1","HPRL1"]; else, units="HPR1"; end
        selected=E.Time>=min(w.Time) & E.Time<=max(w.Time) & ismember(E.DUID,units);
        a=E(selected,:);
        groups=unique(a(:,{'DUID','Service','Direction'}),'rows');
        for k=1:height(groups)
            m=a.DUID==groups.DUID(k) & a.Service==groups.Service(k) & a.Direction==groups.Direction(k);
            v=a(m,:); missing=setdiff(w.Time,v.Time);
            row=table(ndays,label,groups.DUID(k),groups.Service(k),groups.Direction(k), ...
                height(v),numel(missing),sum(v.DailyPriceMatched), ...
                min(v.MaxAvail,[],'omitnan'),median(v.MaxAvail,'omitnan'),max(v.MaxAvail,[],'omitnan'), ...
                median(v.SimpleCeilingMW,'omitnan'),mean(v.UtilizationOfSimpleCeiling,'omitnan'), ...
                sum(v.DiagnosticAboveEnvelope),sum(v.DiagnosticAboveSimpleCeiling),sum(isfinite(v.EnergyLimit)), ...
                'VariableNames',{'Days','Period','DUID','Service','Direction','OfferRows','MissingIntervals', ...
                'DailyPriceMatches','MinMaxAvailMW','MedianMaxAvailMW','MaxMaxAvailMW', ...
                'MedianSimpleCeilingMW','MeanEnabledToSimpleCeiling','EnvelopeDiagnosticCount', ...
                'SimpleCeilingDiagnosticCount','NonblankEnergyLimit'});
            S=[S;row];
            if ~isempty(missing)
                Missing=[Missing;table(repmat(ndays,numel(missing),1),repmat(label,numel(missing),1), ...
                    repmat(groups.DUID(k),numel(missing),1),repmat(groups.Service(k),numel(missing),1), ...
                    repmat(groups.Direction(k),numel(missing),1),missing, ...
                    'VariableNames',{'Days','Period','DUID','Service','Direction','Time'})];
            end
            if ndays==21 && ismember(groups.Service(k),cfg.services(1:8))
                row=groups(k,:); row.Period=label;
                shapeNames={'MaxAvail','ENABLEMENTMIN','LOWBREAKPOINT','HIGHBREAKPOINT','ENABLEMENTMAX'};
                [observed,~,shapeIndex]=unique(v(:,shapeNames),'rows');
                frequencies=accumarray(shapeIndex,1); [count,modeIndex]=max(frequencies);
                for name=string(shapeNames)
                    row.(name)=observed.(name)(modeIndex);
                end
                row.ObservedCount=count; row.TotalOfferRows=height(v);
                row.FirstObservedTime=min(v.Time(shapeIndex==modeIndex));
                Shapes=[Shapes;row];
            end
        end
        if label=="before"
            expected=[table(repmat("HPRG1",7,1),["ENERGY";cfg.services(1:4)';cfg.services(9:10)'],repmat("GEN",7,1), ...
                'VariableNames',{'DUID','Service','Direction'}); ...
                table(repmat("HPRL1",7,1),["ENERGY";cfg.services(5:8)';cfg.services(9:10)'],repmat("LOAD",7,1), ...
                'VariableNames',{'DUID','Service','Direction'})];
        else
            expected=table(repmat("HPR1",14,1),["ENERGY";"ENERGY";cfg.services(1:8)';"RAISEREG";"RAISEREG";"LOWERREG";"LOWERREG"], ...
                ["GEN";"LOAD";repmat("BIDIRECTIONAL",8,1);"GEN";"LOAD";"GEN";"LOAD"], ...
                'VariableNames',{'DUID','Service','Direction'});
        end
        absent=setdiff(expected,groups,'rows');
        for k=1:height(absent)
            Missing=[Missing;table(repmat(ndays,height(w),1),repmat(label,height(w),1), ...
                repmat(absent.DUID(k),height(w),1),repmat(absent.Service(k),height(w),1), ...
                repmat(absent.Direction(k),height(w),1),w.Time, ...
                'VariableNames',{'Days','Period','DUID','Service','Direction','Time'})];
        end
    end
end
R.available=true; R.summary=S; R.shapes=Shapes; R.matchRate=mean(matched);
R.quantityRecords=height(B); R.dailyPriceMatches=sum(matched);
R.missingIntervals=Missing;
R.combinedRegulation=C; R.combinedRegulationSummary=CS;
writetable(S,fullfile(cfg.outputFolder,'offer_statistics.csv'));
if ~isempty(Missing), writetable(Missing,fullfile(cfg.outputFolder,'missing_offer_intervals.csv')); end
writetable(Shapes,fullfile(cfg.outputFolder,'representative_offer_shapes.csv'));
fprintf('Daily bid prices: %d/%d quantity records matched (many-to-one).\n',sum(matched),numel(matched));
end
function k=offerkey(T)
k=string(T.TradingDay)+"|"+T.DUID+"|"+T.BIDTYPE+"|"+T.DIRECTION;
end
