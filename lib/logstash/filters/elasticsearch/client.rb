# encoding: utf-8
require "elasticsearch"
require "base64"
require "elasticsearch/transport/transport/http/manticore"


module LogStash
  module Filters
    class ElasticsearchClient

      attr_reader :client

      def initialize(logger, hosts, options = {})
        ssl = options.fetch(:ssl, false)
        keystore = options.fetch(:keystore, nil)
        keystore_password = options.fetch(:keystore_password, nil)
        user = options.fetch(:user, nil)
        password = options.fetch(:password, nil)
        api_key = options.fetch(:api_key, nil)
        proxy = options.fetch(:proxy, nil)
        user_agent = options[:user_agent]

        transport_options = {:headers => {}}
        transport_options[:headers].merge!(setup_basic_auth(user, password))
        transport_options[:headers].merge!(setup_api_key(api_key))
        transport_options[:headers].merge!({ 'user-agent' => "#{user_agent}" })

        logger.warn "Supplied proxy setting (proxy => '') has no effect" if @proxy.eql?('')
        transport_options[:proxy] = proxy.to_s if proxy && !proxy.eql?('')

        hosts = setup_hosts(hosts, ssl)

        ssl_options = {}
        # set ca_file even if ssl isn't on, since the host can be an https url
        ssl_options.update(ssl: true, ca_file: options[:ca_file]) if options[:ca_file]
        ssl_options.update(ssl: true, trust_strategy: options[:ssl_trust_strategy]) if options[:ssl_trust_strategy]
        if keystore
          ssl_options[:keystore] = keystore
          logger.debug("Keystore for client certificate", :keystore => keystore)
          ssl_options[:keystore_password] = keystore_password.value if keystore_password
        end

        client_options = {
                       hosts: hosts,
             transport_class: ::Elasticsearch::Transport::Transport::HTTP::Manticore,
           transport_options: transport_options,
                         ssl: ssl_options,
            retry_on_failure: options[:retry_on_failure],
             retry_on_status: options[:retry_on_status]
        }

        logger.info("New ElasticSearch filter client", :hosts => hosts)
        @client = ::Elasticsearch::Client.new(client_options)
      end

      def search(params)
        @client.search(params)
      end

      private

      def setup_hosts(hosts, ssl)
        hosts.map do |h|
          if h.start_with?('http:/', 'https:/')
            h
          else
            host, port = h.split(':')
            { host: host, port: port, scheme: (ssl ? 'https' : 'http') }
          end
        end
      end

      def setup_basic_auth(user, password)
        return {} unless user && password && password.value

        token = ::Base64.strict_encode64("#{user}:#{password.value}")
        { 'Authorization' => "Basic #{token}" }
      end

      def setup_api_key(api_key)
        return {} unless (api_key && api_key.value)

        token = ::Base64.strict_encode64(api_key.value)
        { 'Authorization' => "ApiKey #{token}" }
      end
    end
  end
end
