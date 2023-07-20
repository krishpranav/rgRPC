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

      @spanwed = 0
      @workers = []
      @mutex = Mutex.new
      @waiting = 0

      @min_pool_size.times { span_thread }
      @auto_trimmer = GrpcKit::RpcDispatcher::AutoTrimmer.new(self, interval: interval)
    end

    def schedule(task, &block)
      return if task.nil?

      raise "scheduling new task isnn't alloowed during, shutdown!" if @shutdown

      @tasks.push(block || task)
    end
  end
end
