#include "tree_sitter/parser.h"

#include <ctype.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

// Must match the order in grammar.js externals.
enum TokenType {
  FRONT_MATTER_START,
  FRONT_MATTER_END,
  FRONT_MATTER_TEXT,
  FRONT_MATTER_BLANK,

  FENCE_OPEN,
  FENCE_CLOSE,
  BACKTICK_CODE_TEXT,

  TILDE_FENCE_OPEN,
  TILDE_FENCE_CLOSE,
  TILDE_CODE_TEXT,

  HEADING,
  BLOCKQUOTE_LINE,
  LIST_LINE,
  ORDERED_LIST_LINE,
  BLANK_LINE,
  MARKDOWN_TEXT,
  COND_OPERATOR,
  NEWLINE_TOKEN,
};

void *tree_sitter_openprompt_external_scanner_create(void) { return NULL; }
void tree_sitter_openprompt_external_scanner_destroy(void *payload) { (void)payload; }
void tree_sitter_openprompt_external_scanner_reset(void *payload) { (void)payload; }
unsigned tree_sitter_openprompt_external_scanner_serialize(void *payload, char *buffer) {
  (void)payload;
  (void)buffer;
  return 0;
}
void tree_sitter_openprompt_external_scanner_deserialize(void *payload, const char *buffer, unsigned length) {
  (void)payload;
  (void)buffer;
  (void)length;
}

static inline bool is_eof(TSLexer *lexer) { return lexer->eof(lexer); }
static inline bool is_newline(int32_t c) { return c == '\n' || c == '\r'; }
static inline bool is_space(int32_t c) { return c == ' ' || c == '\t'; }
static inline bool is_digit(int32_t c) { return c >= '0' && c <= '9'; }

static void advance(TSLexer *lexer) { lexer->advance(lexer, false); }

static void consume_newline(TSLexer *lexer) {
  if (lexer->lookahead == '\r') {
    advance(lexer);
    if (lexer->lookahead == '\n') advance(lexer);
  } else if (lexer->lookahead == '\n') {
    advance(lexer);
  }
}

static void consume_until_line_end(TSLexer *lexer) {
  while (!is_eof(lexer) && !is_newline(lexer->lookahead)) {
    advance(lexer);
  }
}

static void consume_line(TSLexer *lexer) {
  consume_until_line_end(lexer);
  if (is_newline(lexer->lookahead)) consume_newline(lexer);
}

static void mark(TSLexer *lexer) { lexer->mark_end(lexer); }

static bool line_is_front_matter_delimiter(const char *line, unsigned len) {
  if (len < 3) return false;
  if (line[0] != '-' || line[1] != '-' || line[2] != '-') return false;

  unsigned i = 3;
  while (i < len && (line[i] == ' ' || line[i] == '\t')) i++;
  return i == len;
}

static bool line_starts_backtick_fence(const char *line, unsigned len) {
  return len >= 3 && line[0] == '`' && line[1] == '`' && line[2] == '`';
}

static bool line_starts_tilde_fence(const char *line, unsigned len) {
  return len >= 3 && line[0] == '~' && line[1] == '~' && line[2] == '~';
}

static bool line_is_backtick_fence_close(const char *line, unsigned len) {
  if (!line_starts_backtick_fence(line, len)) return false;
  unsigned i = 3;
  while (i < len && line[i] == '`') i++;
  while (i < len && (line[i] == ' ' || line[i] == '\t')) i++;
  return i == len;
}

static bool line_is_tilde_fence_close(const char *line, unsigned len) {
  if (!line_starts_tilde_fence(line, len)) return false;
  unsigned i = 3;
  while (i < len && line[i] == '~') i++;
  while (i < len && (line[i] == ' ' || line[i] == '\t')) i++;
  return i == len;
}

static bool line_is_heading(const char *line, unsigned len) {
  unsigned i = 0;
  while (i < len && line[i] == '#') i++;
  return i >= 1 && i <= 6 && i < len && (line[i] == ' ' || line[i] == '\t');
}

static bool line_is_list(const char *line, unsigned len) {
  unsigned i = 0;
  while (i < len && (line[i] == ' ' || line[i] == '\t')) i++;
  if (i >= len) return false;
  if (line[i] != '-' && line[i] != '*' && line[i] != '+') return false;
  i++;
  return i < len && (line[i] == ' ' || line[i] == '\t');
}

