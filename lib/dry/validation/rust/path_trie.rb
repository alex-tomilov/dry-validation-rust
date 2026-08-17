# frozen_string_literal: true

module Dry
  module Validation
    module Rust
      class PathTrie
        def initialize
          @root = {}
          @terminal = Object.new
        end

        def add(path)
          node = @root
          path.each { |part| node = node[part] ||= {} }
          node[@terminal] = true
        end

        def prefix?(path)
          return false if path.empty?

          node = @root
          path.each do |part|
            return true if node.key?(@terminal)

            node = node[part]
            return false unless node
          end
          true
        end
      end
    end
  end
end
