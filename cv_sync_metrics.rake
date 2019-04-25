desc <<-DESC.strip_heredoc
  Export Content View Capsule sync tasks metrics based on filter. ENV variables:
   * DAYS     : Number of days to go back
  If DAYS is not defined, it defaults to tasks in the past 7 days.
DESC
task :cv_sync_metrics => ["environment"] do
  puts "Task started. This may take a while depending on the number of tasks..."

  # By default query last 7 days
  number_of_days_to_query = 7.days

  # If DAYS is supplied by the user, use it
  if not ENV['DAYS'].nil?
    number_of_days_to_query = ENV['DAYS'].to_i.days
  end

  output_file = '/tmp/cv_sync_metrics.txt'
  f = File.new(output_file, 'w')

  f.write "ForemanTaskId                            Start Time                   End Time             Duration(min)  Total planning(min)  Total execution(min)\n"

  # Query only Actions::Katello::CapsuleContent::Sync tasks with state = stopped and started_at > number_of_days_to_query
  tasks = ForemanTasks::Task.where(:label => "Actions::Katello::CapsuleContent::Sync").where(:state => 'stopped').where("result !=?", 'error').where("started_at > ?", DateTime.now - number_of_days_to_query); 0

  # Sort by long running tasks first
  tasks = tasks.sort_by {|task| -(task.ended_at - task.started_at)}; 0

  tasks.each do |task|
    #puts "foreman_task_id is #{task.id}"
    execplan = task.execution_plan
    plan_values = execplan.steps.values

    plansteps = plan_values.select { |plan| plan.class == Dynflow::ExecutionPlan::Steps::PlanStep}
    runsteps = plan_values.select { |plan| plan.class == Dynflow::ExecutionPlan::Steps::RunStep}

    if plansteps.count != 0
      started_at = plansteps.map(&:started_at).min
      ended_at = plansteps.map(&:ended_at).max
      total_planning_time = ((ended_at - started_at)/60).round(2)
    end; 0

    if runsteps.count != 0
      started_at = runsteps.map(&:started_at).min
      ended_at = runsteps.map(&:ended_at).max
      total_running_time = ((ended_at - started_at)/60).ceil
    end; 0

    f.write "#{task.id}   #{task.started_at}   #{task.ended_at}        #{((task.ended_at - task.started_at)/60).ceil}              #{total_planning_time}              #{total_running_time}\n"
  end.count
  puts "Report generated, available at /tmp/cv_sync_metrics.txt."
end
