module RGrpc
    class Logger
      class << self
        def setup(config)
          config[:logger] = RGrpc::Logger.create(config)
          RGrpc.logger = config[:logger]
  
          m = Module.new do
            def logger
              RGrpc.logger
            end
          end

          GrpcKit::Grpc.extend(m)
        end
  
        def create(config)
          config[:logger] || ServerEngine::DaemonLogger.new(logdev_from_config(config), config)
        end
  
        def logdev_from_config(config)
          case c = config[:log]
          when nil  
            STDERR
          when '-'
            STDOUT
          else
            c
          end
        end
      end
    end
  end