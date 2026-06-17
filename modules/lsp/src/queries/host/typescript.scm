(lexical_declaration
  (variable_declarator
    name: (identifier) @name))

(variable_declarator
  name: (identifier) @name)

(function_signature
  name: (identifier) @name)

(class_declaration
  name: (type_identifier) @name)

(interface_declaration
  name: (type_identifier) @name)

(property_signature
  name: (property_identifier) @name)
