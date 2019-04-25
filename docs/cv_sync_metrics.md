# cv_sync_metrics.rake
## Usage instructions
1. Download the script `cv_sync_metrics.rake` on your Satellite in the directory `/usr/share/foreman/lib/tasks`.
2. Usage:
   Default run (last 7 days)
   ```console
    # foreman-rake cv_sync_metrics
   ```
   Specify number of days
   ```console
    # foreman-rake cv_sync_metrics DAYS=21
   ```
3. The report is stored in `/tmp/cv_sync_metrics.txt` and it shows the runtime of capsule tasks with the break down of the plan time and the execution time.  The results are sorted by the long-running tasks on the top.  
   Sample output:
   ```console
   # foreman-rake cv_sync_metrics DAYS=9
   # cat /tmp/cv_sync_metrics.txt
   ForemanTaskId                            Start Time                   End Time             Duration(min)  Total planning(min)  Total execution(min)
   bc111aaf-a74a-4c55-81f5-54b3e423f49d   2019-04-18 18:51:14 UTC   2019-04-18 18:53:48 UTC        3              0.26              3
   6d835297-b157-49c5-b281-5e7f0d52478f   2019-04-18 18:51:30 UTC   2019-04-18 18:54:02 UTC        3              0.27              3
   ```
