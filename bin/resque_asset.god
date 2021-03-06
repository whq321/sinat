root =  File.expand_path('../..', __FILE__)

env  =  ENV["RACK_ENV"] ||= "production"

God.pid_file_directory = "#{root}"

num_workers = (env == 'production') ? 4 : 2

num_workers.times do |num|
God.watch do |w|
    w.dir = "#{root}"
    w.name     = "resque-asset-#{num}"
    w.group    = "resque-asset"
    w.interval = 30.seconds
    w.env      = {}
    w.start = "bundle exec resque work -q test_resque,image_upload,upload_ad_image -r #{root}/job.rb"
    w.pid_file = File.join("#{root}", "tmp/pids/resque-asset.#{num}.pid")

    w.behavior(:clean_pid_file)
	
    # restart if memory gets too high
    w.transition(:up, :restart) do |on|
      on.condition(:memory_usage) do |c|
        c.above = 350.megabytes
        c.times = 2
      end
    end

    # determine the state on startup
    w.transition(:init, { true => :up, false => :start }) do  |on|
      on.condition(:process_running) do |c|
        c.running = true
      end
    end

    # determine when process has finished starting
    w.transition([:start, :restart], :up) do |on|
      on.condition(:process_running) do |c|
        c.running = true
        c.interval = 5.seconds
      end
      # failsafe
      on.condition(:tries) do |c|
        c.times = 5
        c.transition = :start
        c.interval = 5.seconds
      end
    end

    # start if process is not running
    w.transition(:up, :start) do |on|
      on.condition(:process_running) do |c|
        c.running = false
      end
    end
 end
end
