function write_summary(R,cfg)
T=table;
for service=cfg.services
    b=R.statistics(R.statistics.Days==21 & R.statistics.Period=="before" & R.statistics.Service==service,:);
    a=R.statistics(R.statistics.Days==21 & R.statistics.Period=="after" & R.statistics.Service==service,:);
    T=[T;table(service,b.MeanMW,a.MeanMW,a.MeanMW-b.MeanMW, ...
        'VariableNames',{'Service','BeforeMW','AfterMW','DifferenceMW'})];
end
writetable(T,fullfile(cfg.outputFolder,'report_service_table.csv'));
A=table(strings(0,1),zeros(0,1),zeros(0,1),zeros(0,1), ...
    strings(0,1),strings(0,1), ...
    'VariableNames',{'Check','Days','Expected','Observed','Status','SupportingFile'});
Q=R.quality;
for k=1:height(Q)
    A=add(A,"Dispatch coverage: "+Q.Period(k),Q.Days(k), ...
        Q.ExpectedIntervals(k),Q.DispatchComplete(k),"quality_checks.csv");
    A=add(A,"Price coverage: "+Q.Period(k),Q.Days(k), ...
        Q.ExpectedIntervals(k),Q.PriceComplete(k),"quality_checks.csv");
end
if R.offers.available
    A=add(A,"Daily bid-price matching",NaN,R.offers.quantityRecords, ...
        R.offers.dailyPriceMatches,"matched_offer_records.csv");
    S=R.offers.combinedRegulationSummary;
    for k=1:height(S)
        A=add(A,S.Service(k)+" evaluated intervals",S.Days(k),S.Days(k)*288, ...
            S.EvaluatedGroups(k),"combined_regulation_statistics.csv");
        row=table(S.Service(k)+" envelope exceedances",S.Days(k),0, ...
            S.AboveCombinedEnvelope(k),"not fully evaluated","combined_regulation_checks.csv", ...
            'VariableNames',A.Properties.VariableNames);
        if S.EvaluatedGroups(k)==S.Days(k)*288
            if S.AboveCombinedEnvelope(k)==0, row.Status="passed"; else, row.Status="review"; end
        end
        A=[A;row];
        row.Check=S.Service(k)+" ceiling exceedances";
        row.Observed=S.AboveCombinedCeiling(k); row.Status="not fully evaluated";
        if S.EvaluatedGroups(k)==S.Days(k)*288
            if S.AboveCombinedCeiling(k)==0, row.Status="passed"; else, row.Status="review"; end
        end
        A=[A;row];
    end
end
if R.constraints.available
    C=R.constraints;
    A=add(A,"Constraint RHS matching",NaN,C.fullTrackingRows, ...
        C.fullRHSMatched,"historical_definition_checks.csv");
    A=add(A,"Constraint RHS version agreement",NaN,C.fullTrackingRows, ...
        C.fullRHSVersionAgrees,"historical_definition_checks.csv");
    A=add(A,"Historical definition reconciliation",NaN,height(C.versionChecks), ...
        sum(C.versionChecks.DefinitionFound),"historical_definition_checks.csv");
end
writetable(A,fullfile(cfg.outputFolder,'final_data_checks.csv'));
end
function T=add(T,name,ndays,expected,observed,file)
status="review";
if expected>0 && observed==expected, status="passed"; end
T=[T;table(name,ndays,expected,observed,status,file, ...
    'VariableNames',T.Properties.VariableNames)];
end
