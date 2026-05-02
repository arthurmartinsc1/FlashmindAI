import type { Metadata, Viewport } from "next";
import { Inter } from "next/font/google";
import "./globals.css";
import { Providers } from "@/components/providers";

const inter = Inter({
  subsets: ["latin"],
  variable: "--font-inter",
  display: "swap",
});

const APP_NAME = "FlashMind";
const APP_DESCRIPTION =
  "Plataforma de estudos com flashcards inteligentes, repetição espaçada (SM-2) e microlearning. Gere cards com IA e estude em 5 minutos por dia.";
const APP_URL = process.env.NEXT_PUBLIC_APP_URL ?? "https://flashmind.app";

export const metadata: Metadata = {
  metadataBase: new URL(APP_URL),
  title: {
    default: "FlashMind — Aprenda mais rápido com flashcards inteligentes",
    template: "%s · FlashMind",
  },
  description: APP_DESCRIPTION,
  keywords: [
    "flashcards",
    "repetição espaçada",
    "SM-2",
    "microlearning",
    "estudo",
    "educação",
    "IA",
    "Anki alternativo",
    "concursos",
    "vestibular",
  ],
  authors: [{ name: "FlashMind" }],
  creator: "FlashMind",
  publisher: "FlashMind",
  applicationName: APP_NAME,
  alternates: { canonical: "/" },
  openGraph: {
    type: "website",
    locale: "pt_BR",
    siteName: APP_NAME,
    url: APP_URL,
    title: "FlashMind — Flashcards Inteligentes com IA",
    description: "Aprenda qualquer coisa em 5 minutos por dia.",
  },
  twitter: {
    card: "summary_large_image",
    title: "FlashMind — Flashcards Inteligentes",
    description: "Aprenda qualquer coisa em 5 minutos por dia.",
  },
  robots: {
    index: true,
    follow: true,
    googleBot: { index: true, follow: true, "max-image-preview": "large" },
  },
  icons: {
    icon: "/bolt.png",
    apple: "/bolt.png",
  },
  category: "education",
};

export const viewport: Viewport = {
  themeColor: [
    { media: "(prefers-color-scheme: light)", color: "#ffffff" },
    { media: "(prefers-color-scheme: dark)", color: "#09090b" },
  ],
  width: "device-width",
  initialScale: 1,
};

const jsonLd = {
  "@context": "https://schema.org",
  "@type": "SoftwareApplication",
  name: APP_NAME,
  url: APP_URL,
  applicationCategory: "EducationalApplication",
  operatingSystem: "Web, Android, iOS",
  description: APP_DESCRIPTION,
  offers: [
    {
      "@type": "Offer",
      name: "Free",
      price: "0",
      priceCurrency: "BRL",
    },
    {
      "@type": "Offer",
      name: "Pro",
      price: "29",
      priceCurrency: "BRL",
    },
  ],
  aggregateRating: {
    "@type": "AggregateRating",
    ratingValue: "4.9",
    ratingCount: "128",
  },
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="pt-BR" className={inter.variable} suppressHydrationWarning>
      <body className="min-h-dvh bg-background font-sans">
        <script
          type="application/ld+json"
          dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }}
        />
        <Providers>{children}</Providers>
      </body>
    </html>
  );
}
