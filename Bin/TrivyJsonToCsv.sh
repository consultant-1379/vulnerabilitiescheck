#!/bin/bash

echo "Package Name,Locations,VulnerabilityID,Version Installed,Severity,Fixed Version" > $2
jq -r 'select(.Results != null) |.Results[] |select(.Vulnerabilities != null) |select(.Target |contains("testsuite") |not) |.Target as $my_target |.Vulnerabilities[]|[ .PkgName, $my_target, .VulnerabilityID, .InstalledVersion, .Severity, "["+.FixedVersion+"]"] | @csv' $1 >> $2
