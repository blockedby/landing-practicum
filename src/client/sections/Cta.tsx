import { type FormEvent, useState, useEffect, useRef } from "react";
import { getFingerprint, trackEvent } from "../tracking";

function formatPhone(raw: string): string {
  const digits = raw.replace(/\D/g, "").slice(0, 11);
  if (!digits) return "";

  let result = "+7";
  if (digits.length > 1) result += " (" + digits.slice(1, 4);
  if (digits.length > 4) result += ") " + digits.slice(4, 7);
  if (digits.length > 7) result += "-" + digits.slice(7, 9);
  if (digits.length > 9) result += "-" + digits.slice(9, 11);
  return result;
}

const NAME_RE = /^[A-Za-zА-Яа-яЁё\s-]{2,}$/;
const PHONE_DIGITS = 11;

interface Errors {
  name?: string;
  phone?: string;
  agreed?: string;
}

export function Cta() {
  const [name, setName] = useState("");
  const [phone, setPhone] = useState("");
  const [agreed, setAgreed] = useState(false);
  const [errors, setErrors] = useState<Errors>({});
  const [submitted, setSubmitted] = useState(false);
  const [loading, setLoading] = useState(false);
  const [serverError, setServerError] = useState("");
  const sectionRef = useRef<HTMLElement>(null);
  const scrollTracked = useRef(false);

  useEffect(() => {
    const el = sectionRef.current;
    if (!el) return;

    const observer = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting && !scrollTracked.current) {
          scrollTracked.current = true;
          trackEvent("cta_click", { action: "scroll_to_form" });
          observer.disconnect();
        }
      },
      { threshold: 0.5 },
    );
    observer.observe(el);
    return () => observer.disconnect();
  }, []);

  function validate(): Errors {
    const e: Errors = {};
    if (!name.trim()) {
      e.name = "Введите имя";
    } else if (!NAME_RE.test(name.trim())) {
      e.name = "Имя может содержать только буквы, пробелы и дефис";
    }

    const digits = phone.replace(/\D/g, "");
    if (!digits) {
      e.phone = "Введите номер телефона";
    } else if (digits.length < PHONE_DIGITS) {
      e.phone = "Номер телефона должен содержать 11 цифр";
    }

    if (!agreed) {
      e.agreed = "Необходимо дать согласие на обработку данных";
    }
    return e;
  }

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    setServerError("");

    const errs = validate();
    setErrors(errs);
    if (Object.keys(errs).length > 0) return;

    setLoading(true);
    try {
      const res = await fetch("/api/leads", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          name: name.trim(),
          contact: phone,
          consent: agreed,
          fingerprint: getFingerprint(),
        }),
      });

      const data = await res.json();

      if (!res.ok) {
        setServerError(data.error || "Что-то пошло не так");
        return;
      }

      setSubmitted(true);
    } catch {
      setServerError("Не удалось отправить заявку. Проверьте соединение.");
    } finally {
      setLoading(false);
    }
  };

  if (submitted) {
    return (
      <section className="cta">
        <div className="container">
          <div className="cta__inner">
            <h2 className="section-title">Спасибо!</h2>
            <p className="section-subtitle">
              Мы свяжемся с вами в ближайшее время
            </p>
          </div>
        </div>
      </section>
    );
  }

  return (
    <section className="cta" ref={sectionRef}>
      <div className="container">
        <div className="cta__inner">
          <h2 className="section-title">Попробуйте первый заказ бесплатно</h2>
          <p className="section-subtitle">
            Оставьте заявку — перезвоним за 5 минут и подберём меню
          </p>
          {serverError && (
            <div className="server-error">{serverError}</div>
          )}
          <form className="cta__form" onSubmit={handleSubmit} noValidate>
            <div>
              <input
                className={`input${errors.name ? " input--error" : ""}`}
                type="text"
                name="name"
                placeholder="Ваше имя"
                value={name}
                onChange={(e) => {
                  setName(e.target.value);
                  if (errors.name) setErrors((p) => ({ ...p, name: undefined }));
                }}
              />
              {errors.name && <span className="field-error">{errors.name}</span>}
            </div>
            <div>
              <input
                className={`input${errors.phone ? " input--error" : ""}`}
                type="tel"
                name="phone"
                placeholder="+7 (___) ___-__-__"
                value={phone}
                onChange={(e) => {
                  setPhone(formatPhone(e.target.value));
                  if (errors.phone) setErrors((p) => ({ ...p, phone: undefined }));
                }}
              />
              {errors.phone && <span className="field-error">{errors.phone}</span>}
            </div>
            <div>
              <label className={`checkbox-label${errors.agreed ? " checkbox-label--error" : ""}`}>
                <input
                  type="checkbox"
                  checked={agreed}
                  onChange={(e) => {
                    setAgreed(e.target.checked);
                    if (errors.agreed) setErrors((p) => ({ ...p, agreed: undefined }));
                  }}
                />
                Я согласен на обработку персональных данных
              </label>
              {errors.agreed && <span className="field-error">{errors.agreed}</span>}
            </div>
            <button className="btn" type="submit" disabled={loading}>
              {loading ? "Отправка..." : "Оставить заявку"}
            </button>
          </form>
        </div>
      </div>
    </section>
  );
}
