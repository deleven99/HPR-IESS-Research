function self_test_hpr(verbose)
if nargin<1, verbose=true; end
root=fileparts(mfilename('fullpath')); addpath(root);
assert(isequal(hpr.time(["2024/09/24 11:05:00";"2024-09-24 11:10:00"]), ...
    [datetime(2024,9,24,11,5,0);datetime(2024,9,24,11,10,0)]));
assert(isnat(hpr.time("")));
p=[-30;0;25;50;75;100;120];
q=hpr.trapezoid(p,80,0,25,75,100,80);
assert(max(abs(q-[0;0;80;80;80;0;0]))<1e-10);
q=hpr.trapezoid([0;50;100],80,0,0,100,100,20);
assert(isequal(q,[20;20;20])); % Vertical sides, band ceiling.
assert(isnan(hpr.trapezoid(0,80,10,0,50,100,80))); % Invalid ordering.
oldLoad=hpr.trapezoid(40,85,0,0,35,120,85);
wrongNet=hpr.trapezoid(-40,85,0,0,35,120,85);
assert(oldLoad>0 && wrongNet==0);
new=hpr.trapezoid(-40,85,-120,-35,150,150,85);
assert(new>0);
E=table(repmat(datetime(2024,9,25,1,45,0),2,1),repmat("HPR1",2,1), ...
    repmat("LOWERREG",2,1),["GEN";"LOAD"],[32;32],[35;35],[80;80], ...
    [150;120],[0;-80],[80;0],[80;0],[80;0], ...
    'VariableNames',{'Time','DUID','Service','Direction','NativeTargetMW', ...
    'EnabledMW','MaxAvail','BandSum','ENABLEMENTMIN','LOWBREAKPOINT', ...
    'HIGHBREAKPOINT','ENABLEMENTMAX'});
C=hpr.combine_regulation(E);
assert(C.DiagnosticAvailable && abs(C.CombinedEnvelopeMW-112)<1e-10);
assert(C.DiagnosticAboveCombinedEnvelope==0);
E.EnabledMW(:)=113; C=hpr.combine_regulation(E);
assert(C.DiagnosticAboveCombinedEnvelope==1);
E.EnabledMW(:)=35; E.LOWBREAKPOINT(1)=40;
C=hpr.combine_regulation(E);
assert(~C.GeometryValid && isnan(C.DiagnosticAboveCombinedEnvelope));
C=hpr.combine_regulation(E(1,:));
assert(~C.DiagnosticAvailable && isnan(C.DiagnosticAboveCombinedEnvelope));
E.LOWBREAKPOINT(1)=80; E.MaxAvail(2)=0; E.BandSum(2)=0;
C=hpr.combine_regulation(E);
assert(C.DiagnosticAvailable && C.CombinedMaxAvailMW==80);
assert(hpr.quantile([1;2;3;4],.5)==2.5);
assert(isnan(hpr.quantile([NaN;NaN],.95)));
temp=tempname; mkdir(temp); cleanup=onCleanup(@() rmdir(temp,'s'));
cfg=hpr_config(temp,fullfile(temp,'HPR_results')); mkdir(cfg.outputFolder); mkdir(cfg.cacheFolder);
file=fullfile(temp,'PUBLIC_ARCHIVE#DISPATCHLOAD#FILE01#fixture.csv');
fid=fopen(file,'w');
fprintf(fid,'C,TEST\nI,DISPATCH,UNIT_SOLUTION,5,SETTLEMENTDATE,RUNNO,DUID,INTERVENTION,TOTALCLEARED,AVAILABILITY\n');
fprintf(fid,'D,DISPATCH,UNIT_SOLUTION,5,2024/09/24 11:05:00,1,HPR1,0,-5,80\n');
fprintf(fid,'D,DISPATCH,UNIT_SOLUTION,5,2024/09/24 11:05:00,1,OTHER,0,99,100\n');
fprintf(fid,'C,END OF REPORT,2\n'); fclose(fid);
cfg.chunkRows=1; inv=hpr.inventory(cfg); T=hpr.load_data(inv,"DISPATCHLOAD",cfg,strings(0,1));
assert(height(T)==1 && T.DUID=="HPR1" && hpr.num(T,'TOTALCLEARED')==-5);
cfg.chunkRows=100000; cfg.rebuildCache=true;
T=hpr.load_data(inv,"DISPATCHLOAD",cfg,strings(0,1));
assert(height(T)==1 && T.DUID=="HPR1" && hpr.num(T,'TOTALCLEARED')==-5);
failed=false;
try, hpr.check_unique([T;T],{'SETTLEMENTDATE','DUID'},'test');
catch err, failed=strcmp(err.identifier,'HPR:DuplicateKey'); end
assert(failed);
file=fullfile(temp,'PUBLIC_PRICES_fixture.CSV'); fid=fopen(file,'w');
fprintf(fid,'C,TEST\nI,DREGION,,2,SETTLEMENTDATE,RUNNO,REGIONID,INTERVENTION,RRP,RAISE6SECRRP\n');
fprintf(fid,'D,DREGION,,2,2026/03/01 00:05:00,1,SA1,0,-10,0.5\n');
fprintf(fid,'D,DREGION,,2,2026/03/01 00:05:00,1,NSW1,0,100,10\n');
fprintf(fid,'I,DREGION,,3,SETTLEMENTDATE,RUNNO,REGIONID,INTERVENTION,RRP,RAISE6SECRRP,EXTRA\n');
fprintf(fid,'D,DREGION,,3,2026/03/01 00:05:00,1,SA1,0,-10,0.5,x\nC,END\n'); fclose(fid);
T=hpr.read_public_prices(string(file),cfg); T=unique(T,'rows');
assert(height(T)==1 && hpr.num(T,'RRP')==-10);
assert(isnan(hpr.num(T,'LOWER1SECRRP')));
F=table(["2024/09/10 00:05:00";"2024/09/10 00:10:00";"2024/09/25 00:05:00"], ...
    ["A";"A";"B"],repmat("SA1",3,1),repmat("RAISE6SEC",3,1), ...
    repmat("1",3,1),repmat("0",3,1),repmat("2020/05/01 00:00:00",3,1), ...
    ["1";"1";"2"], ...
    'VariableNames',{'SETTLEMENTDATE','GENCONID','REGIONID','BIDTYPE', ...
    'RUNNO','INTERVENTION','GENCONEFFECTIVEDATE','GENCONVERSIONNO'});
