module RGrpc
    class ServerConfigBuilder
        SERVERENGINE_PRIMITIVE_CONFIGS = %i[workers bind port log pid_path].freeze
        SERVERENGINE_BLOCK_CONFIGS = %i[before_fork after_fork].freeze

        SERVERENGINE_FIXED_CONFIGS = %i[daemonize worker_type worker_process_name].freeze

        DEFAULT_POOL_SIZE = 20
        DEFAULT_CONNECTION_SIZE = 3 

        RGRPC_CONFIGS = [
            :max_pool_size,
            :min_pool_size,
            :max_connection_size,
            :min_connection_size,
            :max_receive_message_size,
            :max_send_message_size
        ].freeze

        GRPC_CONFIGS = %i[services interceptors].freeze

        ServerConfig = Struct.new(*(SERVERENGINE_PRIMITIVE_CONFIGS + SERVERENGINE_BLOCK_CONFIGS))
            def to_h
                super.compact
            end
        end

        def initialize
            @opts = DEFAULT_SERVER_CONFIG.dup
        end

        (SERVERENGINE_PRIMITIVE_CONFIGS).each do |name|
            define_method(name) do |value|
                @opts[name] = value
            end
        end

        SERVERENGINE_BLOCK_CONFIGS.each do |name|
            define_method(name) do |&block|
                @opts[name] = block
            end
        end

        def pool_size(min, max)
            @opts[:min_pool_size] = Integer(min)
            @opts[:max_pool_size] = Integer(max)
        end

    end

end
