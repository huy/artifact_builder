gem 'mocha'
require 'mocha'

module TestHelper
    def stubs_file_exist(filename, atime)
        File.stubs(:exist?).with(filename).returns(true)
        File.stubs(:exists?).with(filename).returns(true)
        File.stubs(:atime).with(filename).returns(atime)
    end

    def stubs_file_not_exist(filename)
        File.stubs(:exist?).with(filename).returns(false)
        File.stubs(:exists?).with(filename).returns(false)
    end
end

