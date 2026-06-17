(variable_declaration
  name: (identifier) @name)

(assignment_statement
  name: (identifier) @name)

(function_declaration
  name: (identifier) @name)

(table_constructor
  (field
    name: (identifier) @name))
