import { afterEach, describe, expect, it, vi } from "vitest";
import { cleanup, fireEvent, render, screen } from "@testing-library/react";
import { Modal, PageHeader } from "../components/ui";
import { statusTone } from "../lib/format";

afterEach(cleanup);

describe("shared UI", () => {
  it("Modal closes on Escape and focuses its first field", () => {
    const onClose = vi.fn();
    render(
      <Modal title="Test" onClose={onClose}>
        <input aria-label="first" />
      </Modal>,
    );
    expect(document.activeElement).toBe(screen.getByLabelText("first"));
    fireEvent.keyDown(document, { key: "Escape" });
    expect(onClose).toHaveBeenCalledOnce();
  });
  it("PageHeader sets the browser tab title", () => {
    render(<PageHeader title="Students" />);
    expect(document.title).toBe("Students · LicenseLogger");
  });
  it("statusTone maps statuses consistently", () => {
    expect(statusTone("signed")).toBe("ok");
    expect(statusTone("pending")).toBe("warn");
    expect(statusTone("no_show")).toBe("bad");
    expect(statusTone("booked")).toBe("info");
    expect(statusTone("mystery")).toBe("");
  });
});
