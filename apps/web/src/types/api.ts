export type UUID = string;

export type User = {
  id: UUID;
  email: string;
  name: string;
  is_email_verified: boolean;
  created_at: string;
};

export type TokenPair = {
  access_token: string;
  refresh_token: string;
  token_type: string;
};

export type AuthResponse = {
  user: User;
  tokens: TokenPair;
};

export type Deck = {
  id: UUID;
  title: string;
  description: string;
  color: string;
  is_public: boolean;
  is_archived: boolean;
  card_count: number;
  due_count: number;
  lesson_locked_cards_count: number;
  has_pending_lesson_gate: boolean;
  created_at: string;
  updated_at: string;
};

export type DeckList = {
  decks: Deck[];
  count: number;
  limit: number;
  offset: number;
};

export type ActivityPoint = { date: string; count: number };

export type CardDistribution = { new: number; learning: number; mature: number };

export type Dashboard = {
  due_today: number;
  reviewed_today: number;
  reviewed_week: number;
  reviewed_month: number;
  retention_rate: number;
  current_streak: number;
  longest_streak: number;
  activity_last_30_days: ActivityPoint[];
  card_distribution: CardDistribution;
};

export type ApiError = { detail: string };

export type Card = {
  id: UUID;
  deck_id: UUID;
  front: string;
  back: string;
  tags: string[];
  source: string;
  ease_factor: number;
  interval: number;
  repetitions: number;
  next_review: string;
  created_at: string;
  updated_at: string;
};

export type DueCardsOut = {
  cards: Card[];
  total_due: number;
};

export type ReviewOut = {
  card_id: UUID;
  ease_factor: number;
  interval: number;
  repetitions: number;
  next_review: string;
};

export type ReviewSummaryOut = {
  date: string;
  reviewed: number;
  correct: number;
  time_total_ms: number;
};

export type CardList = {
  cards: Card[];
  count: number;
  limit: number;
  offset: number;
};

export type LessonSummary = {
  id: UUID;
  deck_id: UUID;
  title: string;
  order: number;
  estimated_minutes: number;
  created_at: string;
  updated_at: string;
  completed: boolean;
};

export type LessonList = {
  lessons: LessonSummary[];
  count: number;
};

export type DeckIn = {
  title: string;
  description?: string;
  color?: string;
  is_public?: boolean;
};

// ─── Microlearning ───────────────────────────────────────────
export type TextBlockContent = { body: string };
export type HighlightBlockContent = {
  body: string;
  color: "yellow" | "blue" | "green";
};
export type QuizBlockContent = {
  question: string;
  options: string[];
  correct: number;
  explanation: string;
};

export type ContentBlock =
  | { id: UUID; type: "text";      order: number; content: TextBlockContent }
  | { id: UUID; type: "highlight"; order: number; content: HighlightBlockContent }
  | { id: UUID; type: "quiz";      order: number; content: QuizBlockContent };

export type LessonDetail = LessonSummary & { blocks: ContentBlock[] };

export type CompleteLessonOut = {
  lesson_id: UUID;
  already_completed: boolean;
  unlocked_cards_count: number;
};

// ─── Async jobs (geração via IA) ─────────────────────────────
export type GenerateCardsIn = {
  topic: string;
  count?: number;
  language?: string;
  source_text?: string;
};

export type AsyncJobStatus = "pending" | "running" | "completed" | "failed";

export type AsyncJob = {
  id: UUID;
  kind: "generate_cards" | string;
  status: AsyncJobStatus;
  params: Record<string, unknown>;
  result: { deck_id: UUID; created_count: number; skipped_count: number } | null;
  error: string;
  workflow_id: string;
  created_at: string;
  updated_at: string;
  started_at: string | null;
  finished_at: string | null;
};
