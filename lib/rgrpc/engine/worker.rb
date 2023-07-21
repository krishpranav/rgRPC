module RGrpc
    module Engine
      module Worker
        def initialize
          @socket_manager = ServerEngine::SocketManager::Client.new(server.socket_manager_path)
        end
  
        def before_fork
          server.core.before_run(worker_id)
        end
  
        def run
          @lsock = @socket_manager.listen_tcp(config[:bind], config[:port])
          @lsock.setsockopt(Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1)
          server.core.run(@lsock)
        ensure
          @lsock.close if @lsock
        end
  
        def stop(signal = nil)
          kind = case signal
                 when ServerEngine::Signals::GRACEFUL_STOP then RGrpc::Server::GRACEFUL_SHUTDOWN
                 when ServerEngine::Signals::IMMEDIATE_STOP then RGrpc::Server::FORCE_SHUTDOWN
                 when ServerEngine::Signals::GRACEFUL_RESTART then RGrpc::Server::GRACEFUL_RESTART
                 else RGrpc::Server::GRACEFUL_SHUTDOWN
                 end
          server.core.shutdown(kind)
        end
  
        def install_signal_handlers
          w = self
          ServerEngine::SignalThread.new do |st|
            st.trap(ServerEngine::Signals::GRACEFUL_STOP) { |s| w.stop(s) }
            st.trap(ServerEngine::Signals::IMMEDIATE_STOP, 'SIG_DFL')
  
            st.trap(ServerEngine::Signals::GRACEFUL_RESTART) { |s| w.stop(s) }
            st.trap(ServerEngine::Signals::IMMEDIATE_RESTART, 'SIG_DFL')
  
            st.trap(ServerEngine::Signals::RELOAD) {
              w.logger.reopen!
              w.reload
            }
            st.trap(ServerEngine::Signals::DETACH) { |s| w.stop(s) }
  
            st.trap(ServerEngine::Signals::DUMP) { w.dump }
          end
        end
      end
    end
  end