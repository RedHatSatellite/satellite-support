#!/bin/bash
while :
    do
        date >> process-monitor-output.log
        ps -aux | sort -rnk6 >> process-monitor-output.log
        echo "" >> process-monitor-output.log
        echo "" >> process-monitor-output.log
        sleep 10
done
