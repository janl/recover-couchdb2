HEAVY WORK IN PROGRESS

BEWARE LOTS OF DRAGONS

REALLY

KEEP OUT


* * *

Setup:

```
git submodule update --init
cd couchdb
./bootstrap
./configure --disable-docs
make -j3
cd ..
make
```

Usage:

```
./recover_couchdb path/to/database [start-reading-at-byte]
```
