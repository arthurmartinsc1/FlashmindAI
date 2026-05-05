import React from "react";
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, it, expect, vi } from "vitest";
import { StudySummary } from "../study-summary";
import type { SessionResult } from "@/hooks/use-study";
import type { Card } from "@/types/api";

vi.mock("framer-motion", () => ({
  motion: {
    div: ({ children, initial, animate, transition, ...rest }: any) =>
      React.createElement("div", rest, children),
  },
  AnimatePresence: ({ children }: any) => children,
}));

vi.mock("next/link", () => ({
  default: ({ href, children, className }: any) =>
    React.createElement("a", { href, className }, children),
}));

vi.mock("lucide-react", () => ({
  CheckCircle2: () => React.createElement("span"),
  XCircle: () => React.createElement("span"),
  Clock: () => React.createElement("span"),
  RotateCcw: () => React.createElement("span"),
  BookOpen: () => React.createElement("span"),
}));

const makeCard = (id: string): Card => ({
  id,
  deck_id: "deck-1",
  front: `Pergunta ${id}`,
  back: `Resposta ${id}`,
  tags: [],
  source: "",
  ease_factor: 2.5,
  interval: 1,
  repetitions: 0,
  next_review: "2026-05-05",
  created_at: "2026-01-01T00:00:00Z",
  updated_at: "2026-01-01T00:00:00Z",
});

const makeResult = (id: string, quality: number, timeMs = 3000): SessionResult => ({
  card: makeCard(id),
  quality,
  timeMs,
});

describe("StudySummary", () => {
  it("exibe contagem correta de acertos e erros", () => {
    const results = [
      makeResult("1", 5),
      makeResult("2", 4),
      makeResult("3", 3),
      makeResult("4", 1),
    ];

    render(<StudySummary results={results} onRestart={vi.fn()} />);

    const numbers = screen.getAllByText(/^\d+$/);
    const values = numbers.map((el) => el.textContent);

    expect(values).toContain("3"); // acertos
    expect(values).toContain("1"); // erros
  });

  it("exibe tempo médio por card em segundos", () => {
    const results = [
      makeResult("1", 5, 4000),
      makeResult("2", 4, 6000),
    ];

    render(<StudySummary results={results} onRestart={vi.fn()} />);

    expect(screen.getByText("5s")).toBeInTheDocument();
  });

  it("exibe mensagem de excelente quando acerto >= 90%", () => {
    const results = [
      makeResult("1", 5),
      makeResult("2", 5),
      makeResult("3", 5),
      makeResult("4", 5),
      makeResult("5", 5),
      makeResult("6", 5),
      makeResult("7", 5),
      makeResult("8", 5),
      makeResult("9", 5),
      makeResult("10", 1),
    ];

    render(<StudySummary results={results} onRestart={vi.fn()} />);

    expect(screen.getByText("Excelente domínio. Continue assim.")).toBeInTheDocument();
  });

  it("exibe mensagem de 'bom resultado' quando acerto está entre 70% e 89%", () => {
    const results = [
      makeResult("1", 5),
      makeResult("2", 5),
      makeResult("3", 5),
      makeResult("4", 1),
    ];

    render(<StudySummary results={results} onRestart={vi.fn()} />);

    expect(screen.getByText("Bom resultado. A repetição vai consolidar.")).toBeInTheDocument();
  });

  it("exibe mensagem de incentivo quando acerto < 70%", () => {
    const results = [makeResult("1", 1), makeResult("2", 1)];

    render(<StudySummary results={results} onRestart={vi.fn()} />);

    expect(screen.getByText("Cada revisão fortalece sua memória.")).toBeInTheDocument();
  });

  it("chama onRestart ao clicar em 'Nova sessão'", async () => {
    const onRestart = vi.fn();
    render(<StudySummary results={[makeResult("1", 5)]} onRestart={onRestart} />);

    await userEvent.click(screen.getByText("Nova sessão"));

    expect(onRestart).toHaveBeenCalledOnce();
  });

  it("link 'Outros decks' aponta para /review", () => {
    render(<StudySummary results={[makeResult("1", 5)]} onRestart={vi.fn()} />);

    expect(screen.getByText("Outros decks").closest("a")).toHaveAttribute("href", "/review");
  });
});