static bool line_is_ordered_list(const char *line, unsigned len) {
  unsigned i = 0;
  while (i < len && (line[i] == ' ' || line[i] == '\t')) i++;
  unsigned digit_start = i;
  while (i < len && is_digit((unsigned char)line[i])) i++;
  if (i == digit_start) return false;
  if (i >= len || line[i] != '.') return false;
  i++;
  return i < len && (line[i] == ' ' || line[i] == '\t');
}

static bool line_is_blank(const char *line, unsigned len) {
  for (unsigned i = 0; i < len; i++) {
    if (line[i] != ' ' && line[i] != '\t') return false;
  }
  return true;
}

static bool is_operator_boundary(int32_t c) {
  return c == 0 || is_space(c) || is_newline(c) || c == ']' || c == ')' || c == '(' || c == '{' || c == '}' || c == ',';
}

static bool scan_cond_operator(TSLexer *lexer, const bool *valid_symbols) {
  if (!valid_symbols[COND_OPERATOR]) return false;

  while (is_space(lexer->lookahead)) {
    advance(lexer);
  }

  if (lexer->lookahead == '<' || lexer->lookahead == '>') {
    advance(lexer);
    if (lexer->lookahead == '=') {
      advance(lexer);
    }
    mark(lexer);
    lexer->result_symbol = COND_OPERATOR;
    return true;
  }

  if (lexer->lookahead == '=' || lexer->lookahead == '!') {
    advance(lexer);
    if (lexer->lookahead == '=') {
      advance(lexer);
      mark(lexer);
      lexer->result_symbol = COND_OPERATOR;
      return true;
    }
    return false;
  }

  if (isalpha((unsigned char)lexer->lookahead)) {
    char word[16];
    unsigned len = 0;
    while (isalpha((unsigned char)lexer->lookahead) && len + 1 < sizeof(word)) {
      word[len++] = (char)lexer->lookahead;
      advance(lexer);
    }
    word[len] = '\0';

    if (is_operator_boundary(lexer->lookahead) &&
        (!strcmp(word, "and") || !strcmp(word, "or") || !strcmp(word, "in") ||
         !strcmp(word, "not") || !strcmp(word, "matches"))) {
      mark(lexer);
      lexer->result_symbol = COND_OPERATOR;
      return true;
    }
  }

  return false;
}

// Read current physical line into a small prefix buffer, consume the whole line,
// and return the number of non-newline bytes stored in the buffer.
static unsigned consume_line_with_prefix(TSLexer *lexer, char *line, unsigned cap) {
  unsigned len = 0;
  while (!is_eof(lexer) && !is_newline(lexer->lookahead)) {
    if (len + 1 < cap) line[len++] = (char)lexer->lookahead;
    advance(lexer);
  }
  if (is_newline(lexer->lookahead)) consume_newline(lexer);
  if (cap > 0) line[len] = '\0';
  return len;
}

static bool scan_front_matter(TSLexer *lexer, const bool *valid_symbols) {
  if (!valid_symbols[FRONT_MATTER_END] &&
      !valid_symbols[FRONT_MATTER_TEXT] &&
      !valid_symbols[FRONT_MATTER_BLANK]) {
    return false;
  }

  if (is_newline(lexer->lookahead)) {
    consume_newline(lexer);
    mark(lexer);
    if (valid_symbols[FRONT_MATTER_BLANK]) {
      lexer->result_symbol = FRONT_MATTER_BLANK;
      return true;
    }
    return false;
  }

  char line[256];
  unsigned len = consume_line_with_prefix(lexer, line, sizeof(line));
  mark(lexer);

  if (valid_symbols[FRONT_MATTER_END] && line_is_front_matter_delimiter(line, len)) {
    lexer->result_symbol = FRONT_MATTER_END;
    return true;
  }

  if (valid_symbols[FRONT_MATTER_TEXT]) {
    lexer->result_symbol = FRONT_MATTER_TEXT;
    return true;
  }

  return false;
}

static bool scan_backtick_code(TSLexer *lexer, const bool *valid_symbols) {
  if (!valid_symbols[FENCE_CLOSE] && !valid_symbols[BACKTICK_CODE_TEXT]) return false;

  char line[256];
  unsigned len = consume_line_with_prefix(lexer, line, sizeof(line));
  mark(lexer);

  if (valid_symbols[FENCE_CLOSE] && line_is_backtick_fence_close(line, len)) {
    lexer->result_symbol = FENCE_CLOSE;
    return true;
  }

  if (valid_symbols[BACKTICK_CODE_TEXT]) {
    lexer->result_symbol = BACKTICK_CODE_TEXT;
    return true;
  }

  return false;
}

