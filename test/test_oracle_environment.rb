require 'test/unit'
require File.dirname(__FILE__) + '/../lib/oracle_environment'

if PLATFORM =~ /mswin/

class TestOracleEnvironment < Test::Unit::TestCase

    def setup
        @oe = OracleEnvironment
    end

    def test_home_key
        assert_equal "SOFTWARE\\ORACLE\\HOME1",@oe.home_key("D:\\oracle\\orant")
        assert_equal "SOFTWARE\\ORACLE\\HOME1",@oe.home_key("d:/oracle/orant")
    end

    def test_get
        assert_nil @oe.get("SOFTWARE\\ORACLE\\HOME1", 'MY_PATH')
        assert_not_nil @oe.get("SOFTWARE\\ORACLE\\HOME1", "FORMS60_PATH")
    end


    def test_add_path
        @oe.add_path "SOFTWARE\\ORACLE\\HOME1", "FORMS60_PATH", "C:\\TEMP"
        assert_match /C:\\TEMP/i, @oe.get("SOFTWARE\\ORACLE\\HOME1", "FORMS60_PATH")
    end

end

end
