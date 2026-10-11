function R=analyse_constraints(data,cfg)
R=struct('available',false,'coverage',table,'missingDefinitions',table);
F=data.DISPATCH_FCAS_REQ; C=data.DISPATCHCONSTRAINT; G=data.GENCONDATA;
if isempty(F) || isempty(C)
    fprintf('Constraint linkage skipped: FCAS tracking or dispatch equations missing.\n'); return
end
F=F(hpr.num(F,'RUNNO')==1 & hpr.num(F,'INTERVENTION')==0,:);
C=C(hpr.num(C,'RUNNO')==1 & hpr.num(C,'INTERVENTION')==0,:);
if isempty(F) || isempty(C), return; end
F.Time=hpr.time(F.SETTLEMENTDATE); C.Time=hpr.time(C.SETTLEMENTDATE);
F.Effective=hpr.time(F.GENCONEFFECTIVEDATE); C.Effective=hpr.time(C.GENCONID_EFFECTIVEDATE);
F.DefVersion=hpr.num(F,'GENCONVERSIONNO'); C.DefVersion=hpr.num(C,'GENCONID_VERSIONNO');
hpr.check_unique(F,{'Time','GENCONID','REGIONID','BIDTYPE'},'SA FCAS tracking');
hpr.check_unique(C,{'Time','CONSTRAINTID'},'constraint dispatch');
[rhsMatched,ix]=ismember(string(F.Time)+"|"+F.GENCONID,string(C.Time)+"|"+C.CONSTRAINTID);
versionAgrees=false(height(F),1);
versionAgrees(rhsMatched)=F.Effective(rhsMatched)==C.Effective(ix(rhsMatched)) & ...
    F.DefVersion(rhsMatched)==C.DefVersion(ix(rhsMatched));
definitionMatched=false(height(F),1); definitionC=false(height(C),1);
gidx=zeros(height(C),1); kg=strings(0,1);
if ~isempty(G)
    G.Effective=hpr.time(G.EFFECTIVEDATE); G.DefVersion=hpr.num(G,'VERSIONNO');
    hpr.check_unique(G,{'GENCONID','Effective','DefVersion'},'generic constraint definitions');
    kg=defkey(G.GENCONID,G.Effective,G.DefVersion);
    definitionMatched=ismember(defkey(F.GENCONID,F.Effective,F.DefVersion),kg);
    [definitionC,gidx]=ismember(defkey(C.CONSTRAINTID,C.Effective,C.DefVersion),kg);
end
V=unique(table(F.GENCONID,F.Effective,F.DefVersion, ...
    'VariableNames',{'ConstraintID','EffectiveDate','Version'}),'rows');
fk=defkey(F.GENCONID,F.Effective,F.DefVersion);
vk=defkey(V.ConstraintID,V.EffectiveDate,V.Version);
[~,vi]=ismember(fk,vk);
V.TrackingRows=accumarray(vi,1,[height(V),1]);
V.RHSMatchedRows=accumarray(vi,double(rhsMatched),[height(V),1]);
V.RHSVersionAgreesRows=accumarray(vi,double(versionAgrees),[height(V),1]);
V.DefinitionFound=ismember(vk,kg);
writetable(V,fullfile(cfg.outputFolder,'historical_definition_checks.csv'));
writetable(V(~V.DefinitionFound,:),fullfile(cfg.outputFolder,'missing_historical_versions_all.csv'));
coverage=table; CS=table;
missing=table(strings(0,1),NaT(0,1),zeros(0,1),zeros(0,1),strings(0,1), ...
    'VariableNames',{'ConstraintID','EffectiveDate','Version','Days','Period'});
for ndays=cfg.windows
    for label=["before","after"]
        if label=="before"
            start=cfg.transitionDay-days(ndays)+minutes(5); finish=cfg.transitionDay;
        else
            start=cfg.transitionDay+days(1)+minutes(5); finish=cfg.transitionDay+days(1+ndays);
        end
        m=F.Time>=start & F.Time<=finish;
        uniqueVersion=unique(table(F.GENCONID(m),F.Effective(m),F.DefVersion(m), ...
            'VariableNames',{'ConstraintID','EffectiveDate','Version'}),'rows');
        coverage=[coverage;table(ndays,label,sum(m),sum(m & rhsMatched),sum(m & versionAgrees), ...
            sum(m & definitionMatched),height(uniqueVersion), ...
            'VariableNames',{'Days','Period','TrackingRows','RHSMatchedRows','RHSVersionAgreesRows', ...
            'DefinitionMatchedRows','DistinctReferencedVersions'})];
        a=F(m & ~definitionMatched,:);
        if ~isempty(a)
            u=unique(table(a.GENCONID,a.Effective,a.DefVersion, ...
                'VariableNames',{'ConstraintID','EffectiveDate','Version'}),'rows');
            u.Days=repmat(ndays,height(u),1); u.Period=repmat(label,height(u),1);
            missing=[missing;u];
        end
        cc=C(C.Time>=start & C.Time<=finish,:);
        ids=unique(cc.CONSTRAINTID);
        for id=ids'
            a=cc(cc.CONSTRAINTID==id,:); rhs=hpr.num(a,'RHS'); lhs=hpr.num(a,'LHS');
            mv=hpr.num(a,'MARGINALVALUE'); vio=hpr.num(a,'VIOLATIONDEGREE');
            CS=[CS;table(ndays,label,id,height(a),sum(abs(mv)>cfg.enabledTolerance), ...
                sum(vio>cfg.enabledTolerance),median(rhs,'omitnan'),median(lhs,'omitnan'), ...
                'VariableNames',{'Days','Period','ConstraintID','DispatchRows','NonzeroShadowPriceRows', ...
                'ReportedViolationRows','MedianEquationRHS','MedianEquationLHS'})];
        end
    end
end
hit=contains(upper(C.CONSTRAINTID),'HPR');
if ~isempty(G)
    descr=strings(height(C),1); typ=strings(height(C),1);
    descr(definitionC)=G.DESCRIPTION(gidx(definitionC));
    typ(definitionC)=G.CONSTRAINTTYPE(gidx(definitionC));
    hit=hit | contains(upper(descr),'HORNSDALE');
    C.Description=descr; C.EquationType=typ;
end
if any(hit), writetable(C(hit,:),fullfile(cfg.outputFolder,'hpr_named_constraint_dispatch.csv')); end
if ~isempty(G)
    gd=contains(upper(G.GENCONID),'HPR') | contains(upper(G.DESCRIPTION),'HORNSDALE');
    writetable(G(gd,:),fullfile(cfg.outputFolder,'hpr_constraint_definitions.csv'));
end
R.available=true; R.coverage=coverage; R.missingDefinitions=missing; R.summary=CS;
R.versionChecks=V;
R.fullRHSVersionAgrees=sum(versionAgrees);
R.fullTrackingRows=height(F); R.fullRHSMatched=sum(rhsMatched); R.fullDefinitionMatched=sum(definitionMatched);
writetable(coverage,fullfile(cfg.outputFolder,'constraint_version_coverage.csv'));
writetable(CS,fullfile(cfg.outputFolder,'constraint_context_statistics.csv'));
writetable(missing,fullfile(cfg.outputFolder,'missing_constraint_versions.csv'));
fprintf('Constraint linkage: %d/%d RHS matches, %d exact definitions.\n',sum(rhsMatched),height(F),sum(definitionMatched));
end
function k=defkey(id,effective,version)
k=id+"|"+string(effective)+"|"+string(version);
end
