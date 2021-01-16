# Used by "mix format"
[
  inputs: [
    "{mix,.formatter}.exs",
    "{config,lib}/**/*.{ex,exs}",

    # Be explicit here about which files in the test directory we want
    # formatted, we don't want to format generated protobuf files
    "test/lightrail/**/*.{ex,exs}",
    "test/support/*.{ex,exs}",
    "test_helper.exs"
  ]
]
