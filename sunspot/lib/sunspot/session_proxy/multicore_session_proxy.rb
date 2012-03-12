module Sunspot
  module SessionProxy
    class MulticoreSessionProxy < AbstractSessionProxy

      def initialize( cores )
        @sessions = {}
        @cores ||= []
        ( @cores << cores ).flatten!
        cores.each do |core|

          # can't find a better way grab the sunspot.yml configuration (:user_configuration is a private method)
          modified_config = Marshal.load( Marshal.dump( Sunspot::Rails.configuration.send(:user_configuration) ) )

          modified_config["solr"]["path"] = File.join(
            ( modified_config["solr"]["path"] || Sunspot::Rails.configuration.path ), core )
            
          extended_config = Sunspot::Rails::ExtendedConfiguration.new(modified_config)
          session = @sessions[core] = Sunspot::Rails.build_session(extended_config)
        end
      end

      attr_accessor :selected_session
        
      def method_missing(method, *args, &block)
        inspectable_args = args.flatten
        types = inspectable_args.select(&:searchable?) rescue []
        types += inspectable_args.select{|a| a.class.searchable? rescue false }
        
        self.selected_session = session_for_types(types) || self.selected_session
        
        if self.selected_session.respond_to?(method)
          begin
            self.selected_session.send(method, *args, &block) 
          rescue Exception => e
            (puts "method #{method} caused: #{e.message}")
          end
        else
          # raise NoMethodError, "Method #{method} isn't defined on session"
          # logger.info("do nothing")
          # super
          # self.selected_session.send(method, *args, &block)
          return false
        end
      end
      
      protected
        def infer_configuration_options_from_env_url( options )
          if ENV["SOLR_URL"]
            
          end
        end
        
        def session_for_types(*types)
          cores = types.flatten.map{|t| t.sunspot_options[:core] }.uniq
          raise ArgumentError, "Can't mix and match types that use different solr cores" if cores.length > 1

          @sessions[cores.first]
        end
        
        def session_for_objects(*objects)
          types = objects.map(&:class).uniq
          session_for_types(types)
        end

    end
  end
end