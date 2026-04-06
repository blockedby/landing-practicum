import { Outlet } from "@tanstack/react-router";

export function App() {
  return (
    <div
      style={{
        minHeight: "100vh",
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        justifyContent: "center",
        fontFamily: "system-ui, sans-serif",
        background: "#0f172a",
        color: "#e2e8f0",
      }}
    >
      <h1 style={{ fontSize: "3rem", marginBottom: "0.5rem" }}>
        Landing
      </h1>
      <p style={{ fontSize: "1.25rem", color: "#94a3b8" }}>
        Добро пожаловать!
      </p>
      <Outlet />
    </div>
  );
}
