# frozen_string_literal: true

# The experimental replacement ships only the minimal schema factories needed
# by its contract DSL. Loading this entrypoint also loads exact compatibility
# mode; it is not the full upstream dry-schema gem.
require 'dry/validation'
