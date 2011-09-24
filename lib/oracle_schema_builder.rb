$LOAD_PATH.unshift File.expand_path(File.dirname(__FILE__)) unless $LOAD_PATH.first == File.expand_path(File.dirname(__FILE__))

require 'core_ext'
require 'oracle_dbi_connection'
require 'set'

class OracleSchemaBuilder
    include Shell

    attr_accessor :sql_command_dir,:username,:ignore_error,:verbose,:record_sql

    class << self
       def create params
           params.assert_valid_keys(:connect_string,:sql_command_dir)
           OracleSchemaBuilder.new(params[:connect_string],params[:sql_command_dir])
       end
    end
    
    def initialize(connect_string=nil,sql_command_dir=nil)
        @connection = OracleDbiConnection.new connect_string
        @sql_command_dir=sql_command_dir || '.'
        @ignore_error=false
        @verbose=false
        @error=Set.new
        @record_sql=true
    end

    def create_user(params)
        params.assert_valid_keys(:username,:password,:privs,:ignore_error, :force, :verbose)

        username = params[:username]
        password = params[:password] || params[:username]
        ignore_error = params[:ignore_error] || @ignore_error
        verbose = params[:verbose] || @verbose
        
        privs = params[:privs] ||[
          "DBA",
          "SELECT ON V_$DATAFILE", 
          "SELECT ON V_$SESSION", 
          "SELECT ON V_$MYSTAT",
          "SELECT ON DBA_JOBS", 
          "SELECT ON DBA_OBJECTS", 
          "EXECUTE ON DBMS_ALERT", 
          "EXECUTE ON DBMS_SESSION", 
          "EXECUTE ON DBMS_UTILITY", 
          "SELECT ON DBA_FREE_SPACE", 
          "SELECT ON DBA_DATA_FILES", 
          "UNLIMITED TABLESPACE WITH ADMIN OPTION"]

        if params[:force]
            drop_user(:username=>username, :ignore_error=>true, :verbose=>verbose)
        end

        sql = <<EOF
                 create user #{username} identified by #{password} default tablespace users temporary tablespace temp
EOF

        execute(sql.strip.chomp, :ignore_error=>ignore_error, :verbose=>verbose)

        grant_privs(:username=>username, :privs=>[privs].flatten)
  
    end

    def drop_user(params)
        params.assert_valid_keys(:username,:ignore_error,:verbose)

        username = params[:username]
        ignore_error = params[:ignore_error] || @ignore_error
        verbose = params[:verbose] || @verbose

        sql = <<EOF
                 drop user #{username} cascade
