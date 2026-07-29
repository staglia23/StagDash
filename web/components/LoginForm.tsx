"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { createBrowserClient } from "@supabase/ssr";

// createBrowserClient guarda la sesión en COOKIES (no en localStorage): es lo que permite
// que los server components y el middleware la vean. No cambiar a createClient.
export default function LoginForm() {
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [cargando, setCargando] = useState(false);

  async function entrar(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setCargando(true);
    try {
      const supabase = createBrowserClient(
        process.env.NEXT_PUBLIC_SUPABASE_URL!,
        process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
      );
      const { error: err } = await supabase.auth.signInWithPassword({
        email: email.trim(),
        password,
      });
      if (err) {
        // Un fallo de transporte llega por esta misma vía: no culpar a la contraseña
        // por un corte de red (el texto afirmaría una causa que no consta).
        const esRed = err.name === "AuthRetryableFetchError" || !err.status || err.status >= 500;
        setError(
          esRed
            ? "Sin conexión ahora mismo — reintentá en unos minutos."
            : "No se pudo entrar. Revisá el email y la contraseña.",
        );
        setCargando(false);
        return;
      }
      router.replace("/");
      router.refresh();
      // Si la navegación rebota (fallo transitorio del middleware), la sesión igual quedó
      // creada: re-habilitar el botón para que el reintento entre, en vez de dejarlo
      // clavado en "Entrando…".
      setTimeout(() => setCargando(false), 8000);
    } catch {
      setError("Sin conexión ahora mismo — reintentá en unos minutos.");
      setCargando(false);
    }
  }

  return (
    <form className="login-form" onSubmit={entrar}>
      <label>
        Email
        <input
          className="login-input"
          type="email"
          name="email"
          autoComplete="email"
          inputMode="email"
          required
          value={email}
          onChange={(e) => setEmail(e.target.value)}
        />
      </label>
      <label>
        Contraseña
        <input
          className="login-input"
          type="password"
          name="password"
          autoComplete="current-password"
          required
          value={password}
          onChange={(e) => setPassword(e.target.value)}
        />
      </label>
      {error && (
        <p className="login-error" role="alert">
          <span aria-hidden="true">⚠️</span> {error}
        </p>
      )}
      <button className="login-btn" type="submit" disabled={cargando}>
        {cargando ? "Entrando…" : "Entrar"}
      </button>
    </form>
  );
}
