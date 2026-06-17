; OpenPrompt variable scope query (adapted from tree-sitter locals.scm)

(for_start
  variable: (variable_identifier) @definition)

(use_directive
  alias: (variable_identifier) @definition)

(variable_reference
  root: (variable_identifier) @reference)

(cond_variable_ref
  root: (variable_identifier) @reference)
