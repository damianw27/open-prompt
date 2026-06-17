; OpenPrompt highlighting

; Directive wrappers — low priority so inner captures win
(template_start) @keyword (#set! priority 1)
(use_directive) @keyword (#set! priority 1)
(inject_directive) @keyword (#set! priority 1)
(if_start) @keyword (#set! priority 1)
(elseif_start) @keyword (#set! priority 1)
(else_directive) @keyword (#set! priority 1)
(end_directive) @keyword (#set! priority 1)
(for_start) @keyword (#set! priority 1)

[
  "as"
  "in"
  "not"
] @keyword (#set! priority 50)

[
  "]]"
  "{{"
  "}}"
  "["
  "]"
  "."
  "("
  ")"
] @punctuation.delimiter

(cond_operator) @operator

(use_directive
  alias: (variable_identifier) @variable (#set! priority 100))

(for_start
  variable: (variable_identifier) @variable (#set! priority 100)
  iterable: (for_iterable) @variable (#set! priority 100))

(variable_reference
  root: (variable_identifier) @variable (#set! priority 100))

(cond_variable_ref
  root: (variable_identifier) @variable (#set! priority 100)
  property: (identifier) @property (#set! priority 100))

(variable_path_segment
  property: (identifier) @property (#set! priority 100))

(meta_entry
  key: (identifier) @property (#set! priority 100))

(meta_entry
  value: (meta_value (string)) @string (#set! priority 100))

(meta_entry
  value: (meta_value (identifier)) @property (#set! priority 100))

(prompt_selection
  prompt: (string) @string.special (#set! priority 100))

(template_start
  name: (prompt_name) @string.special (#set! priority 100))

(string) @string (#set! priority 100)
(number) @number (#set! priority 100)
(boolean) @constant.builtin (#set! priority 100)
"null" @constant.builtin (#set! priority 100)

(front_matter_start) @punctuation.special
(front_matter_end) @punctuation.special
(front_matter_blank) @punctuation.special
(front_matter_text) @property

(fence_open) @punctuation.special
(fence_close) @punctuation.special
(tilde_fence_open) @punctuation.special
(tilde_fence_close) @punctuation.special
(backtick_code_text) @text.literal
(tilde_code_text) @text.literal

(heading) @markup.heading
(blockquote_line) @markup.quote
(list_line) @markup.list
(ordered_list_line) @markup.list

(markdown_text) @markup.raw
(blank_line) @markup.raw
(other_char) @markup.raw
