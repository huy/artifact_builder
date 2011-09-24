require 'test/unit'

require File.dirname(__FILE__) + '/test_helper'
require File.dirname(__FILE__) + '/../lib/java_builder'

class TestJdkHome < Test::Unit::TestCase
    def test_jdk_home_win32
        builder = JavaBuilder.new '.',"d:/j2sdk1.4.2_12"

        builder.stubs(:win32?).returns(true)

        assert_equal "d:\\j2sdk1.4.2_12\\bin\\java", builder.jdk_command(:java)
        assert_equal "d:\\j2sdk1.4.2_12\\bin\\jar", builder.jdk_command(:jar)
        assert_equal "d:\\j2sdk1.4.2_12\\bin\\javac", builder.jdk_command(:javac)
    end

    def test_jdk_home_unix
        builder = JavaBuilder.new '.',"/usr/java/j2sdk1.4.2_12"

        builder.stubs(:win32?).returns(false)

        assert_equal "/usr/java/j2sdk1.4.2_12/bin/java", builder.jdk_command(:java)
        assert_equal "/usr/java/j2sdk1.4.2_12/bin/jar", builder.jdk_command(:jar)
        assert_equal "/usr/java/j2sdk1.4.2_12/bin/javac", builder.jdk_command(:javac)
    end

    def test_no_jdk_home
        builder = JavaBuilder.new '.'
        assert_equal "java", builder.jdk_command(:java)
        assert_equal "jar", builder.jdk_command(:jar)
        assert_equal "javac", builder.jdk_command(:javac)
    end
end
