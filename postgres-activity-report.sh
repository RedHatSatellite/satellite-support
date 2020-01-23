#!/bin/bash

cd ~postgres

echo ""

PGQUERY="SELECT pid, age(clock_timestamp(), query_start), usename AS dbname, query FROM pg_stat_activity ORDER BY query_start desc;"

echo $PGQUERY | sudo -u postgres psql -d foreman
