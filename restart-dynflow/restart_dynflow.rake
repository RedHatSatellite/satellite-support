require 'get_process_mem'

namespace :foreman_tasks do
  desc "Restart Dynflow when memory limit has exceeded and no extensive tasks are running"
  task :restart_dynflow => 'environment' do
    def memory_limit
      @memory_limit ||= (ENV['MEMORY_LIMIT_GB'] || 1.5).to_f.round(4)
    end

    def active_tasks(world)
      # The type of tasks we care
      label_list = [
        'Actions::Katello::Organization::ManifestRefresh',
        'Actions::Katello::Repository::Sync',
        'Actions::Katello::Repository::Destroy',
        'Actions::Katello::CapsuleContent::Sync',
        'Actions::Katello::ContentView::CapsuleSync',
        'Actions::Katello::ContentView::Publish',
        'Actions::Katello::ContentView::Promote',
        'Actions::Katello::ContentView::Remove'
      ]
      active_states = ['running', 'pending']
      ForemanTasks::Task.where("label in (?) and state in (?)", label_list, active_states).select do |t|
        begin
          execution_plan = ForemanTasks.dynflow.world.persistence.adapter.load_execution_plan(t.external_id)
          # Can't determine which executor is running it so consider it as true for safety
          # Not checking 'start execution' key. Will trust the foreman task state here
          execution_plan["execution_history"].blank? || execution_plan["execution_history"].last["world_id"] == world.id
        rescue KeyError
          # Execution plan not found. Could be an orphaned task
          false
        end
      end
    end

    def terminate_world?(world)
      pid = world.data["meta"]["pid"]
      mem = GetProcessMem.new(pid).gb.round(4)
      puts "Dynflow world with pid: #{pid} currently uses #{mem} GB of memory out of limit: #{memory_limit} GB"
      mem > memory_limit
    end

    def executor_worlds
      ForemanTasks.dynflow.world.coordinator.find_worlds(true).sort_by do |world|
        GetProcessMem.new(world.data["meta"]["pid"]).gb
      end.reverse
    end

    def waiting_processes(pids)
      the_pids = pids.dup
      begin
        Timeout.timeout(90) do
          while the_pids.any?
            sleep 1
            the_pids.each do |pid|
              the_pids.delete(pid) unless Daemons::Pid.running?(pid)
            end
          end
        end
      rescue TimeoutError
        puts "Pid #{the_pids.join(", ")} not exit within timeout killing them forcefully"
        the_pids.each {|pid| Process.kill('KILL', pid)}
        begin
          Timeout.timeout(60) do
            while the_pids.any?
              sleep 1
              the_pids.each do |pid|
                the_pids.delete(pid) unless Daemons::Pid.running?(pid)
              end
            end
          end
        rescue TimeoutError
          puts "Error: Timeout waiting pid #{the_pids.join(", ")} to exit"
          exit 1
        end
      end
    end

    # Multiple monitor processes with the same appname will cause race condition
    # when restarting the dynflow executors. Each monitor process will try to
    # fork multiple executors and too many executors will be started. This code is
    # to workaround this bug by killing duplicate monitor processes.
    all_pids = `pgrep -f  'dynflow_executor.*_monitor'`.split("\n").map(&:strip).map(&:to_i)
    if all_pids.empty?
      puts "Error: Dynflow doesn't seem to be running"
      exit 1
    end

    pid_dir = "/usr/share/foreman/tmp/pids/*"
    wanted_pids = Dir.glob(pid_dir)
                     .select { |f| f =~ /dynflow_executor.*_monitor\.pid/ }
                     .flat_map { |f| File.readlines(f, chomp: true) }
                     .map(&:to_i)

    if (all_pids & wanted_pids).empty?
      puts "Error: Couldn't find any Dynflow executor monitor pid file in #{pid_dir}"
      exit 1
    end

    unwanted_pids = all_pids - wanted_pids
    unwanted_pids.each do |pid|
      puts "Killing unwanted Dynflow executor monitor (pid #{pid})"
      Process.kill('TERM', pid)
    end
    waiting_processes(unwanted_pids)

    tried = 0
    tries = 1
    executors = []
    all_worlds = executor_worlds
    checklist = all_worlds.map(&:id)
    loop do
      all_worlds.each do |world|
        next unless checklist.include?(world.id)
        pid = world.data["meta"]["pid"]
        unless terminate_world?(world)
          checklist.delete(world.id)
          next
        end
        task_count = active_tasks(world).size
        if task_count > 0
          puts "Can't terminate world #{world.id}. Waiting for #{task_count} extensive tasks to finish" if tried < tries
          next
        end
        puts "Terminating world #{world.id} (pid: #{pid})"
        Process.kill('TERM', pid)
        executors << pid
        checklist.delete(world.id)
      end
      break if checklist.empty? || tried >= tries
      tried += 1
      sleep 120
      puts "Timeout waiting for tasks to finish"
    end

    if executors.empty?
      puts "No worlds have been terminated"
      exit
    end

    puts "Waiting for all worlds to terminate"
    waiting_processes(executors)
    puts "#{executors.size} worlds have been terminated successfully"
    puts "Waiting for new worlds to start"
    begin
      Timeout.timeout(180) do
        seen = []
        loop do
          sleep 20
          new_worlds = executor_worlds.map(&:id) - all_worlds.map(&:id)
          new_worlds.each do |wid|
            puts "New world is ready: #{wid}" unless seen.include?(wid)
            seen << wid
          end
          break if new_worlds.size >= executors.size
        end
      end
    rescue TimeoutError
      puts "Error: Timeout waiting for all worlds to start"
      exit 1
    end
    puts "Done!"
  end
end
