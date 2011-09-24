require 'test/unit'
require File.expand_path(File.dirname(__FILE__) + '/../lib/core_ext')

class TestCoreExt < Test::Unit::TestCase
    def test_string_wrap
        original = %q{ojdbc14.jar ls-domain.jar sq-io.jar sq-app.jar sq-tableaction.jar sq-util.jar sq-queue.jar sq-text.jar sq-reflection.jar sq-date.jar}

        expected = %q{ojdbc14.jar ls-domain.jar sq-io.jar sq-app.jar sq-tableaction.jar
sq-util.jar sq-queue.jar sq-text.jar sq-reflection.jar sq-date.jar}

        assert_equal expected, original.wrap(:width=>70)
    end
end