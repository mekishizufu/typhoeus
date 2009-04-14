module HTTPMachine
  USER_AGENT = "HTTPMachine - http://github.com/pauldix/http-machine/tree/master"
  
  def self.included(base)
    base.extend ClassMethods
  end
    
  module ClassMethods
    def get(url, options = {}, &block)
      if HTTPMachine.multi_running?
        HTTPMachine.add_easy_request(base_easy_object(url, :get, options, block))
      else
        HTTPMachine.service_access do
          get(url, options, &block)
        end
      end
    end
    
    def post(url, options = {}, &block)
      if HTTPMachine.multi_running?
        HTTPMachine.add_easy_request(base_easy_object(url, :post, options, block))
      else
        HTTPMachine.service_access do
          post(url, options, &block)
        end
      end
    end
    
    # def put(url, options = {}, &block)
    #   easy = Curl::Easy.new(url) do |curl|
    #     curl.on_success do |c|
    #       block.call(c.response_code, c.body_str)
    #     end
    #     curl.on_failure do |c|
    #       block.call(c.response_code, c.body_str)
    #     end
    #   end
    #   put_data = params_to_curl_post_fields(options[:params]).collect{|p| p.to_s}.join("&")
    #   easy.http_put(put_data)
    # end
    
    def delete(url, options = {}, &block)
      if HTTPMachine.multi_running?
        HTTPMachine.add_easy_request(base_easy_object(url, :delete, options, block))
      else
        HTTPMachine.service_access do
          delete(url, options, &block)
        end
      end
    end
    
    def base_easy_object(url, method, options, block)
      easy = HTTPMachine::Easy.new
      easy.url = url
      easy.method = method
      easy.headers["User-Agent"] = (options[:user_agent] || HTTPMachine::USER_AGENT)
      easy.params = options[:params] if options[:params]
      easy.request_body = options[:body] if options[:body]
      easy.on_success do |c|
        block.call(c.response_code, c.response_body)
      end
      easy.on_failure do |c|
        block.call(c.response_code, c.response_body)
      end
      easy
    end
    
    def add_params_to_url(url, params)
      if url.include?("?")
        url + "&" + params_to_query_string(params)
      else
        url + "?" + params_to_query_string(params)
      end
    end
    
    def params_to_query_string(params)
      params.keys.collect do |k|
        value = params[k]
        if value.is_a? Hash
          value.keys.collect {|sk| CGI.escape("#{k}[#{sk}]") + "=" + CGI.escape(value[sk].to_s)}
        else
          "#{CGI.escape(k.to_s)}=#{CGI.escape(params[k].to_s)}"
        end
      end.flatten.join("&")
    end
    
    def params_to_curl_post_fields(params)
      params.keys.collect do |k|
        value = params[k]
        if value.is_a? Hash
          value.keys.collect {|sk| Curl::PostField.content("#{k}[#{sk}]", value[sk])}
        else
          Curl::PostField.content(k.to_s, params[k].to_s)
        end
      end.flatten
    end
    
    def remote_server(server)
      @server = server
    end
    
    def add_multi_request(method_name, params, block)
      all_params = @methods[method_name][:params].merge(params)
      params_string = all_params.to_a.map {|a| a.map {|o|o.to_s}.join("=")}.join("&")
      url = "#{@server}?#{params_string}"
      easy = Curl::Easy.new(url) do |curl|
        curl.headers["User-Agent"] = "HTTPMachine - http://github.com/pauldix/http-machine/tree/master"
        curl.on_success do |c|
          block.functionally.call(send(@methods[method_name][:response_handler], c.body_str))
        end
      end
      Thread.current[:curl_multi].add(easy)
    end

    def remote_method(name, args = {})
      args[:method] ||= :get
      args[:params] ||= {}
      @methods ||= {}
      @methods[name] = args
      puts name
      class_eval <<-SRC
        def self.#{name.to_s}(params, &block)
          add_multi_request(:#{name.to_s}, params, block)
        end
      SRC
    end
  end # ClassMethods
end