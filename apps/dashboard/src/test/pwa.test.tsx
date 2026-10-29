import { describe, expect, it } from "vitest";
import { render } from "@testing-library/react";
import { PwaChrome } from "../components/PwaChrome";

describe("PwaChrome", () => {
  it("renders nothing without update or install event", () => {
    const { container } = render(<PwaChrome />);
    expect(container.textContent).toBe("");
  });
});