D=table(F.SETTLEMENTDATE,F.GENCONID,F.RUNNO,F.INTERVENTION, ...
    F.GENCONEFFECTIVEDATE,["1";"1";"1"], ...
    'VariableNames',{'SETTLEMENTDATE','CONSTRAINTID','RUNNO','INTERVENTION', ...
    'GENCONID_EFFECTIVEDATE','GENCONID_VERSIONNO'});
G=table(["A";"B"],repmat("2020/05/01 00:00:00",2,1),["1";"1"], ...
    ["Test A";"Test B"],["LE";"LE"], ...
    'VariableNames',{'GENCONID','EFFECTIVEDATE','VERSIONNO','DESCRIPTION','CONSTRAINTTYPE'});
data=struct('DISPATCH_FCAS_REQ',F,'DISPATCHCONSTRAINT',D,'GENCONDATA',G);
R=hpr.analyse_constraints(data,cfg);
assert(R.fullTrackingRows==3 && R.fullRHSMatched==3);
assert(R.fullRHSVersionAgrees==2 && R.fullDefinitionMatched==2);
assert(height(R.versionChecks)==2 && sum(R.versionChecks.DefinitionFound)==1);
assert(sum(R.versionChecks.TrackingRows)==3);
M=hpr.missing_files(data,inv,cfg,R);
assert(any(contains(M.DownloadURL,"PUBLIC_DVD_GENCONDATA_202005010000.zip")));
data.GENCONDATA.VERSIONNO(2)="2";
data.DISPATCHCONSTRAINT.GENCONID_VERSIONNO(3)="2";
R=hpr.analyse_constraints(data,cfg);
assert(all(R.versionChecks.DefinitionFound) && isempty(R.missingDefinitions));
assert(R.fullDefinitionMatched==3 && R.fullRHSVersionAgrees==3);
if verbose, fprintf('HPR self-tests passed: native coordinates, missing values, duplicates and ingestion.\n'); end
end
