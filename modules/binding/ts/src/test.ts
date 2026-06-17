import test from "node:test";
import assert from "node:assert/strict";
import { render } from "./node.js";

test("render basic template", () => {
  const output = render(
    `[[@use "common.op" as $prompts]]\nHello {{ $user.name }}\n{{ $prompts.example }}\n[[@if $user.age >= 18]]\nAdult\n[[@end]]\n`,
    { user: { name: "Ada", age: 18 } },
    {
      basePath: "basic.op",
      modules: {
        "common.op": '[[@template example]]\n\n## Example Section\n\n[[@end]]\n',
      },
    },
  );

  assert.match(output, /Hello Ada/);
  assert.match(output, /Adult/);
  assert.match(output, /## Example Section/);
});
