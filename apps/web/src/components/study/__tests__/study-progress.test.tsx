import React from "react";
import { render } from "@testing-library/react";
import { describe, it, expect } from "vitest";
import { StudyProgress } from "../study-progress";

vi.mock("framer-motion", () => ({
  motion: {
    div: ({ children, initial, animate, transition, style, ...rest }: any) =>
      React.createElement("div", { ...rest, style }, children),
  },
}));

describe("StudyProgress", () => {
  it("define largura 0% quando total é 0", () => {
    const { container } = render(<StudyProgress current={0} total={0} />);
    const bar = container.querySelector("[style*='width']") as HTMLElement;
    expect(bar?.style.width).toBe("0%");
  });

  it("define largura 50% quando current=5 e total=10", () => {
    const { container } = render(<StudyProgress current={5} total={10} />);
    const bar = container.querySelector("[style*='width']") as HTMLElement;
    expect(bar?.style.width).toBe("50%");
  });

  it("define largura 100% ao final da sessão", () => {
    const { container } = render(<StudyProgress current={8} total={8} />);
    const bar = container.querySelector("[style*='width']") as HTMLElement;
    expect(bar?.style.width).toBe("100%");
  });
});
