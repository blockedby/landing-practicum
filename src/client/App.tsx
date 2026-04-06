import { Outlet } from "@tanstack/react-router";
import "./styles.css";

export function App() {
  return (
    <>
      <Outlet />
      <footer className="footer">
        <div className="container">
          &copy; {new Date().getFullYear()} FreshBox. Доставка здоровой еды.
        </div>
      </footer>
    </>
  );
}
