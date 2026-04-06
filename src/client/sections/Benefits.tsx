const items = [
  {
    icon: "⚡",
    title: "Быстрая доставка",
    text: "Привезём горячий обед за 30 минут или вернём деньги. Работаем без задержек.",
  },
  {
    icon: "🥬",
    title: "Свежие продукты",
    text: "Закупаем продукты каждое утро у проверенных фермеров. Никаких заморозок.",
  },
  {
    icon: "🎯",
    title: "Персональное меню",
    text: "Подберём рацион под ваши цели: похудение, набор массы или поддержание формы.",
  },
  {
    icon: "✨",
    title: "Без подписки",
    text: "Заказывайте когда удобно. Никаких обязательств, отменить можно в любой момент.",
  },
];

export function Benefits() {
  return (
    <section className="benefits">
      <div className="container">
        <h2 className="section-title">Почему выбирают нас</h2>
        <p className="section-subtitle">
          Всё, чтобы питаться правильно без лишних усилий
        </p>
        <div className="benefits__grid">
          {items.map((item) => (
            <div key={item.title} className="benefit-card">
              <div className="benefit-card__icon">{item.icon}</div>
              <h3 className="benefit-card__title">{item.title}</h3>
              <p className="benefit-card__text">{item.text}</p>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