static bool scan_tilde_code(TSLexer *lexer, const bool *valid_symbols) {
  if (!valid_symbols[TILDE_FENCE_CLOSE] && !valid_symbols[TILDE_CODE_TEXT]) return false;

  char line[256];
  unsigned len = consume_line_with_prefix(lexer, line, sizeof(line));
  mark(lexer);

  if (valid_symbols[TILDE_FENCE_CLOSE] && line_is_tilde_fence_close(line, len)) {
    lexer->result_symbol = TILDE_FENCE_CLOSE;
    return true;
  }

  if (valid_symbols[TILDE_CODE_TEXT]) {
    lexer->result_symbol = TILDE_CODE_TEXT;
    return true;
  }

  return false;
}

static bool finish_line_token(TSLexer *lexer, enum TokenType symbol) {
  consume_until_line_end(lexer);
  if (is_newline(lexer->lookahead)) consume_newline(lexer);
  mark(lexer);
  lexer->result_symbol = symbol;
  return true;
}

static bool finish_list_marker(TSLexer *lexer, enum TokenType symbol) {
  mark(lexer);
  lexer->result_symbol = symbol;
  return true;
}

static bool finish_markdown_prefix(TSLexer *lexer, const bool *valid_symbols) {
  if (!valid_symbols[MARKDOWN_TEXT]) return false;
  mark(lexer);
  lexer->result_symbol = MARKDOWN_TEXT;
  return true;
}

static bool scan_line_start_token(TSLexer *lexer, const bool *valid_symbols) {
  if (lexer->get_column(lexer) != 0) return false;

  // Leading spaces can start blank/list lines, but they can also be normal text
  // before a tag. Consume only the spaces unless a real block token is known.
  if (is_space(lexer->lookahead)) {
    bool consumed_space = false;
    while (is_space(lexer->lookahead)) {
      advance(lexer);
      consumed_space = true;
    }

    if (is_newline(lexer->lookahead) && valid_symbols[BLANK_LINE]) {
      consume_newline(lexer);
      mark(lexer);
      lexer->result_symbol = BLANK_LINE;
      return true;
    }

    if ((lexer->lookahead == '-' || lexer->lookahead == '*' || lexer->lookahead == '+') && valid_symbols[LIST_LINE]) {
      advance(lexer);
      if (is_space(lexer->lookahead)) {
        advance(lexer);
        return finish_list_marker(lexer, LIST_LINE);
      }
    }

    if (is_digit(lexer->lookahead) && valid_symbols[ORDERED_LIST_LINE]) {
      while (is_digit(lexer->lookahead)) advance(lexer);
      if (lexer->lookahead == '.') {
        advance(lexer);
        if (is_space(lexer->lookahead)) {
          advance(lexer);
          return finish_list_marker(lexer, ORDERED_LIST_LINE);
        }
      }
    }

    if (consumed_space) return finish_markdown_prefix(lexer, valid_symbols);
    return false;
  }

  if (lexer->lookahead == '-' && (valid_symbols[FRONT_MATTER_START] || valid_symbols[LIST_LINE] || valid_symbols[MARKDOWN_TEXT])) {
    advance(lexer); // first '-'

    if (lexer->lookahead == '-') {
      advance(lexer); // second '-'
      if (lexer->lookahead == '-') {
        advance(lexer); // third '-'
        mark(lexer);    // safe fallback token end: '---'

        bool only_spaces = true;
        while (!is_eof(lexer) && !is_newline(lexer->lookahead)) {
          if (!is_space(lexer->lookahead)) only_spaces = false;
          advance(lexer);
        }

        if (only_spaces && valid_symbols[FRONT_MATTER_START]) {
          if (is_newline(lexer->lookahead)) consume_newline(lexer);
          mark(lexer);
          lexer->result_symbol = FRONT_MATTER_START;
          return true;
        }

        return finish_markdown_prefix(lexer, valid_symbols);
      }
    }

    if (is_space(lexer->lookahead) && valid_symbols[LIST_LINE]) {
      advance(lexer);
      return finish_list_marker(lexer, LIST_LINE);
    }

    return finish_markdown_prefix(lexer, valid_symbols);
  }

  if (lexer->lookahead == '`' && (valid_symbols[FENCE_OPEN] || valid_symbols[MARKDOWN_TEXT])) {
    advance(lexer);
    if (lexer->lookahead == '`') {
      advance(lexer);
      if (lexer->lookahead == '`') {
        advance(lexer);
        if (valid_symbols[FENCE_OPEN]) return finish_line_token(lexer, FENCE_OPEN);
      }
    }
    return finish_markdown_prefix(lexer, valid_symbols);
  }

  if (lexer->lookahead == '~' && (valid_symbols[TILDE_FENCE_OPEN] || valid_symbols[MARKDOWN_TEXT])) {
    advance(lexer);
    if (lexer->lookahead == '~') {
      advance(lexer);
      if (lexer->lookahead == '~') {
        advance(lexer);
        if (valid_symbols[TILDE_FENCE_OPEN]) return finish_line_token(lexer, TILDE_FENCE_OPEN);
      }
    }
    return finish_markdown_prefix(lexer, valid_symbols);
  }

  if (lexer->lookahead == '#' && (valid_symbols[HEADING] || valid_symbols[MARKDOWN_TEXT])) {
    unsigned count = 0;
    while (lexer->lookahead == '#' && count < 6) {
      advance(lexer);
      count++;
    }
    if (count >= 1 && count <= 6 && is_space(lexer->lookahead) && valid_symbols[HEADING]) {
      return finish_line_token(lexer, HEADING);
    }
    return finish_markdown_prefix(lexer, valid_symbols);
  }

  if (lexer->lookahead == '>' && valid_symbols[BLOCKQUOTE_LINE]) {
    advance(lexer);
    return finish_line_token(lexer, BLOCKQUOTE_LINE);
  }

  if ((lexer->lookahead == '*' || lexer->lookahead == '+') && (valid_symbols[LIST_LINE] || valid_symbols[MARKDOWN_TEXT])) {
    advance(lexer);
    if (is_space(lexer->lookahead) && valid_symbols[LIST_LINE]) {
      advance(lexer);
      return finish_list_marker(lexer, LIST_LINE);
    }
    return finish_markdown_prefix(lexer, valid_symbols);
  }

  if (is_digit(lexer->lookahead) && (valid_symbols[ORDERED_LIST_LINE] || valid_symbols[MARKDOWN_TEXT])) {
    while (is_digit(lexer->lookahead)) advance(lexer);
    mark(lexer);
    if (lexer->lookahead == '.') {
      advance(lexer);
      if (is_space(lexer->lookahead) && valid_symbols[ORDERED_LIST_LINE]) {
        advance(lexer);
        return finish_list_marker(lexer, ORDERED_LIST_LINE);
      }
    }
    return finish_markdown_prefix(lexer, valid_symbols);
  }

  return false;
}

