#!/bin/bash

if [ $# -eq 0 ] ; then
    echo "USAGE: $(basename $0) columnName1 columnName2 columnName3 ..."
    exit 1
fi

argc=$#
argv=("$@")

for (( name=0; name<argc; name++ ))
do
    if [ $name -ne 0 ]; then
        echo -n ","
    fi
    echo -n "${argv[name]}"
done

echo

for (( name=0; name<argc; name++ ))
do
    if [ $name -ne 0 ]; then
        echo -n ","
    fi
    echo -n $(( $RANDOM % 100)) # Values: 0-99
done

echo
