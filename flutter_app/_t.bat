@echo off 
set \"PROGRAMFILES(X86)=C:\Program Files (x86)\" 
cd /d e:\Programming\endpoint-monitor\flutter_app 
flutter test test\em_vital_band_test.dart test\em_vital_sparkline_test.dart test\system_vitals_history_cubit_test.dart 
