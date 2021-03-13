# config/.credo.exs
%{
  configs: [
    %{
      name: "default",
      checks: [
        {Credo.Check.Readability.ParenthesesOnZeroArityDefs, parens: true},
        # UTC offset heuristic is complicated
        {Credo.Check.Refactor.CyclomaticComplexity,max_complexity: 13}
      ]
    }
  ]
}
