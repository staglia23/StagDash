"use client";

import { useState, type ReactNode } from "react";

export type TabItem = { label: string; content: ReactNode };

export function Tabs({ items }: { items: TabItem[] }) {
  const [activo, setActivo] = useState(0);
  return (
    <div>
      <div className="tabs" role="tablist">
        {items.map((t, i) => (
          <button
            key={t.label}
            role="tab"
            aria-selected={i === activo}
            className={"tab" + (i === activo ? " active" : "")}
            onClick={() => setActivo(i)}
          >
            {t.label}
          </button>
        ))}
      </div>
      <div role="tabpanel">{items[activo]?.content}</div>
    </div>
  );
}
