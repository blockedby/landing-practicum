export function Hero() {
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
        <button className="btn" type="button">
          Попробовать бесплатно
        </button>
      </div>
    </section>
  );
}
