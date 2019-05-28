#!/bin/bash
while :
    do
        date >> postgres-monitor-output.log
        echo "select usesysid,usename,state,waiting,query from pg_stat_activity where state = 'active'" | sudo -u postgres psql >> postgres-monitor-output.log
        sleep 30
done
