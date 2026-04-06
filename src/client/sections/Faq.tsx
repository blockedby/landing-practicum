import { useState } from "react";

const questions = [
  {
    q: "Как сделать заказ?",
    a: "Оставьте заявку на сайте или напишите в Telegram. Мы перезвоним, уточним предпочтения и доставим первый заказ в удобное время.",
  },
  {
    q: "В какие районы вы доставляете?",
    a: "Доставляем по всей Москве внутри МКАД. За МКАД — в радиусе 10 км. Зоны расширяем каждый месяц.",
  },
  {
    q: "Учитываете ли вы аллергии?",
    a: "Да, при оформлении заказа укажите аллергены — мы исключим их из вашего меню. Также есть безглютеновые и безлактозные варианты.",
  },
  {
    q: "Можно ли отменить заказ?",
    a: "Да, заказ можно отменить бесплатно за 3 часа до доставки. Позже — вернём 50% стоимости.",
  },
];

export function Faq() {
  const [openIndex, setOpenIndex] = useState<number | null>(null);

  const toggle = (i: number) => {
    setOpenIndex(openIndex === i ? null : i);
  };

  return (
    <section className="faq">
      <div className="container">
        <h2 className="section-title">Частые вопросы</h2>
        <p className="section-subtitle">
          Не нашли ответ? Напишите нам — ответим за 5 минут
        </p>
        <div className="faq__list">
          {questions.map((item, i) => (
            <div key={i} className="faq-item">
              <button
                className="faq-item__question"
                type="button"
                onClick={() => toggle(i)}
              >
                {item.q}
                <span
                  className={`faq-item__chevron${openIndex === i ? " faq-item__chevron--open" : ""}`}
                >
                  ▾
                </span>
              </button>
              {openIndex === i && (
                <div className="faq-item__answer">{item.a}</div>
              )}
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
