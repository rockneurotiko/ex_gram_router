dsl_macros = [scope: 1, filter: 1, filter: 2, handle: 1, alias_filter: 2]

[
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  locals_without_parens: dsl_macros,
  plugins: [Quokka],
  line_length: 120,
  export: [locals_without_parens: dsl_macros]
]
