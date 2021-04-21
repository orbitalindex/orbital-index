#!/bin/bash

curl -O https://celestrak.com/NORAD/elements/starlink.txt

ABSPATH=$(cd -- "$(dirname "$BASH_SOURCE")"; pwd -P)

echo $ABSPATH

python3 $ABSPATH/filter-starlink.py $PWD/starlink.txt

exit 0
