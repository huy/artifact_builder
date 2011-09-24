unless defined?(CoreExt)
    CoreExt = true

    class Hash
        def assert_valid_keys(*valid_keys)
            unknown_keys = keys - [valid_keys].flatten
            raise(ArgumentError,
            "<error>Unknown key(s): #{unknown_keys.join(", ")}\nValid key(s): #{valid_keys.join(',')}</error>") unless unknown_keys.empty?
        end
    end

    class String
        def to_task(task_type=nil)
            if task_type
                "#{task_type.to_s}_#{self.gsub(/-|\./,'_')}".to_sym
            else
                "#{self.gsub(/-|\./,'_')}".to_sym
            end
        end
    end

    class String
        def little_endian
            reverse.big_endian
        end

        def big_endian
            result=0
            each_byte { |c| result=result*256 + c}
            result
        end

        # borow from Ruby Cookbook
        def wrap(param={})
            param.assert_valid_keys(:width,:wrapper)

            width = param[:width] || 78
            wrapper = param[:wrapper] || "\n"

            lines = []
            line = ""
            self.split(/\s+/).each do |word|
                if line.size + word.size >= width
                    lines << line
                    line = word
                elsif line.empty?
                    line = word
                else
                    line << " " << word
                end
            end
            lines << line if line
            return lines.join(wrapper)
        end

        def highlight(type=:error)
            if ENV['CC_BUILD_ARTIFACTS'] 
              "<span class=\"error\">#{self}</span>" 
            else
              self
            end     
        end


    end

    def File.read filename
        size = File.size(filename)
        File.open(filename) do |file|
            file.binmode
            return file.read(size)
        end
    end

    module Shell
        def win32?
            RUBY_PLATFORM =~ /win32/i
        end

        def unix?
            !win32?
        end

        def system(cmd,opts={})
            os_command = cmd

            ignore_exitstatus = opts[:ignore_exitstatus]

            if unix?
                os_command = cmd.gsub("$","\\$")
            end

            CommandRecorder.record(os_command)

            Kernel.system os_command

            raise "'#{cmd}'\ncommand not found".highlight(:error) unless $?

            unless ignore_exitstatus
                raise "'#{cmd}'\nfailed".highlight(:error) unless $?.exitstatus==0
            end
        end

        module_function :win32?,:unix?

        CLASSPATH_SEPARATOR = win32? ? ";" : ":"
        FILE_SEPARATOR = win32? ? "\\" : "/"
    end

    require 'rubygems'
    require 'rake'

    class Rake::Task
        alias original_execute execute

        def extern_commands
            @extern_commands||=[]
        end

        def execute
            CommandRecorder.current_task = self
            original_execute
        end

        def record_extern_commands(params={})
            params.assert_valid_keys(:filename,:append)
            
            filename = params[:filename] || name
            
            mkdir_p File.dirname(filename)
            
            filemode = if params[:append]
               'a'
            else
               'w'
            end
            
            File.open(filename,filemode) do |f|
               if File.extname(filename) =~ /\.sh/i
                  f.puts "\n\# #{name}"         
               else
                  f.puts "\nrem #{name}"
               end
               f.puts extern_commands
            end   
        end
    end

    ENV.instance_eval do
        alias original_setter []=
        def []=(name,value)
            os_command = if Shell.win32?
               "set #{name}=#{value}"
            else
                "export #{name}=#{value}"
            end

            CommandRecorder.record(os_command)

            original_setter(name,value)
        end
    end

    class CommandRecorder
        class << self
            attr_accessor :current_task

            def recorded_tasks
                @recorded_tasks ||= []
            end

            def record command
                if @current_task
                    recorded_tasks << @current_task unless recorded_tasks.include?(@current_task)
                    @current_task.extern_commands << command
                end
            end

            def size
                recorded_tasks.compact.inject(0){|memo,task| memo+task.extern_commands.size}
            end

        end
    end
end
