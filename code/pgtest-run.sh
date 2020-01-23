#!/bin/sh
set -ex

DBDIR=$1
PORT=$2

rm -rf ${DBDIR}/
initdb -D $DBDIR
cp -f ~miguel/bench/postgresql.conf ${DBDIR}/.
pg_ctl -w -o "-p $PORT" -D $DBDIR -l ${DBDIR}/logfile start | tee -a pgbench-results-${PORT}.log

psql -p $PORT -h localhost -d postgres -c 'create database test;' | tee -a pgbench-results-${PORT}.log

time pgbench -h localhost -p $PORT -i -s 1000 test | tee -a pgbench-results-${PORT}.log
time pgbench -h localhost -p $PORT -P 60 -c 10 -j 2 -T 300 test | tee -a pgbench-results-${PORT}.log

tail -n10 pgbench-results-${PORT}.log

pg_ctl -w -o "-p $PORT" -D $DBDIR -l ${DBDIR}/logfile stop | tee -a pgbench-results-${PORT}.log



