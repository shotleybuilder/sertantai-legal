%{
  configs: [
    %{
      name: "default",
      files: %{
        included: [
          "lib/",
          "test/"
        ],
        excluded: [~r"/_build/", ~r"/deps/", ~r"/node_modules/"]
      },
      plugins: [],
      requires: [],
      strict: false,
      parse_timeout: 5000,
      color: true,
      checks: %{
        enabled: [
          ## Design Checks
          {Credo.Check.Design.AliasUsage, priority: :low, exit_status: 0},
          {Credo.Check.Design.TagFIXME, priority: :low, exit_status: 0},
          {Credo.Check.Design.TagTODO, priority: :low, exit_status: 0},

          ## Consistency Checks
          {Credo.Check.Consistency.ExceptionNames, priority: :normal, exit_status: 2},
          {Credo.Check.Consistency.LineEndings, priority: :normal, exit_status: 2},
          {Credo.Check.Consistency.ParameterPatternMatching, priority: :normal, exit_status: 2},
          {Credo.Check.Consistency.SpaceAroundOperators, priority: :normal, exit_status: 2},
          {Credo.Check.Consistency.SpaceInParentheses, priority: :normal, exit_status: 2},
          {Credo.Check.Consistency.TabsOrSpaces, priority: :normal, exit_status: 2},

          ## Readability Checks
          {Credo.Check.Readability.AliasOrder, priority: :low, exit_status: 0},
          {Credo.Check.Readability.FunctionNames, priority: :high, exit_status: 2},
          {Credo.Check.Readability.LargeNumbers, priority: :low, exit_status: 0},
          {Credo.Check.Readability.MaxLineLength,
           priority: :low, max_length: 120, exit_status: 0},
          {Credo.Check.Readability.ModuleAttributeNames, priority: :high, exit_status: 2},
          {Credo.Check.Readability.ModuleDoc, priority: :low, exit_status: 0},
          {Credo.Check.Readability.ModuleNames, priority: :high, exit_status: 2},
          {Credo.Check.Readability.ParenthesesInCondition, priority: :normal, exit_status: 2},
          {Credo.Check.Readability.ParenthesesOnZeroArityDefs, priority: :normal, exit_status: 2},
          {Credo.Check.Readability.PipeIntoAnonymousFunctions, priority: :normal, exit_status: 2},
          {Credo.Check.Readability.PredicateFunctionNames, priority: :normal, exit_status: 2},
          {Credo.Check.Readability.PreferImplicitTry, priority: :low, exit_status: 0},
          {Credo.Check.Readability.RedundantBlankLines, priority: :low, exit_status: 0},
          {Credo.Check.Readability.Semicolons, priority: :high, exit_status: 2},
          {Credo.Check.Readability.SpaceAfterCommas, priority: :low, exit_status: 0},
          {Credo.Check.Readability.StringSigils, priority: :low, exit_status: 0},
          {Credo.Check.Readability.TrailingBlankLine, priority: :low, exit_status: 0},
          {Credo.Check.Readability.TrailingWhiteSpace, priority: :low, exit_status: 0},
          {Credo.Check.Readability.UnnecessaryAliasExpansion, priority: :low, exit_status: 0},
          {Credo.Check.Readability.VariableNames, priority: :high, exit_status: 2},
          {Credo.Check.Readability.WithSingleClause, priority: :low, exit_status: 0},

          ## Refactoring Opportunities
          {Credo.Check.Refactor.CondStatements, priority: :low, exit_status: 0},
          {Credo.Check.Refactor.CyclomaticComplexity,
           priority: :normal, max_complexity: 9, exit_status: 0},
          {Credo.Check.Refactor.FunctionArity, priority: :low, max_arity: 8, exit_status: 0},
          {Credo.Check.Refactor.LongQuoteBlocks, priority: :low, exit_status: 0},
          {Credo.Check.Refactor.MatchInCondition, priority: :low, exit_status: 0},
          {Credo.Check.Refactor.MapInto, priority: :low, exit_status: 0},
          {Credo.Check.Refactor.NegatedConditionsInUnless, priority: :normal, exit_status: 0},
          {Credo.Check.Refactor.NegatedConditionsWithElse, priority: :low, exit_status: 0},
          {Credo.Check.Refactor.Nesting, priority: :normal, max_nesting: 2, exit_status: 0},
          {Credo.Check.Refactor.UnlessWithElse, priority: :normal, exit_status: 0},
          {Credo.Check.Refactor.WithClauses, priority: :low, exit_status: 0},

          ## Warnings
          {Credo.Check.Warning.ApplicationConfigInModuleAttribute,
           priority: :normal, exit_status: 2},
          {Credo.Check.Warning.BoolOperationOnSameValues, priority: :high, exit_status: 2},
          {Credo.Check.Warning.ExpensiveEmptyEnumCheck, priority: :normal, exit_status: 2},
          {Credo.Check.Warning.IExPry, priority: :high, exit_status: 2},
          {Credo.Check.Warning.IoInspect, priority: :normal, exit_status: 0},
          {Credo.Check.Warning.OperationOnSameValues, priority: :high, exit_status: 2},
          {Credo.Check.Warning.OperationWithConstantResult, priority: :high, exit_status: 2},
          {Credo.Check.Warning.RaiseInsideRescue, priority: :normal, exit_status: 2},
          {Credo.Check.Warning.SpecWithStruct, priority: :normal, exit_status: 0},
          {Credo.Check.Warning.UnusedEnumOperation, priority: :high, exit_status: 2},
          {Credo.Check.Warning.UnusedFileOperation, priority: :high, exit_status: 2},
          {Credo.Check.Warning.UnusedKeywordOperation, priority: :high, exit_status: 2},
          {Credo.Check.Warning.UnusedListOperation, priority: :high, exit_status: 2},
          {Credo.Check.Warning.UnusedPathOperation, priority: :high, exit_status: 2},
          {Credo.Check.Warning.UnusedRegexOperation, priority: :high, exit_status: 2},
          {Credo.Check.Warning.UnusedStringOperation, priority: :high, exit_status: 2},
          {Credo.Check.Warning.UnusedTupleOperation, priority: :high, exit_status: 2}
        ],
        disabled: [
          # Disabled because Ash resources have a specific pattern
          {Credo.Check.Design.DuplicatedCode, priority: :low, exit_status: 0},

          # Can be noisy with Ash's DSL
          {Credo.Check.Readability.Specs, priority: :low, exit_status: 0}
        ]
      }
    }
  ]
}
