# frozen_string_literal: true

module Dry
  module Validation
    module Rust
      class PathTrie
        TERMINAL = Object.new.freeze
        private_constant :TERMINAL

        def initialize
          @root = {}
        end

        def add(path)
          node = @root
          path.each { |part| node = node[part] ||= {} }
          node[TERMINAL] = true
        end

        def prefix?(path)
          return false if path.empty?

          node = @root
          path.each do |part|
            return true if node.key?(TERMINAL)

            node = node[part]
            return false unless node
          end
          true
        end

        def freeze
          stack = [[@root, false]]
          until stack.empty?
            node, visited = stack.pop
            if visited
              node.freeze
              next
            end

            stack << [node, true]
            node.each_value do |child|
              stack << [child, false] if child.is_a?(Hash)
            end
          end
          super
        end

        def ==(other)
          other.is_a?(self.class) && @root == other.instance_variable_get(:@root)
        end

        alias eql? ==

        def hash
          @root.hash
        end
      end
    end
  end
end
