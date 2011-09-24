require File.dirname(__FILE__) + '/java_class_info'

class JavaFileTimestampChecker

    def initialize(params={})
        @class_timestamp = {}
        @jar_command = params[:jar_command] || 'jar'
        @verbose = params[:verbose] || false
    end

    def get_out_of_date_java_files(src_dir, dest_dir, dependencies)
        java_files = []
        Dir["#{src_dir}/**/*.java"].each do |java_file|
            class_file = dest_dir + java_file[src_dir.length,
            java_file.length - src_dir.length - '.java'.length] + '.class'

            unless File.exist?(class_file) && File.atime(class_file) >= File.atime(java_file)
                java_files << java_file
            else
                puts "-- check dependers of #{File.basename(java_file)}" if @verbose
                references = JavaClassInfo.read(class_file).class_names_ref

                references.delete_if {|name| java_core_lib?(name) }

                within_module_references = references.select {|class_name|
                    File.exist?("#{dest_dir}/#{class_name}.class")}

                out_of_module_references = references - within_module_references

                java_files << java_file if within_module_references.any? { |class_name|
                    ref_java_class_out_of_date?(src_dir,dest_dir,class_name)
                }

                unless java_files.include?(java_file) || out_of_module_references.empty?
                    java_files << java_file if out_of_module_references.any? { |ref_class_name|
                        ref_class_atime = get_out_of_module_ref_class_atime(ref_class_name, dependencies)
                        ref_class_atime.nil? || ref_class_atime > File.atime(class_file)
                    }
                end
            end
        end
        return java_files
    end

    def get_out_of_module_ref_class_atime(ref_class_name, dependencies)
        puts "#{ref_class_name}.atime = #{@class_timestamp[ref_class_name]}" if @verbose

        return @class_timestamp[ref_class_name] if  @class_timestamp[ref_class_name]

        puts "ref_class_name=#{ref_class_name}" if @verbose

        jars = dependencies.select{|name| name =~ /^.+\.jar$/}
        non_jars = dependencies - jars

        puts "-- scanning #{non_jars.join(',')}" if @verbose

        non_jars.each do |path|
            Dir["#{path}/**/*.class"].collect {|class_file|
                class_name = class_file[path.length+1,class_file.length-path.length-'.class'.length-1]
                @class_timestamp[class_name]=File.atime(class_file)
            }
        end

        puts "#{ref_class_name}.atime = #{@class_timestamp[ref_class_name]}" if @verbose

        return @class_timestamp[ref_class_name] if  @class_timestamp[ref_class_name]

        puts "-- scanning #{jars.join(',')}" if @verbose

        jars.each do |jar|
            @class_timestamp.merge!(extract_jar(jar))
        end

        puts "#{ref_class_name}.atime = #{@class_timestamp[ref_class_name]}" if @verbose

        return @class_timestamp[ref_class_name]
    end

    def extract_jar jar_file
        result={}
        jar_file_atime = File.atime(jar_file)
        command = "|#{@jar_command} tf #{jar_file}"
        open(command) do |f|
            f.each { |line|
                if line =~ /^.+\.class/
                    class_name = line[0,line.length-'.class'.length-1]
                    result[class_name] = jar_file_atime 
                end
            }
        end
        result
    end

    def java_core_lib? class_name
        class_name =~ /^java\// || class_name =~/^\[[BCIJL]/ || class_name =~/^\[\[[BCIJL]/ ||
        class_name =~ /^javax\/swing/ || class_name =~ /^javax\/sound/ || class_name =~ /^javax\/naming/
    end

    def ref_java_class_out_of_date? src_dir,dest_dir,class_name
        class_file = "#{dest_dir}/#{class_name}.class"
        java_file = "#{src_dir}/#{class_name}.java"

        if File.exist?(java_file) && @verbose
            puts "\tFile.atime(#{java_file})=#{File.atime(java_file).strftime('%H:%M:%S')}"
        end
        if File.exist?(class_file) && @verbose
            puts "\tFile.atime(#{class_file})=#{File.atime(class_file).strftime('%H:%M:%S')}"
        end

        !File.exist?(java_file) || File.atime(java_file) > File.atime(class_file)
    end

end
