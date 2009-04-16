module HTTPMachine
  class RemoteMethod
    attr_accessor :http_method, :options, :base_uri, :path, :on_success, :on_failure
    
    def initialize(options = {})
      @http_method       = options.delete(:method) || :get
      @options           = options
      @base_uri          = options.delete(:base_uri)
      @path              = options.delete(:path)
      @on_success        = options.delete(:on_success)
      @on_failure        = options.delete(:on_failure)
      @memoize_responses = options.delete(:memoize_responses)
      
      clear_cache
    end
    
    def memoize_responses?
      @memoize_responses
    end
    
    def args_options_key(args, options)
      "#{args.to_s}+#{options.to_s}"
    end
    
    def calling(args, options)
      @called_methods[args_options_key(args, options)] = true
    end
    
    def already_called?(args, options)
      @called_methods.has_key? args_options_key(args, options)
    end
    
    def add_response_block(block, args, options)
      @response_blocks[args_options_key(args, options)] << block
    end
    
    def call_response_blocks(result, args, options)
      key = args_options_key(args, options)
      @response_blocks[key].each {|block| block.call(result)}
      @response_blocks.delete(key)
      @called_methods.delete(key)
    end
    
    def clear_cache
      @response_blocks  = Hash.new {|h, k| h[k] = []}
      @called_methods   = {}      
    end
    
    def merge_options(new_options)
      merged = options.merge(new_options)
      if options.has_key?(:params) && new_options.has_key?(:params)
        merged[:params] = options[:params].merge(new_options[:params])
      end
      merged
    end
    
    def interpolate_path_with_arguments(args)
      unless @interpolated_path
        @interpolated_path = @path
        argument_names.each_with_index do |arg, i|
          @interpolated_path.gsub!(":#{arg}", args[i])
        end
      end
      @interpolated_path
    end
    
    def argument_names_string
      args = argument_names
      if args.empty?
        ""
      else
        "#{args.join(', ')}, "
      end
    end
    
    def argument_names
      pattern, @keys = compile(@path) unless @keys
      @keys
    end
    
    # rippped from Sinatra. clean up stuff we don't need later
    def compile(path)
      path ||= ""
      keys = []
      if path.respond_to? :to_str
        special_chars = %w{. + ( )}
        pattern =
          path.gsub(/((:\w+)|[\*#{special_chars.join}])/) do |match|
            case match
            when "*"
              keys << 'splat'
              "(.*?)"
            when *special_chars
              Regexp.escape(match)
            else
              keys << $2[1..-1]
              "([^/?&#]+)"
            end
          end
        [/^#{pattern}$/, keys]
      elsif path.respond_to? :match
        [path, keys]
      else
        raise TypeError, path
      end
    end
  end
end