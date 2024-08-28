"""
    Convert a text file to HTML
"""
import sys

with open(sys.argv[1], 'r', encoding='UTF-8') as source:
    with open(sys.argv[2], 'w', encoding='UTF-8') as target:
        for lines in source.readlines():
            target.write("<pre>" + lines + "</pre>")
