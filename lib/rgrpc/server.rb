require 'grpc_kit'
require 'rgrpc/engine'
require 'rgrpc/server_config_builder'
require 'rgrpc/thread_pool'

module RGrpc
  class Server
    DEFAULT_BACKLOG_SIZE = 1024

    GRACEFUL_SHUTDOWN = '0'
    FORCIBLE_SHUTDOWN = '1'
    GRACEFUL_RESTART = '2'

    class << self
      def run(bind: nil, port: nil)
        c = config_builder.build
        raise 'Required at least one service to handle reqeust' if c[:services].empty?

        opts = { bind: bind, port: port }.compact
        RGrpc::Engine.start(c.merge(opts), cluster: Integer(c[:workers]) > 1)
      end

      def configure
        yield(config_builder)
      end

      def config_builder
        @config_builder ||= RGrpc::ServerConfigBuilder.new
      end
    end

    def initialize(min_pool_size:, max_pool_size:, min_connection_size:, max_connection_size:, interceptors: [],
                   shutdown_timeout: 30, settings: [], max_receive_message_size: nil, max_send_message_size: nil, **opts)
      @min_connection_size = min_connection_size
      @max_connection_size = max_connection_size
      @server = GrpcKit::Server.new(
        interceptors: interceptors,
        shutdown_timeout: shutdown_timeout,
        min_pool_size: min_pool_size,
        max_pool_size: max_pool_size,
        max_receive_message_size: max_receive_message_size,
        max_send_message_size: max_send_message_size,
        settings: settings
      )
      @opts = opts
      @status = :run
      @worker_id = 0
    end

    def handle(handler)
      @server.handle(handler)
      klass = handler.is_a?(Class) ? handler : handler.class
      klass.rpc_descs.each_key do |path|
        RGrpc.logger.info("Handle #{path}")
      end
    end

    def before_run(worker_id = 0)
      @worker_id = worker_id

      @socks = []
      @command, @signal = IO.pipe
      @socks << @command
    end

    def run(sock, blocking: true)
      @socks << sock

      @thread_pool = RGrpc::ThreadPool.new(min: @min_connection_size, max: @max_connection_size) do |conn|
        @server.run(conn)
      end

      if blocking
        handle_server
      else
        Thread.new { handle_server }
      end
    end

    def shutdown(reason = GRACEFUL_SHUTDOWN)
      @signal.write(reason)
    end

    private

    def handle_server
      while @status == :run
        io = IO.select(@socks, [], [])

        io[0].each do |sock|
          break if sock == @command && handle_command

          break unless @thread_pool.resouce_available?

          begin
            conn = sock.accept_nonblock
            @thread_pool.schedule(conn)
          rescue IO::WaitReadable, Errno::EINTR => e
            RGrpc.logger.debug("Error raised #{e}")
          end
        end
      end

      @thread_pool.shutdown
      @command.close
      @signal.close
    end

    def handle_command
      case @command.read(1)
      when FORCIBLE_SHUTDOWN
        RGrpc.logger.info("Shutting down sever(id=#{@worker_id}) forcibly...")

        @status = :halt
        @server.force_shutdown
        true
      when GRACEFUL_SHUTDOWN
        RGrpc.logger.info("Shutting down sever(id=#{@worker_id}) gracefully...")

        @status = :stop
        @server.graceful_shutdown
        true
      when GRACEFUL_RESTART
        RGrpc.logger.info("Restart sever(id=#{@worker_id}) gracefully...")

        @status = :restart

        @server.graceful_shutdown(timeout: false)
        true
      end
    end
  end
end
