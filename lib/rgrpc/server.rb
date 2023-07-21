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
        raise 'Required at least one service to handle request' if c[:services].empty?

        opts = { bind: bind, port: port }.compact
        RGrpc::Engine.start(c.merge(opts), cluster: Integer(c[workers]))
      end

      def configure
        yield(config_builder)
      end

      def config_builder
        @config_builder ||= RGrpc::ServerConfigBuilder.new
      end
    end
  end
end
