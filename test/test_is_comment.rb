require 'test/unit'
require File.dirname(__FILE__) + '/../lib/oracle_schema_builder'

class TestIsComment < Test::Unit::TestCase
    def test_is_comment
        builder = OracleSchemaBuilder.new
        assert builder.is_comment('--')
        assert builder.is_comment('-- hello world')
        assert builder.is_comment('rem')
        assert builder.is_comment('prompt')
        assert builder.is_comment('PROMPT')
        assert !builder.is_comment('create table')
    end
end