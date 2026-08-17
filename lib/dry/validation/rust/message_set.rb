# frozen_string_literal: true

module Dry
  module Validation
    module Rust
      # A collection of validation messages with filtering and rendering views.
      #
      # Message sets preserve individual {Message} objects until a caller asks
      # for a nested error hash with {#to_h}. Use {#with} with `full: true` to
      # render field names into message text.
      #
      # @example Read nested errors from a contract result
      #   result.errors.to_h # => { name: ["is missing"] }
      class MessageSet
        include Enumerable

        # @return [Hash] rendering options applied to this message set.
        attr_reader :options

        # Creates a message set from messages and optional rendering options.
        #
        # @param messages [Array<Message>] messages to include
        # @param options [Hash] rendering options, such as `full: true`
        # @return [MessageSet]
        def initialize(messages = [], options = {})
          @messages = messages.dup
          @options = options
        end

        # Iterates over messages.
        #
        # @yield [message] each message in the set
        # @yieldparam message [Message]
        # @return [Enumerator, MessageSet] an enumerator without a block, or this set with one
        # @example Print each message text
        #   result.errors.each { |message| puts message.text }
        def each(&)
          @messages.each(&)
        end

        # Returns an immutable snapshot of the messages.
        #
        # @return [Array<Message>] frozen message-object view
        def messages
          readonly_messages
        end

        # Returns messages at or below a key or path.
        #
        # @param key [Symbol, String, Array, Hash] key or supported path specification
        # @return [MessageSet] messages whose paths start with `key`
        # @example Select nested address messages
        #   result.errors[:address].to_h # => { city: ["is missing"] }
        def [](key)
          wanted = Path.parse(key)
          self.class.new(@messages.select { |message| Path.prefix?(message.path, wanted) }, options)
        end

        # Adds a message and invalidates derived views.
        #
        # @param message [Message] message to append
        # @return [MessageSet] this set
        def add(message)
          @messages << message
          @readonly_messages = nil
          @to_h = nil
          self
        end

        # Returns whether this set contains no messages.
        #
        # @return [Boolean]
        def empty?
          @messages.empty?
        end

        # Returns messages satisfying every supplied message predicate.
        #
        # Each predicate must be a public predicate method on a message and
        # return a truthy value. A message without a requested predicate is
        # excluded.
        #
        # @param predicates [Array<Symbol, String>] message predicate names
        # @return [MessageSet] matching messages
        # @example Select base-level messages
        #   result.errors.filter(:base?)
        def filter(*predicates)
          self.class.new(
            @messages.select do |message|
              predicates.all? { |predicate| message.respond_to?(predicate) && message.public_send(predicate) }
            end,
            options
          )
        end

        # Returns a copy with rendering options, including full-message text.
        #
        # With `full: true`, non-base message text is prefixed with its
        # humanized path (for example, `:first_name` becomes `"first name"`).
        #
        # @param new_options [Hash] rendering options to merge into {#options}
        # @return [MessageSet] a new set using the merged options
        # @example Render full messages
        #   result.errors.with(full: true).messages.map(&:text)
        #   # => ["name is missing"]
        def with(new_options = {})
          merged = options.merge(new_options)
          return self.class.new(@messages, merged) unless merged[:full]

          self.class.new(@messages.map { |message| full_message(message) }, merged)
        end

        # Returns messages grouped into a nested Hash by path.
        #
        # @return [Hash] nested error messages keyed by their paths
        # @example Read errors as a hash
        #   result.errors.to_h # => { address: { city: ["is missing"] } }
        def to_h
          @to_h ||= build_nested_hash
        end

        # Freezes this set and its cached derived Hash.
        #
        # @return [MessageSet] this frozen set
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
