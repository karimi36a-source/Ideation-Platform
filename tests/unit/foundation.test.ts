import { createElement } from "react";
import { renderToStaticMarkup } from "react-dom/server";
import { expect, test } from "vitest";
import HomePage from "@/app/page";

test("renders the foundation page without external services", () => {
  const html = renderToStaticMarkup(createElement(HomePage));

  expect(html).toContain(
    "<h1>FICI Invention Education &amp; Development Platform</h1>",
  );
});
