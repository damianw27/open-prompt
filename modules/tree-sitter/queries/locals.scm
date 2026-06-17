; Variables defined by loops and use directives.

(for_start
  variable: (variable_identifier) @local.definition)

(use_directive
  alias: (variable_identifier) @local.definition)

(variable_reference
  root: (variable_identifier) @local.reference)

(cond_variable_ref
  root: (variable_identifier) @local.reference)
