import React from "react";
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, it, expect, vi } from "vitest";
import { FlipCard } from "../flip-card";

vi.mock("framer-motion", () => ({
  motion: {
    div: ({ children, initial, animate, transition, ...rest }: any) =>
      React.createElement("div", rest, children),
  },
}));

vi.mock("lucide-react", () => ({
  RotateCcw: () => React.createElement("span", { "data-testid": "icon-rotate" }),
}));

describe("FlipCard", () => {
  const defaultProps = { front: "O que é React?", back: "Uma lib UI do Facebook" };

  it("mostra a face frontal e o hint antes de virar", () => {
    render(<FlipCard {...defaultProps} />);

    expect(screen.getByText("O que é React?")).toBeInTheDocument();
    expect(screen.getByText("Clique para revelar")).toBeInTheDocument();
  });

  it("aria-label indica que a resposta ainda está oculta", () => {
    render(<FlipCard {...defaultProps} />);

    expect(screen.getByRole("button")).toHaveAccessibleName(
      "Clique para revelar a resposta",
    );
  });

  it("chama onFlip ao primeiro clique", async () => {
    const onFlip = vi.fn();
    render(<FlipCard {...defaultProps} onFlip={onFlip} />);

    await userEvent.click(screen.getByRole("button"));

    expect(onFlip).toHaveBeenCalledOnce();
  });

  it("aria-label muda para 'resposta visível' após virar", async () => {
    render(<FlipCard {...defaultProps} />);

    await userEvent.click(screen.getByRole("button"));

    expect(screen.getByRole("button")).toHaveAccessibleName(
      "Card — resposta visível",
    );
  });

  it("não chama onFlip em cliques subsequentes", async () => {
    const onFlip = vi.fn();
    render(<FlipCard {...defaultProps} onFlip={onFlip} />);

    await userEvent.click(screen.getByRole("button"));
    await userEvent.click(screen.getByRole("button"));
    await userEvent.click(screen.getByRole("button"));

    expect(onFlip).toHaveBeenCalledOnce();
  });

  it("reseta para a frente quando front/back mudam (novo card)", async () => {
    const { rerender } = render(<FlipCard {...defaultProps} />);

    await userEvent.click(screen.getByRole("button"));
    expect(screen.getByRole("button")).toHaveAccessibleName("Card — resposta visível");

    rerender(<FlipCard front="Nova pergunta" back="Nova resposta" />);

    expect(screen.getByRole("button")).toHaveAccessibleName(
      "Clique para revelar a resposta",
    );
  });
});
