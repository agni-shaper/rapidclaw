import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Tasks · Kanban",
  description: "Sqlite-backed Kanban board for the coach tasks system",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className="dark">
      <body className="bg-slate-950 text-slate-100 antialiased">{children}</body>
    </html>
  );
}
