import type { Metadata } from "next";
import { RegisterForm } from "@/components/auth/register-form";

export const metadata: Metadata = {
  title: "Criar conta",
  description: "Crie sua conta FlashMind grátis.",
};

export default function RegisterPage() {
  return <RegisterForm />;
}
