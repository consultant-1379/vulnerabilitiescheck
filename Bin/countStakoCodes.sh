#!/bin/bash

report_file=$1
summary_file=$2

esw4_count=$(grep -E "\"STAKO\": +\"ESW4\"" "$report_file" |wc -l)
esw3_count=$(grep -E "\"STAKO\": +\"ESW3\"" "$report_file" |wc -l)
esw2_count=$(grep -E "\"STAKO\": +\"ESW2\"" "$report_file" |wc -l)
esw1_count=$(grep -E "\"STAKO\": +\"ESW1\"" "$report_file" |wc -l)
null_count=$(grep -E "\"STAKO\": +null" "$report_file" |wc -l)

echo "ESW4,ESW3,ESW2,ESW1,N/A" > "$summary_file"
echo "$esw4_count","$esw3_count","$esw2_count","$esw1_count","$null_count" >> "$summary_file"