EOF
        execute(sql.strip.chomp, :ignore_error=>ignore_error, :verbose=>true)
    end

    def connect(params)
        params.assert_valid_keys([:username,:password,:verbose])

        username = params[:username]
        password = params[:password] || username
        verbose = params[:verbose] || @verbose

        if @connection
            puts "connect #{username}/#{password}@#{@connection.connect_string}"

            record_sql_commands unless @connection.sql_commands.empty?
            
            begin
                @connection.disconnect
            rescue
            end
        end

        @connection.connect(username,password)

    end

    def record_sql_commands
        sql_file = "#{@sql_command_dir}/#{@connection.username}_#{CommandRecorder.size}.sql"
        
        #puts "save sql commands to #{sql_file}"       
        
        mkdir_p @sql_command_dir       
        
        File.open(sql_file,'w') do |f|
            f.puts @connection.sql_commands.collect {|sql| "#{sql}\n/\n"}
            f.puts "exit\n"
        end

        CommandRecorder.record("sqlplus \"#{@connection.logon_string}\" @#{File.basename(sql_file)}")

        @connection.sql_commands=[]
    end

    def disconnect
        @connection.disconnect
        @connection=nil
    end

    def sys?
        @connection.sys?
    end

    def execute(sql, params={})
        params.assert_valid_keys(:verbose,:ignore_error,:nolog)

        ignore_error = if params[:ignore_error].nil? 
           @ignore_error
        else
           params[:ignore_error]
        end
        
        verbose = if params[:verbose].nil?
           @verbose
        else
           params[:verbose]
        end
        
        nolog = params[:nolog]
        
        raise "not yet connected to database".highlight(:error) unless @connection

        puts "execute \"#{sql.strip}\", ignore_error=#{ignore_error}" if verbose

        @connection.do(sql,ignore_error,verbose, nolog)

        if !sys? && !invalid_objects.empty?
            object_name = invalid_objects.first[:object_name]
            object_type = invalid_objects.first[:object_type]
            
            #require 'pp'
            #puts "---"
            #pp invalid_objects

            user_error_msg = user_error(:object_name=>object_name,
               :object_type=>object_type, :ignore_error=>ignore_error,:verbose=>verbose)
            
            msg = "invalid #{object_type} #{object_name}\n  #{user_error_msg}".highlight(:error)
            unless ignore_error
                raise msg
            else
                unless @error.include?(msg)
                    unless nolog
                        puts msg
                    end
                    @error << msg
                end
            end
        end

        puts "=>ok" if verbose
    end

    def invalid_objects
        user_objects :status=>"INVALID",:select=>[:object_name,:object_type]
    end

    def drop_objects params
        params.assert_valid_keys(:object_name,:object_type,:owner,:ignore_error,:verbose,:nolog)

        object_type = params[:object_type]
        owner = params[:owner] || @connection.username
        
        ignore_error = if params[:ignore_error].nil? 
           @ignore_error
        else
           params[:ignore_error]
        end
        
        verbose = if params[:verbose].nil?
           @verbose
        else
           params[:verbose]
        end
        
        nolog = params[:nolog]

        drop_object_options = {'TYPE'=>'force'}

        [object_type].flatten.each do |obj_type|
            objects(:object_type=>obj_type, :owner=>owner,:object_name=>params[:object_name],
            :select=>[:object_name,:object_type]).each do |info|
                if java?(info[:object_type])
                    class_name = info[:object_name].gsub('/','.')
                    cmd = "begin\n dbms_java.dropjava('-user #{owner.upcase} #{class_name}');\nend;"
                else
                    cmd = "drop #{info[:object_type]} #{owner.upcase}.#{info[:object_name]} #{drop_object_options[info[:object_type].upcase]}"
                end

                execute(cmd , :ignore_error=>ignore_error, :verbose=>verbose,:nolog=>nolog)
            end
        end
    end

    def exists?(params={})
        !objects(params).empty?
    end

    def user_objects(params={})
        params[:owner]=@connection.username
        objects(params)
    end

    def objects(params={})
        params.assert_valid_keys([:object_type,:status,:owner,:object_name,:select,:ignore_error, :verbose])

        ignore_error = params[:ignore_error] || @ignore_error
        verbose = params[:verbose] || @verbose

        sql =<<-EOF
              select
                    object_type,
                    object_name
              from
                all_objects
              where
                1=1
        EOF

        if dbms_java?
            sql = <<-EOF
              select
                    object_type,
                    decode(object_type,'JAVA CLASS',dbms_java.longname(object_name),object_name) object_name
              from
                all_objects
              where
                1=1
             EOF
        end

        object_name = params[:object_name]
        object_type = params[:object_type]
        status = params[:status]
        owner = params[:owner]

        sql = "#{sql} and object_name=\'#{object_name}\'" unless object_name.nil?

        sql = "#{sql} and owner=\'#{owner.upcase}\'" unless owner.nil?
        sql = "#{sql} and status=\'#{status.upcase}\'" unless status.nil?

        result = []
        
        [object_type].flatten.each do |obj_type|
            one_sql = if obj_type
                "#{sql} and object_type=\'#{obj_type.upcase}\'"
            else
                sql
            end
            #puts "--- #{one_sql}"
            select_all(one_sql,ignore_error,verbose).each do |row|
                
                if params[:select].nil?
                   result << row['OBJECT_NAME'].downcase unless in_recycle?(row['OBJECT_NAME'])
                else      
                   #require 'pp'
                   #puts "--- params[:select]"
                   #pp params[:select]
                   
                   one = {}
                   [params[:select]].flatten.each do |attr|
                       one[attr] = row[attr.to_s.upcase].downcase                    
                   end
                                      
                   #puts "------ one="
                   #pp one
                   
                   result << one unless in_recycle?(row['OBJECT_NAME'])
                end
            end
        end

        result.compact
    end

    def dbms_java?
        return @dbms_java_available if @dbms_java_available

        sql = <<-EOF
              select
                    object_type,
                    object_name,
                    owner
              from
                all_objects
              where
                object_name='DBMS_JAVA'
              and
                object_type = 'PACKAGE'
        EOF
        row = select_one(sql,false,false)

        @dbms_java_available = !row.nil?

        return @dbms_java_available
    end

    def in_recycle? name
        name && name[0,1] == '/'
    end

    def java? type
        type == 'JAVA CLASS'
    end

    def user_error(params)
        
        params.assert_valid_keys(:object_name,:object_type,:source_lines,:ignore_error,:verbose)
        
        object_name = params[:object_name]
        object_type = params[:object_type]
        ignore_error = params[:ignore_error]
        verbose = params[:verbose]
        source_lines = params[:source_lines] || 20
        
        user_error_sql = <<-EOF
              select
                line,
                text
              from
                user_errors
              where
                name='#{object_name.upcase}' 
              and
                type='#{object_type.upcase}'
              order by line
        EOF

        user_error_row=select_one(user_error_sql,ignore_error,verbose)

        unless user_error_row.nil?
            line = user_error_row['LINE'].to_i

            user_source_sql = <<-EOF
              select
                line,
                text
              from
                user_source
              where
                name='#{object_name.upcase}'
              and
                type='#{object_type.upcase}'
              and
                line>=#{line}
              and
                line<=#{line} + #{source_lines}
              
