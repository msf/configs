#!/bin/bash
set -ex

PORT=$1


psql -p $PORT -h localhost -d postgres -c 'create database test;' | tee -a pgbench-results-${PORT}.log

time pgbench -h localhost -p $PORT -i -s 1000 test | tee -a pgbench-results-${PORT}.log
time pgbench -h localhost -p $PORT -P 60 -c 10 -j 2 -T 300 test | tee -a pgbench-results-${PORT}.log

tail -n10 pgbench-results-${PORT}.log




