#!/bin/bash

# curl -O https://celestrak.org/NORAD/elements/starlink.txt

curl "https://celestrak.org/NORAD/elements/gp.php?GROUP=starlink&FORMAT=tle" -o starlink.txt

ABSPATH=$(cd -- "$(dirname "$BASH_SOURCE")"; pwd -P)

echo $ABSPATH

python3 $ABSPATH/filter-starlink.py $PWD/starlink.txt

exit 0
