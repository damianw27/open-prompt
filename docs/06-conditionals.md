# Conditionals

Include or skip prompt sections based on a condition. Typical for roles, feature flags, plan tiers.

---

## Syntax

```op
[[@if condition]]
  content when true
[[@elseif other_condition]]
  alternate content
[[@else]]
  fallback content
[[@end]]
```

| Part | Required? |
|------|-------------|
| `[[@if condition]]` | Yes |
| `[[@elseif condition]]` | No (repeatable) |
| `[[@else]]` | No |
| `[[@end]]` | Yes |

`@elseif` and `@else` are optional. `@if` alone + `[[@end]]` is fine.

---

## Which branch runs

Top to bottom:

1. `@if` true → render body, stop
2. Else try each `@elseif` in order; first true wins
3. Else `@else` if present
4. Else render nothing for this block

One branch per block.

---

## Age gate

```op
[[@if $user.age >= 18]]
You have full access.
[[@elseif $user.age == 17]]
You have limited access until your next birthday.
[[@else]]
You need a guardian account.
[[@end]]
```

Context `{ "user": { "age": 17 } }` → limited access line.

Context `{ "user": { "age": 12 } }` → guardian line.

---

## By role

```op
[[@if $user.role == "admin"]]
You may approve or reject requests.
[[@elseif $user.role == "editor"]]
You may edit but not approve.
[[@else]]
You have read-only access.
[[@end]]
```

Combine comparisons with `and` / `or`? Use parentheses. [Condition Expressions](11-condition-expressions.md).

---

## Literal conditions

```op
[[@if true]]
always shown
[[@end]]

[[@if null]]
never shown
[[@end]]
```

Truthiness: [Types and Truthiness](12-types-and-truthiness.md).

---

## Nesting

```op
[[@if $user.premium]]
Premium instructions:

[[@if $user.beta]]
Beta feature notes apply.
[[@end]]
[[@else]]
Standard instructions.
[[@end]]
```

Each block needs its own `[[@end]]`.

---

## Empty branches

Whitespace-only branch → whitespace in output when that branch runs.

---

## Condition syntax

Comparisons, `and` / `or`, `in`, `matches`, `not`. Full detail:

→ [Condition Expressions](11-condition-expressions.md)

---

## Related

- [Condition Expressions](11-condition-expressions.md)
- [Types and Truthiness](12-types-and-truthiness.md)
- [Loops](07-loops.md)
