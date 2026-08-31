# src/vt/version.cr
module VT
  VERSION = {{ `shards version "#{__DIR__}"`.chomp.stringify }}
end

require "./types"
require "./utf8"
require "./scanner"
require "./handler"
require "./table"
require "./parser"
require "./dsl"
