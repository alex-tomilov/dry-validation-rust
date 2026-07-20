# frozen_string_literal: true

module DryValidationRustBenchmark
  module Statistics
    module_function

    def median(values)
      raise ArgumentError, "cannot calculate a median without samples" if values.empty?

      sorted = values.sort
      middle = sorted.length / 2
      return sorted.fetch(middle) if sorted.length.odd?

      (sorted.fetch(middle - 1) + sorted.fetch(middle)) / 2.0
    end

    def spread(values)
      {
        "median" => median(values),
        "min" => values.min,
        "max" => values.max,
        "samples" => values
      }
    end
  end
end
