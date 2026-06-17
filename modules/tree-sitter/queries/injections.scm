; Fenced code blocks. Fence info-string parsing can refine injection.language later.

(fenced_code
  (backtick_code_text) @injection.content
  (#set! injection.language "text"))

(fenced_code
  (tilde_code_text) @injection.content
  (#set! injection.language "text"))