static bool scan_default_line_token(TSLexer *lexer, const bool *valid_symbols) {
  // Let Tree-sitter's normal lexer handle OpenPrompt tags and single fallback
  // characters. This prevents markdown_text from swallowing {{...}} or [[@...]].
  if (lexer->lookahead == '{' || lexer->lookahead == '[') {
    return false;
  }

  if (is_newline(lexer->lookahead)) {
    consume_newline(lexer);
    mark(lexer);
    if (valid_symbols[NEWLINE_TOKEN]) {
      lexer->result_symbol = NEWLINE_TOKEN;
      return true;
    }
    return false;
  }

  if (scan_line_start_token(lexer, valid_symbols)) return true;

  if (valid_symbols[MARKDOWN_TEXT]) {
    // Consume normal text until a newline or a possible OpenPrompt tag.
    bool consumed = false;
    while (!is_eof(lexer) &&
           !is_newline(lexer->lookahead) &&
           lexer->lookahead != '{' &&
           lexer->lookahead != '[') {
      advance(lexer);
      consumed = true;
    }
    if (consumed) {
      mark(lexer);
      lexer->result_symbol = MARKDOWN_TEXT;
      return true;
    }
  }

  return false;
}

bool tree_sitter_openprompt_external_scanner_scan(void *payload, TSLexer *lexer, const bool *valid_symbols) {
  (void)payload;

  if (is_eof(lexer)) return false;

  // Context-sensitive scanner states are selected by Tree-sitter's valid token set.
  if (scan_front_matter(lexer, valid_symbols)) return true;
  if (scan_backtick_code(lexer, valid_symbols)) return true;
  if (scan_tilde_code(lexer, valid_symbols)) return true;
  if (scan_cond_operator(lexer, valid_symbols)) return true;
  if (scan_default_line_token(lexer, valid_symbols)) return true;

  return false;
}
