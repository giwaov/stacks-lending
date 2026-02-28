import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Stacks Token Swap",
  description: "Decentralized token swap on Stacks blockchain",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
