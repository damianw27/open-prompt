// Tree-sitter grammar for OpenPrompt.
// Converted from OpenPromptLexer.g4 + OpenPromptParser.g4.
//
// Key changes from ANTLR:
// - ANTLR lexer modes are replaced with parser context.
// - start-of-line / first-line predicates are handled by src/scanner.c.
// - skipped whitespace inside tags is represented explicitly with private rules.

const IDENT = /[A-Za-z_][A-Za-z_0-9]*/;
const VAR_IDENT = /\$[A-Za-z_][A-Za-z_0-9]*/;
const NUMBER = /[0-9]+(\.[0-9]+)?/;
const STRING = choice(
  /"([^"\\]|\\[btnfr"'\\]|\\u[0-9a-fA-F]{4})*"/,
  /'([^'\\]|\\[btnfr"'\\]|\\u[0-9a-fA-F]{4})*'/
);

module.exports = grammar({
  name: 'openprompt',

  // Do not use global whitespace extras. In this language normal spaces and
  // newlines are prompt text outside tags.
  extras: $ => [],

  externals: $ => [
    $.front_matter_start,
    $.front_matter_end,
    $.front_matter_text,
    $.front_matter_blank,

    $.fence_open,
    $.fence_close,
    $.backtick_code_text,

    $.tilde_fence_open,
    $.tilde_fence_close,
    $.tilde_code_text,

    $.heading,
    $.blockquote_line,
    $.list_line,
    $.ordered_list_line,
    $.blank_line,
    $.markdown_text,
    $.cond_operator,
    $.newline_token,
  ],

  word: $ => $.identifier,

  rules: {
    document: $ => seq(
      optional($.front_matter),
      repeat($.document_element)
    ),

    front_matter: $ => seq(
      $.front_matter_start,
      repeat($.front_matter_line),
      $.front_matter_end
    ),

    front_matter_line: $ => choice(
      $.front_matter_text,
      $.front_matter_blank
    ),

    document_element: $ => choice(
      $.use_directive,
      $.sub_prompt,
      $.prompt_content
    ),

    sub_prompt: $ => seq(
      $.template_start,
      repeat(choice(
        $.meta_block,
        $.prompt_content
      )),
      $.end_directive
    ),

    template_start: $ => seq(
      '[[@template',
      $._dir_ws,
      field('name', $.prompt_name),
      optional($._dir_ws),
      ']]'
    ),

    prompt_content: $ => choice(
      $.markdown_block,
      $.inject_directive,
      $.interpolation,
      $.conditional_block,
      $.for_loop,
      $.markdown_inline
    ),

    meta_block: $ => seq(
      // ponytail: reuse the existing front-matter delimiters for template meta blocks.
      $.front_matter_start,
      repeat(choice(
        $.meta_entry,
        $.front_matter_blank
      )),
      $.front_matter_end
    ),

    markdown_block: $ => choice(
      $.heading,
      $.blockquote_line,
      $.list_item,
      $.ordered_list_item,
      $.blank_line,
      $.fenced_code
    ),

    list_item: $ => seq(
      $.list_line,
      repeat(choice(
        $.interpolation,
        $.inject_directive,
        $.markdown_text,
        $.other_char
      )),
      $.newline_token
    ),

    ordered_list_item: $ => seq(
      $.ordered_list_line,
      repeat(choice(
        $.interpolation,
        $.inject_directive,
        $.markdown_text,
        $.other_char
      )),
      $.newline_token
    ),

    fenced_code: $ => choice(
      seq(
        $.fence_open,
        repeat($.backtick_code_text),
        $.fence_close
      ),
      seq(
        $.tilde_fence_open,
        repeat($.tilde_code_text),
        $.tilde_fence_close
      )
    ),

    markdown_inline: $ => choice(
      $.markdown_text,
      $.newline_token,
      $.other_char
    ),

    prompt_name: $ => choice(
      $.string,
      $.identifier
    ),

    use_directive: $ => seq(
      '[[@use',
      $._dir_ws,
      field('value', $.use_value),
      $._dir_ws,
      'as',
      $._dir_ws,
      field('alias', $.variable_identifier),
      optional($._dir_ws),
      ']]'
    ),

    inject_directive: $ => seq(
      '[[@inject',
      $._dir_ws,
      field('path', $.directive_path),
      optional($._dir_ws),
      ']]'
    ),

    directive_path: $ => $.string,

    use_value: $ => choice(
      $.directive_path,
      $.number,
      $.boolean
    ),

    meta_entry: $ => seq(
      field('key', $.identifier),
      $._meta_ws,
      field('value', $.meta_value),
      $.newline_token
    ),

    meta_value: $ => choice(
      $.identifier,
      $.string
    ),

    interpolation: $ => seq(
      '{{',
      optional($._var_ws),
      field('variable', $.variable_reference),
      optional($._var_ws),
      '}}'
    ),

    variable_reference: $ => seq(
      field('root', $.variable_identifier),
      repeat($.variable_path_segment),
      optional($.prompt_selection)
    ),

    variable_path_segment: $ => seq(
      '.',
      field('property', $.identifier)
    ),

    prompt_selection: $ => seq(
      '[',
      field('prompt', $.string),
      ']'
    ),

    conditional_block: $ => seq(
      $.if_start,
      repeat($.prompt_content),
      repeat($.elseif_branch),
      optional($.else_branch),
      $.end_directive
    ),

    if_start: $ => seq(
      '[[@if',
      $._cond_ws,
      field('condition', $.condition_expr),
      optional($._cond_ws),
      ']]'
    ),

    elseif_branch: $ => seq(
      $.elseif_start,
      repeat($.prompt_content)
    ),

    elseif_start: $ => seq(
      '[[@elseif',
      $._cond_ws,
      field('condition', $.condition_expr),
      optional($._cond_ws),
      ']]'
    ),

    else_branch: $ => seq(
      $.else_directive,
      repeat($.prompt_content)
    ),

    else_directive: $ => '[[@else]]',
    end_directive: $ => '[[@end]]',

    for_loop: $ => seq(
      $.for_start,
      repeat($.prompt_content),
      $.end_directive
    ),

    for_start: $ => seq(
      '[[@for',
      $._cond_ws,
      field('variable', $.variable_identifier),
      $._cond_ws,
      'in',
      $._cond_ws,
      field('iterable', $.for_iterable),
      optional($._cond_ws),
      ']]'
    ),

    for_iterable: $ => seq(
      $.identifier,
      repeat(seq('.', $.identifier))
    ),

    condition_expr: $ => prec.left(seq(
      $.cond_unary_expr,
      repeat(seq(
        $.cond_operator,
        $._cond_ws,
        $.cond_unary_expr
      ))
    )),

    cond_unary_expr: $ => choice(
      prec(5, seq('not', $._cond_ws, $.cond_unary_expr)),
      $.cond_primary_expr
    ),

    cond_primary_expr: $ => choice(
      $.boolean,
      'null',
      $.number,
      $.string,
      $.cond_variable_ref,
      seq('(', optional($._cond_ws), $.condition_expr, optional($._cond_ws), ')')
    ),

    cond_variable_ref: $ => seq(
      field('root', $.variable_identifier),
      repeat(seq('.', field('property', $.identifier)))
    ),

    other_char: _ => /./,

    variable_identifier: _ => token(VAR_IDENT),
    identifier: _ => token(IDENT),
    number: _ => token(NUMBER),
    string: _ => token(STRING),
    boolean: _ => choice('true', 'false'),

    _dir_ws: _ => /[ \t]+/,
    _meta_ws: _ => /[ \t]+/,
    _var_ws: _ => /[ \t]+/,
    _cond_ws: _ => /[ \t\r\n]+/,
  }
});
