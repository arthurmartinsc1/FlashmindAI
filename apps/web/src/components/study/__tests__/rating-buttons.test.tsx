import React from "react";
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, it, expect, vi } from "vitest";
import { RatingButtons } from "../rating-buttons";

vi.mock("framer-motion", () => ({
  motion: {
    div: ({ children, initial, animate, transition, ...rest }: any) =>
      React.createElement("div", rest, children),
  },
}));

describe("RatingButtons", () => {
  it("renderiza os 4 botões com label e subtítulo", () => {
    render(<RatingButtons onRate={vi.fn()} />);

    expect(screen.getByText("Não lembrei")).toBeInTheDocument();
    expect(screen.getByText("Vejo amanhã")).toBeInTheDocument();
    expect(screen.getByText("Difícil")).toBeInTheDocument();
    expect(screen.getByText("Bom")).toBeInTheDocument();
    expect(screen.getByText("Fácil")).toBeInTheDocument();
  });

  it.each([
    ["Não lembrei", 1],
    ["Difícil", 3],
    ["Bom", 4],
    ["Fácil", 5],
  ] as const)('chama onRate com %i ao clicar em "%s"', async (label, quality) => {
    const onRate = vi.fn();
    render(<RatingButtons onRate={onRate} />);

    await userEvent.click(screen.getByText(label));

    expect(onRate).toHaveBeenCalledOnce();
    expect(onRate).toHaveBeenCalledWith(quality);
  });

  it("desabilita todos os botões quando disabled=true", () => {
    render(<RatingButtons onRate={vi.fn()} disabled />);

    screen.getAllByRole("button").forEach((btn) => expect(btn).toBeDisabled());
  });

  it("não chama onRate quando desabilitado", async () => {
    const onRate = vi.fn();
    render(<RatingButtons onRate={onRate} disabled />);

    await userEvent.click(screen.getByText("Fácil"));

    expect(onRate).not.toHaveBeenCalled();
  });
});
