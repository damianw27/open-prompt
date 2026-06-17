(class_declaration
  name: (identifier) @name)

(field_declaration
  declarator: (variable_declarator
    name: (identifier) @name))

(method_declaration
  parameters: (formal_parameters
    (formal_parameter
      name: (identifier) @name)))

(record_declaration
  name: (identifier) @name)
