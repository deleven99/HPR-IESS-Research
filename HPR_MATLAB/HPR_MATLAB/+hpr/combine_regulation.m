function C=combine_regulation(E)
names={'Time','DUID','Service','NativeTargetMW','EnabledMW','MaxAvail', ...
    'BandSum','ENABLEMENTMIN','LOWBREAKPOINT','HIGHBREAKPOINT','ENABLEMENTMAX'};
reg=E.DUID=="HPR1" & ismember(E.Service,["RAISEREG","LOWERREG"]);
G=E(reg & E.Direction=="GEN",names); L=E(reg & E.Direction=="LOAD",names);
hpr.check_unique(G,{'Time','DUID','Service'},'GEN regulation offers');
hpr.check_unique(L,{'Time','DUID','Service'},'LOAD regulation offers');
key=@(T) string(T.Time)+"|"+T.DUID+"|"+T.Service;
U=unique(E(reg,{'Time','DUID','Service'}),'rows'); n=height(U);
[gm,gi]=ismember(key(U),key(G)); [lm,li]=ismember(key(U),key(L));
C=U; C.NativeTargetMW=nan(n,1); C.EnabledMW=nan(n,1);
C.CombinedMaxAvailMW=nan(n,1); C.CombinedBandSumMW=nan(n,1);
C.CombinedEnablementMinMW=nan(n,1); C.CombinedLowBreakpointMW=nan(n,1);
C.CombinedHighBreakpointMW=nan(n,1); C.CombinedEnablementMaxMW=nan(n,1);
C.CombinedSimpleCeilingMW=nan(n,1); C.CombinedEnvelopeMW=nan(n,1);
C.GeometryValid=false(n,1); C.DiagnosticAvailable=false(n,1);
C.DiagnosticAboveCombinedEnvelope=nan(n,1);
C.DiagnosticAboveCombinedCeiling=nan(n,1);
C.Status=repmat("missing directional offer",n,1);
tol=1e-7;
for k=find(gm & lm)'
    g=G(gi(k),:); l=L(li(k),:);
    C.NativeTargetMW(k)=g.NativeTargetMW; C.EnabledMW(k)=g.EnabledMW;
    q=[g.MaxAvail,l.MaxAvail]; b=[g.BandSum,l.BandSum];
    endpoints=[l.ENABLEMENTMIN,g.ENABLEMENTMAX];
    active=q>tol;
    valid=all(isfinite([q,b,endpoints,l.ENABLEMENTMAX,g.ENABLEMENTMIN])) && ...
        all(q>=0) && all(b>=0) && ...
        abs(l.ENABLEMENTMAX)<=tol && abs(g.ENABLEMENTMIN)<=tol;
    C.Status(k)="invalid or incompatible directional geometry";
    if ~valid, continue; end
    lo=[g.LOWBREAKPOINT-g.ENABLEMENTMIN,l.LOWBREAKPOINT-l.ENABLEMENTMIN];
    hi=[g.ENABLEMENTMAX-g.HIGHBREAKPOINT,l.ENABLEMENTMAX-l.HIGHBREAKPOINT];
    order=[g.LOWBREAKPOINT<=g.HIGHBREAKPOINT,l.LOWBREAKPOINT<=l.HIGHBREAKPOINT];
    if any(~isfinite([lo(active),hi(active)])) || ...
            any(lo(active)<-tol) || any(hi(active)<-tol) || any(~order(active))
        continue
    end
    if any(active)
        sl=lo(active)./q(active); sh=hi(active)./q(active);
        if max(sl)-min(sl)>tol || max(sh)-min(sh)>tol, continue; end
        lowerSlope=mean(sl); upperSlope=mean(sh);
    else
        lowerSlope=0; upperSlope=0;
    end
    m=sum(q); bands=sum(b); emin=endpoints(1); emax=endpoints(2);
    low=emin+m*lowerSlope; high=emax-m*upperSlope;
    if emin>low+tol || low>high+tol || high>emax+tol, continue; end
    if low>high, midpoint=(low+high)/2; low=midpoint; high=midpoint; end
    C.GeometryValid(k)=true; C.CombinedMaxAvailMW(k)=m;
    C.CombinedBandSumMW(k)=bands; C.CombinedEnablementMinMW(k)=emin;
    C.CombinedLowBreakpointMW(k)=low; C.CombinedHighBreakpointMW(k)=high;
    C.CombinedEnablementMaxMW(k)=emax; C.CombinedSimpleCeilingMW(k)=min(m,bands);
    C.CombinedEnvelopeMW(k)=hpr.trapezoid(g.NativeTargetMW,m,emin,low,high,emax,bands);
    C.Status(k)="geometry valid; dispatch unavailable or inconsistent";
    sameDispatch=all(isfinite([g.NativeTargetMW,l.NativeTargetMW,g.EnabledMW,l.EnabledMW])) && ...
        abs(g.NativeTargetMW-l.NativeTargetMW)<=tol && abs(g.EnabledMW-l.EnabledMW)<=tol;
    if ~sameDispatch || ~isfinite(C.CombinedEnvelopeMW(k)), continue; end
    C.DiagnosticAvailable(k)=true; C.Status(k)="evaluated";
    C.DiagnosticAboveCombinedEnvelope(k)=g.EnabledMW>C.CombinedEnvelopeMW(k)+1e-3;
    C.DiagnosticAboveCombinedCeiling(k)=g.EnabledMW>C.CombinedSimpleCeilingMW(k)+1e-3;
end
end
