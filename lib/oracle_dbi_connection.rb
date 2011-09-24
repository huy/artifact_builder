$LOAD_PATH.unshift File.expand_path(File.dirname(__FILE__)) unless $LOAD_PATH.first == File.expand_path(File.dirname(__FILE__))

require 'dbi'
require 'core_ext'

class OracleDbiConnection
    attr_accessor :sql_commands,:username,:password,:connect_string

    def initialize connect_string
        @connect_string = connect_string.strip if connect_string
        @sql_commands = []
    end

    def connect username, password
        @username=username
        @password=password
        if sys?
            @dbi_connection = DBI.connect("DBI:OCI8:#{@connect_string}", @username, @password, {'Privilege' => :SYSDBA})
        else
            @dbi_connection = DBI.connect("DBI:OCI8:#{@connect_string}", @username, @password)
        end
    end

    def logon_string
       if sys?
          "#{@username}/#{@password}@#{@connect_string} as sysdba"
       else
           "#{@username}/#{@password}@#{@connect_string}"
       end
    end

    def sys?
        @username.upcase.eql?('SYS')
    end

    def disconnect
        @dbi_connection.disconnect
        @dbi_connection=nil
    end

    def do(sql, ignore_error, verbose,nolog=false)
        @dbi_connection.do(sql)
        @sql_commands << sql
    rescue DBI::DatabaseError => error
        handle_error(sql,error,verbose,ignore_error,nolog)
    end

    def select_all(sql, ignore_error=false, verbose=false)
        @dbi_connection.select_all(sql)
    rescue DBI::DatabaseError => error
        handle_error(sql,error,verbose,ignore_error)
    end

    def select_one(sql, ignore_error=false, verbose=false)
        @dbi_connection.select_one(sql)
    rescue DBI::DatabaseError => error
        handle_error(sql,error,verbose,ignore_error)
    end

    def handle_error(sql,error,verbose,ignore_error,nolog=false)
        puts "execute \"#{sql.strip}\"" if verbose
        puts "=>failed:#{error}".highlight(:error) unless nolog
        raise error unless ignore_error
    end
    
    private :handle_error
end