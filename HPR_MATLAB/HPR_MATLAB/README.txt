HPR MATLAB Package

Requires MATLAB R2021a or newer. No additional toolboxes are required.

1. Extract the ZIP and open HPR_MATLAB_English in MATLAB.
2. Keep the +hpr folder beside run_hpr_research.m.
3. Run:

   self_test_hpr
   run_hpr_research

4. Select the folder containing the downloaded AEMO ZIP or CSV files.
   Include September and October 2024 data and the historical GENCONDATA archives.
   Extract any outer collection ZIP first; individual AEMO ZIP files can stay zipped.
5. Outputs are saved in HPR_results inside the selected data folder.
   Report plots are in report_figures. Check final_data_checks.csv and missing_files.csv.
   Add any required missing archives to the input folder and rerun.

To update regulation checks and report plots from existing results only, run:

   update_hpr_regulation_checks
   make_report_figures

Select the existing HPR_results folder for both commands.
Updated regulation files are saved in corrected_regulation.
This update does not recalculate dispatch or historical constraint coverage.

To specify folders directly:

   run_hpr_research('C:\Users\wz\Desktop\5510\data')

Window settings are in hpr_config.m. All market timestamps use fixed AEST (UTC+10).
