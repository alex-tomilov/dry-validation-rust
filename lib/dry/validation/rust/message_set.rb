# frozen_string_literal: true

module Dry
  module Validation
    module Rust
      class MessageSet
        include Enumerable

        # @return [Hash] rendering options applied to this message set.
        attr_reader :options

        # Creates a message set from messages and optional rendering options.
        def initialize(messages = [], options = {})
          @messages = messages.dup
          @options = options
        end

        # Iterates over messages.
        def each(&)
          @messages.each(&)
        end

        # Returns an immutable snapshot of the messages.
        def messages
          readonly_messages
        end

        # Returns messages at or below a key or path.
        def [](key)
          wanted = Path.parse(key)
          self.class.new(@messages.select { |message| Path.prefix?(message.path, wanted) }, options)
        end

        # Adds a message and invalidates derived views.
        def add(message)
          @messages << message
          @readonly_messages = nil
          @to_h = nil
          self
        end

        # Returns true when this set contains no messages.
        def empty?
          @messages.empty?
        end

        # Returns messages satisfying every supplied message predicate.
        def filter(*predicates)
          self.class.new(
            @messages.select do |message|
              predicates.all? { |predicate| message.respond_to?(predicate) && message.public_send(predicate) }
            end,
            options
          )
        end

        # Returns a copy with rendering options, including full-message text.
        def with(new_options = {})
          merged = options.merge(new_options)
          return self.class.new(@messages, merged) unless merged[:full]

          self.class.new(@messages.map { |message| full_message(message) }, merged)
        end

        # Returns messages grouped into a nested Hash by path.
        def to_h
          @to_h ||= build_nested_hash
        end

        # Freezes this set and its cached derived Hash.
        def freeze
          @messages.freeze
          # Keep the derived representation so callers of a frozen set reuse it.
          to_h.freeze
          super
        end

        private

        def readonly_messages
          @readonly_messages ||= @messages.dup.freeze
        end

        def build_nested_hash
          @messages.each_with_object({}) do |message, result|
            insert(result, message.path.empty? ? [nil] : message.path, message.payload)
          end
        end

        def insert(root, path, payload)
          leaf = path.last
          parent = path[0...-1].reduce(root) { |node, part| node[part] ||= {} }
          (parent[leaf] ||= []) << payload
        end

        def full_message(message)
          return message if message.base?

          label = message.path.map { |part| part.is_a?(Integer) ? part : part.to_s.tr('_', ' ') }.join(' ')
          message.with(text: "#{label} #{message.text}")
        end
      end
    end
  end
end
