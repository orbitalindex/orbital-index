## Starlink Coverage Tracker

This is a little html/js site that visualizes current coverage of starlink satellites based on a few variables.

Originally created by [Greg Morenz](http://droid.cafe)

To get started:
1. Download Celestrak's latest active satellite list into the repo's root directory)
```
$ curl -O https://celestrak.com/NORAD/elements/active.txt  
```
2. Filter the list to just Starlink satellites:
```
$ python bin/filter-starlink.py active.txt
```
3. Serve the page locally using python's built in webserver:
```
$ python3 -m http.server 1337
```
4. Open http://localhost:1337

Improvements & contributions welcome!

---

Current version hosted at: https://benlachman.github.io/starlink-coverage/

Original at: http://droid.cafe/starlink
