HPR RESULTS: FILE CONTENTS

MAIN DATA FILES

quality_checks.csv
Dispatch and price completeness checks for each comparison window.

transition_evidence.csv
First and last availability, energy-target and FCAS records for each HPR unit.

service_statistics.csv
FCAS enablement averages, medians, percentiles, maxima and enablement percentages.

window_sensitivity_and_bootstrap.csv
Mean enablement changes for the 21-day and 14-day windows, with bootstrap intervals.

state_sensitivity.csv
FCAS results by charging, near-zero and discharging state, using different power thresholds.

common_support_comparison.csv
Reweighted before-and-after comparisons using common operating-state, time and price groups.

daily_statistics.csv
Daily average energy prices, power targets and FCAS enablement.

intervals_21d_before.csv
Five-minute dispatch and price data for the 21-day before-transition window.

intervals_21d_after.csv
Five-minute dispatch and price data for the 21-day after-transition window.

intervals_14d_before.csv
Five-minute dispatch and price data for the 14-day before-transition window.

intervals_14d_after.csv
Five-minute dispatch and price data for the 14-day after-transition window.

stored_energy_quality.csv
Stored-energy reporting summaries, including valid records, zero values and reported ranges.

reference_reconciliation.csv
Comparison of calculated service averages with reference values.

registration_records.csv
HPR unit registration details, including unit types, regions and effective dates.

fcas_registration_records.csv
Registered FCAS capacities and enablement parameters for the HPR units.

matched_offer_records.csv
Interval offers matched to daily bid prices and available dispatch observations.

offer_statistics.csv
Offer availability, price-matching counts and applicable offer diagnostics by service and window.

representative_offer_shapes.csv
Parameters and occurrence counts of the most frequent observed contingency FCAS offer shapes.

combined_regulation_checks.csv
Interval-level comparisons of aggregate HPR1 regulation enablement against combined offer limits.

combined_regulation_statistics.csv
Summary counts of evaluated regulation intervals and exceedances for each post-transition window.

constraint_context_statistics.csv
Constraint dispatch counts, shadow-price activity, reported violations and equation RHS/LHS summaries.

CORRECTED REGULATION FILES

corrected_regulation/matched_offer_records_corrected.csv
Offer records with the regulation-related corrections applied.

corrected_regulation/offer_statistics_corrected.csv
Offer statistics with the regulation-related corrections applied.

corrected_regulation/combined_regulation_checks.csv
Detailed combined regulation checks exported by the update procedure.

corrected_regulation/combined_regulation_statistics.csv
Combined regulation summaries exported by the update procedure.

REPORT FIGURES

report_figures/Fig2_observed_offer_shapes
Observed legacy and bidirectional offer shapes for Raise 6 s and Lower 60 s.

report_figures/Fig3_window_comparison
Mean FCAS enablement changes and bootstrap intervals for the two window lengths.

SUPPORTING FIGURES

figures/01_fcas_enablement
Before-and-after mean FCAS enablement and percentage of enabled intervals.

figures/02_window_sensitivity
Comparison of results across window lengths with bootstrap intervals.

figures/03_fcas_by_operating_state
Mean FCAS enablement during charging, near-zero operation and discharging.

figures/04_target_and_reported_energy
Signed power targets and reported stored energy over the main comparison windows.

figures/05_daily_price_context
Daily average South Australian energy prices during the comparison periods.

figures/06_offer_envelopes
Representative Raise 6 s and Lower 6 s offer shapes.

Each figure has PNG, PDF and FIG versions. PNG is suitable for viewing and Word;
PDF is suitable for printing; FIG can be opened and edited in MATLAB.

OTHER FILES

file_inventory.csv
Input-file paths, sizes and modification records.

execution_log.txt
Program execution messages, processing counts and completion records.

research_results.mat
Saved MATLAB results and configuration for further inspection or analysis.
