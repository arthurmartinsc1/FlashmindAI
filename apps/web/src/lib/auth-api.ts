"use client";

import { api } from "@/lib/api";
import type {
  AsyncJob,
  AuthResponse,
  Card,
  CardList,
  CompleteLessonOut,
  Dashboard,
  Deck,
  DeckIn,
  DeckList,
  DueCardsOut,
  GenerateCardsIn,
  LessonDetail,
  LessonList,
  ReviewOut,
  User,
} from "@/types/api";

export async function registerUser(payload: {
  email: string;
  password: string;
  name: string;
}) {
  const { data } = await api.post<AuthResponse>("/auth/register", payload);
  return data;
}

export async function loginUser(payload: { email: string; password: string }) {
  const { data } = await api.post<AuthResponse>("/auth/login", payload);
  return data;
}

export async function fetchMe() {
  const { data } = await api.get<User>("/auth/me");
  return data;
}

export async function logoutRemote() {
  await api.post("/auth/logout");
}

export async function verifyEmailPin(pin: string) {
  const { data } = await api.post<User>("/auth/email/verify", { pin });
  return data;
}

export async function resendEmailVerification() {
  const { data } = await api.post<{
    sent: boolean;
    expires_in_minutes: number;
    cooldown_seconds: number;
  }>("/auth/email/resend");
  return data;
}

export async function fetchDashboard() {
  const { data } = await api.get<Dashboard>("/progress/dashboard");
  return data;
}

export async function fetchDecks(params?: { search?: string; limit?: number; offset?: number }) {
  const { data } = await api.get<DeckList>("/decks/", { params });
  return data;
}

export async function fetchDueCards(params?: { deck_id?: string; limit?: number }) {
  const { data } = await api.get<DueCardsOut>("/review/due", { params });
  return data;
}

export async function submitReview(
  cardId: string,
  payload: { quality: number; time_spent_ms: number },
) {
  const { data } = await api.post<ReviewOut>(`/review/${cardId}`, payload);
  return data;
}

// ─── Decks ──────────────────────────────────────────────────
export async function fetchDeck(id: string) {
  const { data } = await api.get<Deck>(`/decks/${id}`);
  return data;
}

export async function createDeck(payload: DeckIn) {
  const { data } = await api.post<Deck>("/decks/", payload);
  return data;
}

export async function updateDeck(id: string, payload: Partial<DeckIn>) {
  const { data } = await api.put<Deck>(`/decks/${id}`, payload);
  return data;
}

export async function deleteDeck(id: string) {
  await api.delete(`/decks/${id}`);
}

// ─── Cards ──────────────────────────────────────────────────
export async function fetchCards(
  deckId: string,
  params?: { search?: string; limit?: number; offset?: number },
) {
  const { data } = await api.get<CardList>(`/decks/${deckId}/cards`, { params });
  return data;
}

export async function createCard(
  deckId: string,
  payload: { front: string; back: string; tags?: string[] },
) {
  const { data } = await api.post<Card>(`/decks/${deckId}/cards`, payload);
  return data;
}

export async function updateCard(
  cardId: string,
  payload: { front?: string; back?: string; tags?: string[] },
) {
  const { data } = await api.put<Card>(`/cards/${cardId}`, payload);
  return data;
}

export async function deleteCard(cardId: string) {
  await api.delete(`/cards/${cardId}`);
}

export async function importCardsCSV(deckId: string, file: File) {
  const form = new FormData();
  form.append("file", file);
  const { data } = await api.post<{ imported_count: number; skipped_count: number }>(
    `/decks/${deckId}/cards/import`,
    form,
    { headers: { "Content-Type": "multipart/form-data" } },
  );
  return data;
}

// ─── Lessons ────────────────────────────────────────────────
export async function fetchLessons(deckId: string) {
  const { data } = await api.get<LessonList>(`/decks/${deckId}/lessons`);
  return data;
}

export async function fetchLesson(lessonId: string) {
  const { data } = await api.get<LessonDetail>(`/lessons/${lessonId}`);
  return data;
}

export async function completeLesson(lessonId: string) {
  const { data } = await api.post<CompleteLessonOut>(`/lessons/${lessonId}/complete`);
  return data;
}

// ─── AI generation (async jobs) ─────────────────────────────
export async function generateCards(deckId: string, payload: GenerateCardsIn) {
  const { data } = await api.post<AsyncJob>(`/decks/${deckId}/generate`, payload);
  return data;
}

export async function fetchJob(jobId: string) {
  const { data } = await api.get<AsyncJob>(`/jobs/${jobId}`);
  return data;
}
