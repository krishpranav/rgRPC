require 'grpc_kit/rpc_dispatcher/auto_trimmer'

module RGrpc
  class ThreadPool
    DEFAULT_MAX = 5
    DEFAULT_MIN = 1
    QUEUE_SIZE = 128

    def initialize(interval: 60, max: DEFAULT_MAX, min: DEFAULT_MIN, &block)
      @max_pool_size = max
      @min_pool_size = min
      @block = block
      @shutdown = false
      @tasks = SizedQueue.new(QUEUE_SIZE)

      @spawned = 0
      @workers = []
      @mutex = Mutex.new
      @waiting = 0

      @min_pool_size.times { spawn_thread }
      @auto_trimmer = GrpcKit::RpcDispatcher::AutoTrimmer.new(self, interval: interval + rand(10)).tap(&:start!)
    end

    def schedule(task, &block)
      if task.nil?
        return
      end

      if @shutdown
        raise "scheduling new task isn't allowed during shutdown"
      end

      @tasks.push(block || task)

      if @mutex.synchronize { (@waiting < @tasks.size) && (@spawned < @max_pool_size) }
        spawn_thread
      end
    end

    def resouce_available?
      (@waiting != 0) || (@spawned != @max_pool_size)
    end

    def shutdown
      @shutdown = true
      @max_pool_size.times { @tasks.push(nil) }
      @auto_trimmer.stop
      until @workers.empty?
        RGrpc.logger.debug("Shutdown waiting #{@waiting} workers")
        sleep 1
      end
    end

    def trim(force = false)
      if @mutex.synchronize { (force || (@waiting > 0)) && (@spawned > @min_pool_size) }
        GrpcKit.logger.info("Trim worker! Next worker size #{@spawned - 1}")
        @tasks.push(nil)
      end
    end

    private

    def spawn_thread
      @spawned += 1
      worker = Thread.new(@spawned) do |i|
        Thread.current.name = "RGrpc worker thread #{i}"
        RGrpc.logger.debug("#{Thread.current.name} started")

        loop do
          if @shutdown
            break
          end

          @mutex.synchronize { @waiting += 1 }
          task = @tasks.pop
          @mutex.synchronize { @waiting -= 1 }
          if task.nil?
            break
          end

          begin
            @block.call(task)
          rescue Exception => e 
            RGrpc.logger.error("An error occured on top level in worker #{Thread.current.name}: #{e.message} (#{e.class})\n #{Thread.current.backtrace.join("\n")}  ")
          end
        end

        RGrpc.logger.debug("worker thread #{Thread.current.name} is stopping")
        @mutex.synchronize do
          @spawned -= 1
          @workers.delete(worker)
        end
      end

      @workers.push(worker)
    end
  end
end