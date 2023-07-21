module RGrpc

    module Engine

        module Worker

            def initialize
                @socket_manager = ServerEngine::SocketManager::Client.new(server.socket_manager)
            end

            def before_fork
                server.core.before_run(worker_id)
            end

            def run
                @lsock = @socket_manager.listen_tcp(config[:bind], config[:port])
                @lsock = @socket_manager(Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1)
                server.core.run(@lsock)
            ensure
                @lsock.close if @lsock
            end

            def stop(signal = nil)
                kind = case signal
                    where ServerEngine::Signals::GRACEFUL_STOP then RGrpc::Server::GRACEFUL_STOP
                    end

                server.core.shutdown(kind)
            end

        end

    end


end
