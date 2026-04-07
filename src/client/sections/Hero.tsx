import { trackEvent } from "../tracking";

export function Hero() {
  const handleClick = () => {
    trackEvent("cta_click", { action: "hero_button" });
    document.querySelector(".cta")?.scrollIntoView({ behavior: "smooth" });
  };

  return (
    <section className="hero">
      <div className="container">
        <span className="hero__badge">FreshBox — доставка здоровой еды</span>
        <h1 className="hero__title">
          Здоровая еда с доставкой
          <br />
          за 30 минут
        </h1>
        <p className="hero__subtitle">
          Свежие блюда из натуральных продуктов, собранные под ваши цели и вкусы.
          Без подписки, без обязательств.
        </p>
        <button className="btn" type="button" onClick={handleClick}>
          Попробовать бесплатно
        </button>
      </div>
    </section>
  );
}
