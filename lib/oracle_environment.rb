if PLATFORM =~ /mswin/

require 'win32/registry'

class OracleEnvironment
    ORACLE_ROOT_KEY = "SOFTWARE\\ORACLE"
    class << self
        def home_key home_path
            path_in_win32 = home_path.gsub("/","\\")

            Win32::Registry::HKEY_LOCAL_MACHINE.open(ORACLE_ROOT_KEY) do |oracle_root|

                oracle_root.each_value do |name,type,data|
                    return ORACLE_ROOT_KEY if name==='ORACLE_HOME' && oracle_root[name].casecmp(path_in_win32)==0
                end

                oracle_root.each_key do |key,time|
                    #puts key
                    oracle_root.open(key) do |home|
                        home.each_value do |name,type,data|
                            #puts "\t#{name}"
                            return "#{ORACLE_ROOT_KEY}\\#{key}" if name==='ORACLE_HOME' && home[name].casecmp(path_in_win32)==0
                        end
                    end
                end
            end
            nil
        end

        def get(key, name)
            Win32::Registry::HKEY_LOCAL_MACHINE.open(key) do |reg|
                reg.each_value do |n,t,d|
                    return d if n===name
                end
            end
            nil
        end

        def add_path(key, name, path)
            path_in_win32 = path.gsub("/", "\\")

            Win32::Registry::HKEY_LOCAL_MACHINE.open(key, Win32::Registry::KEY_WRITE) do |reg|
                existing = get(key, name)
                if existing
                    #puts "existing=#{existing},path=#{path_in_win32}"
                    #puts existing =~ /#{Regexp.escape(path_in_win32)}/i
                    reg[name] = "#{path_in_win32};#{existing.gsub(/^;/,'')}" unless existing =~ /#{Regexp.escape(path_in_win32)}/i
                else
                    reg[name] = "#{path_in_win32}"
                end
                reg.flush
            end
        end

        def replace_cc_build_path(key, name, path)
            path_in_win32 = path.gsub("/", "\\")

            Win32::Registry::HKEY_LOCAL_MACHINE.open(key, Win32::Registry::KEY_WRITE) do |reg|
                project_path = path_in_win32.split("\\build-")[0]

                existing = remove_last_build_paths(get(key, name), project_path)

                if !existing.empty?
                    reg[name] = "#{path_in_win32};#{existing.gsub(/^;/,'')}" unless existing =~ /#{Regexp.escape(path_in_win32)}/i
                else
                    reg[name] = "#{path_in_win32}"
                end
                reg.flush
            end
        end

        def remove_last_build_paths(paths, project_path)
            paths.split(";").reject{ |p|
                p =~ /#{Regexp.escape(project_path)}/i 
            }.join(';')
        end

    end
end

end
