#!/bin/bash

report_file=$1
summary_file=$2

severity_array=($(cut -d',' -f4 < $report_file |tr -d '"'))

critical_count=0
high_count=0
medium_count=0
low_count=0
negligible_count=0

for i in "${severity_array[@]}"
do
  case "$i" in
    "Critical"|"critical")
      ((critical_count=critical_count+1));;
    "High"|"high")
      ((high_count=high_count+1));;
    "Medium"|"medium")
      ((medium_count=medium_count+1));;
    "Low"|"low")
      ((low_count=low_count+1));;
    "Negligible"|"negligible")
      ((negligible_count=negligible_count+1));;
    *) ;;
  esac
done

echo "Critical,High,Medium,Low,Negligible" > "$summary_file"
echo "$critical_count","$high_count","$medium_count","$low_count","$negligible_count" >> "$summary_file"
