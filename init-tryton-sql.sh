#!/bin/bash
set -e

if [ "$REP" ]; then
    cd /data/restore
    wget -c ftp://139.59.135.185/$REP/tryton.sql.gz
fi
