import type { Metadata } from "next";
import LoginForm from "@/components/LoginForm";

export const metadata: Metadata = {
  title: "Entrar — Stag · Dashboard Samavi",
  robots: { index: false, follow: false },
};

export default function LoginPage() {
  return (
    <main className="container login-wrap">
      <div className="card login-card">
        <h1>Stag · Dashboard Samavi</h1>
        <p className="login-sub">Acceso privado</p>
        <LoginForm />
      </div>
    </main>
  );
}