EOF

            user_source_text = select_all(user_source_sql,ignore_error,verbose).
              collect {|row| row['TEXT']}.join("\n")
              
            user_source_text = user_source_text[/^[^;]+;/] || user_source_text
            
            result = "line=#{line},error=#{user_error_row['TEXT']},source=\n#{user_source_text}"
        end

        result
    end

    def select_all(sql,ignore_error,verbose)
        raise "not yet connected to database".highlight(:error) unless @connection
        @connection.select_all(sql,ignore_error, verbose)
    end

    def select_one(sql,ignore_error, verbose)
        raise "not yet connected to database".highlight(:error) unless @connection
        @connection.select_one(sql,ignore_error, verbose)
    end

    def run params={:record_sql=>false}, &block
        params.assert_valid_keys(:record_sql)

        instance_eval &block if block_given?
        
        record_sql_commands if @record_sql || params[:record_sql]
    end

    def grant_privs (params)
        params.assert_valid_keys(:username,:privs,:ignore_error,:verbose)

        username = params[:username]
        privs = params[:privs]
        ignore_error = params[:ignore_error] || @ignore_error
        verbose = params[:verbose] || @verbose

        [privs].flatten.collect {|priv| "grant #{priv.sub(/ with admin option/i,'')} to #{username} #{priv[/ with admin option/i]}"}.
        each do |statement|
            execute(statement, :ignore_error=>ignore_error, :verbose=>verbose)
        end
    end

    def parse_sql_script(filename, spliter=/^\/$/)
        entire = ""
        File.open(filename) do |f|
            f.binmode
            entire = f.readlines().collect{|line| "#{line}".strip.chomp}.join("\n")
        end

        result = []
        entire.split(spliter).each do |one|
            one = exclude_comment_outside_code(one)
            one.strip!
            result << one unless one.empty?
        end
        result
    end

    def exclude_comment_outside_code(statement)
        result = ""
        is_within_code=false
        statement.split("\n").each do |line|
            line.strip!
            if is_within_code
                result += line + "\n"
            else
                if !line.empty? && !is_comment(line)
                    is_within_code = true
                    result += line + "\n"
                end
            end
        end
        result.strip!
        result
    end

    def is_comment(line, comments = ['--','PROMPT','REM'])
        [comments].flatten.any? { |comment|
            Regexp.new(comment, Regexp::IGNORECASE).match(line)
        }
    end

    def execute_sql_script(params)
        params.assert_valid_keys(:filename,:ignore_error, :verbose)

        filename = params[:filename]
        ignore_error= params[:ignore_error] || @ignore_error
        verbose = params[:verbose] || @verbose

        [filename].flatten.each do |file|
            ignore_flag = ",ignore_error=#{ignore_error}" if ignore_error
            puts "execute #{file}#{ignore_flag}"
            parse_sql_script(file).each do |sql|
                execute(sql, :ignore_error=>ignore_error, :verbose=>verbose)
            end
        end
    end

    def execute_dir(params)
        params.assert_valid_keys(:dir,:extname,:exclude,:order,:ignore_error, :verbose)

        dir = params[:dir]
        extname = params[:extname] || ''
        ignore_error = params[:ignore_error] || @ignore_error
        verbose = params[:verbose] || @verbose

        order = params[:order] || []
        exclude =[params[:exclude]].flatten.compact + order

        execute_sql_script(:filename=>order.compact.collect {|name| "#{dir}/#{name}"},
        :ignore_error=>ignore_error,
        :verbose=>verbose)

        Dir["#{dir}/*#{extname}"].sort.each do |filename|
            execute_sql_script(:filename=>filename,
            :ignore_error=>ignore_error,
            :verbose=>verbose) unless [exclude].flatten.member?(File.basename(filename))
        end
    end

    def load_java(params)
        params.assert_valid_keys(:userid,:jar, :verbose)

        userid= params[:userid]
        jar = params[:jar]
        verbose = params[:verbose] || @verbose

        [jar].flatten.each do |file|
            cmd = "loadjava -user #{userid} -resolve #{file} -verbose"

            puts cmd if verbose

            system cmd
        end
    end

    def exp(params)
        params.assert_valid_keys(:userid, :owner, :file, :dest_dir,:log, :verbose)

        userid= params[:userid] || "system/manager@#{connect_string}"
        dest_dir = params[:dest_dir]

        owner = [params[:owner]].flatten

        file = params[:file] || owner.first + '.dmp'

        log = params[:log] || File.basename(file,'.*')

        log = if log =~ /exp/i
            log + '.log'
        else
            log + '-exp.log'
        end

        verbose = params[:verbose] || @verbose

        file = dest_dir + FILE_SEPARATOR + file if dest_dir

        if dest_dir
            log =  dest_dir + FILE_SEPARATOR + log
        else
            if File.dirname(file) != '.'
                log =  File.dirname(file) + FILE_SEPARATOR + log
            end
        end

        cmd = "exp userid=#{userid} owner=(#{owner.join(',')}) file=#{file} log=#{log}"

        puts cmd if verbose

        system cmd
    end
    
    def create_access_path(params)
       params.assert_valid_keys(:from_user, :to_user, :from_password, :to_password,:objects, :public_synonym, 
          :name_mapping, :privilege, :ignore_error, :verbose, :nolog)

       from_user = params[:from_user].strip.downcase
       from_password = params[:from_password] || from_user
       
       to_user = params[:to_user].strip.downcase
       to_password = params[:to_password] || to_user
       
       objects = params[:objects].to_a
      
       public_synonym = params[:public_synonym]
       
       name_mapping = params[:name_mapping] || lambda {|name| name}
       
       privilege = params[:privilege] || 'select'
       
       ignore_error = if params[:ignore_error].nil? 
          @ignore_error
       else
          params[:ignore_error]
       end
       
       verbose = if params[:verbose].nil? 
          @verbose
       else
          params[:verbose]
       end
       
       nolog = params[:nolog]
       
       connect :username=>from_user,:password=>from_password
       
       unless to_user == from_user
         grant_privs :username=>to_user,
           :privs=>objects.collect {|name| "#{privilege} on #{name}"},
           :ignore_error=>ignore_error,:verbose=>verbose
       end    
         
       connect :username=>to_user,:password=>to_password
       
       objects.each do |name|             
            
            public_opt = if public_synonym
             'public'
            else
              nil
            end
            
            execute "drop #{public_opt} synonym #{name_mapping.call(name)}",
              :verbose=>verbose, :ignore_error=>true,:nolog=>true
            
            if to_user != from_user or name_mapping.call(name) != name or public_opt
               execute "create #{public_opt} synonym #{name_mapping.call(name)} for #{from_user}.#{name}",
               :verbose=>verbose, :ignore_error=>ignore_error,:nolog=>nolog
            end   
       end
    end
    
    def connect_string
      @connection.connect_string if @connection
    end
    
end