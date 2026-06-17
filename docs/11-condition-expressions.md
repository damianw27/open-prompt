# Condition expressions

Used in `[[@if …]]` and `[[@elseif …]]`. Evaluate to true/false; pick a branch.

---

## Forms

```ebnf
condition_expr ::= unary_expr (operator unary_expr)*
unary_expr ::= "not" unary_expr | primary
primary ::= boolean | "null" | number | string
          | variable_ref | "(" condition_expr ")"
```

### Literals

```op
[[@if true]]
[[@if false]]
[[@if null]]
[[@if 3.14]]
[[@if "ok"]]
```

Truthiness: [Types and Truthiness](12-types-and-truthiness.md).

### Variables

```op
[[@if $user.active]]
[[@if $user.profile.verified]]
```

Same resolution order as interpolation. Missing → null (falsy).

### `not`

```op
[[@if not $user.active]]
```

Negates truthiness of operand.

### Parentheses

```op
[[@if ($user.score > 10)]]
[[@if ($user.age >= 18) and ($user.role == "admin")]]
```

Use these when mixing comparisons with `and` / `or`. Seriously.

---

## Operators

| Operator | Meaning |
|----------|---------|
| `==` | Equal (numeric if both numbers, else string) |
| `!=` | Not equal |
| `<` `>` `<=` `>=` | Numeric compare (`>=` may coerce via string parse) |
| `and` `or` | Both / either truthy |
| `in` | Array membership or substring |
| `matches` | Right string contains left (substring, not regex) |

Lowercase words: `and`, `or`, `in`, `not`, `matches`.

---

## Comparisons

```op
[[@if $user.age >= 18]]
[[@if $user.role == "admin"]]
[[@if $user.role != "guest"]]
[[@if $user.score < 10]]
```

Both numbers → numeric compare for `==` / `!=`. Otherwise string compare.

---

## `and` / `or`

```op
[[@if $user.active and $user.verified]]
[[@if $user.admin or $user.role == "moderator"]]
```

### No precedence

> Warning: left-to-right only. No operator precedence like C or Python.

This probably doesn't mean what you think:

```op
[[@if $user.age >= 18 and $user.role == "admin"]]
```

Write:

```op
[[@if ($user.age >= 18) and ($user.role == "admin")]]
```

Each `(...)` is one operand.

---

## `in`

```op
[[@if "admin" in $user.roles]]
[[@if $needle in $haystack]]
```

| Right side | Meaning |
|------------|---------|
| Array | Any element's string equals left |
| String | Right contains left as substring |

---

## `matches`

```op
[[@if $user.admin matches "yes"]]
```

Right contains left. Name says "matches"; behavior is substring search.

---

## Combined example

```op
[[@if ($user.role != "guest" or $user.admin matches "yes")]]
Full access
[[@elseif ($user.score < 10)]]
Limited access
[[@else]]
Denied
[[@end]]
```

---

## Related

- [Conditionals](06-conditionals.md)
- [Types and Truthiness](12-types-and-truthiness.md)
- [Language Reference](15-language-reference.md)
