require 'test/unit'
require File.dirname(__FILE__) + '/test_helper'
require File.dirname(__FILE__) + '/../lib/oracle_schema_builder'

class TestUserObjects < Test::Unit::TestCase
    def test_no_filter
        builder = OracleSchemaBuilder.new

        builder.stubs(:dbms_java?).returns(true)

        builder.expects(:select_all).with() {|sql,ignore_error,verbose|
        sql.strip.gsub("\n",' ').squeeze(' ').eql? "select object_type, decode(object_type,'JAVA CLASS',dbms_java.longname(object_name),object_name) object_name from all_objects where 1=1"
        }.returns([{'OBJECT_NAME'=>'ABC'}])

        assert_equal ['abc'], builder.user_objects

    end

    def test_filter_by_object_type

        builder = OracleSchemaBuilder.new

        builder.stubs(:dbms_java?).returns(true)

        builder.expects(:select_all).with() {|sql,ignore_error,verbose|
            sql.strip.gsub("\n",' ').squeeze(' ').eql? "select object_type, decode(object_type,'JAVA CLASS',dbms_java.longname(object_name),object_name) object_name from all_objects where 1=1 and object_type='TABLE'"
        }.returns([{'OBJECT_NAME'=>'ABC'}])
        assert_equal ['abc'], builder.user_objects(:object_type=>'TABLE')


        builder.expects(:select_all).with() {|sql,ignore_error,verbose|
            sql.strip.gsub("\n",' ').squeeze(' ').eql? "select object_type, decode(object_type,'JAVA CLASS',dbms_java.longname(object_name),object_name) object_name from all_objects where 1=1 and object_type='VIEW'"
        }.returns([])
        assert_equal [], builder.user_objects(:object_type=>'VIEW')

    end

end