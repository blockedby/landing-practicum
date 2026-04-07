import express from "express";
import path from "path";
import { fileURLToPath } from "url";
import pg from "pg";
import { PrismaPg } from "@prisma/adapter-pg";
import { PrismaClient } from "@prisma/client";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const app = express();

const pool = new pg.Pool({ connectionString: process.env.DATABASE_URL });
const adapter = new PrismaPg(pool);
const prisma = new PrismaClient({ adapter });

const PORT = process.env.PORT || 3000;
const TG_BOT_TOKEN = process.env.TG_BOT_TOKEN;
const TG_CHAT_ID = process.env.TG_CHAT_ID;

const STATUS_LABELS: Record<string, string> = {
  new: "Новая",
  contacted: "Связались",
  rejected: "Не актуален",
};

async function tgApi(method: string, body: Record<string, unknown>) {
  const res = await fetch(
    `https://api.telegram.org/bot${TG_BOT_TOKEN}/${method}`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
    },
  );
  if (!res.ok) {
    console.error(`Telegram ${method} error:`, res.status, await res.text());
  }
  return res;
}

async function notifyTelegram(leadId: string, name: string, contact: string) {
  if (!TG_BOT_TOKEN || !TG_CHAT_ID) return;

  const time = new Date().toLocaleString("ru-RU", { timeZone: "Europe/Moscow" });
  const text = `Новая заявка!\nИмя: ${name}\nКонтакт: ${contact}\nВремя: ${time}`;

  try {
    await tgApi("sendMessage", {
      chat_id: TG_CHAT_ID,
      text,
      reply_markup: {
        inline_keyboard: [[
          { text: "Связался", callback_data: `status:contacted:${leadId}` },
          { text: "Не актуален", callback_data: `status:rejected:${leadId}` },
        ]],
      },
    });
  } catch (err) {
    console.error("Telegram notification failed:", err);
  }
}

// ─── Telegram bot commands ──────────────────────

async function handleLeadsCommand(chatId: number, arg: string) {
  const isWeek = arg.trim() === "week";
  const where = isWeek
    ? { createdAt: { gte: new Date(Date.now() - 7 * 86400000) } }
    : {};

  const leads = await prisma.lead.findMany({
    where,
    orderBy: { createdAt: "desc" },
    ...(!isWeek && { take: 5 }),
  });

  if (leads.length === 0) {
    await tgApi("sendMessage", {
      chat_id: chatId,
      text: isWeek ? "За последнюю неделю заявок нет." : "Заявок пока нет.",
    });
    return;
  }

  const title = isWeek
    ? `Заявки за неделю (${leads.length}):`
    : `Последние ${leads.length} заявок:`;

  const lines = leads.map((l) => {
    const date = l.createdAt.toLocaleDateString("ru-RU", { timeZone: "Europe/Moscow" });
    const status = STATUS_LABELS[l.status] || l.status;
    return `• ${l.name} | ${l.contact} | ${status} | ${date}`;
  });

  await tgApi("sendMessage", {
    chat_id: chatId,
    text: `${title}\n\n${lines.join("\n")}`,
  });
}

async function handleStatsCommand(chatId: number) {
  const since = new Date(Date.now() - 7 * 86400000);

  const [views, clicks, leadsCount] = await Promise.all([
    prisma.eventLog.count({ where: { type: "landing_view", createdAt: { gte: since } } }),
    prisma.eventLog.count({ where: { type: "cta_click", createdAt: { gte: since } } }),
    prisma.lead.count({ where: { createdAt: { gte: since } } }),
  ]);

  const clickRate = views > 0 ? ((clicks / views) * 100).toFixed(1) : "—";
  const convRate = views > 0 ? ((leadsCount / views) * 100).toFixed(1) : "—";

  const text = [
    "Воронка за 7 дней:",
    "",
    `Посещений: ${views}`,
    `Кликов CTA: ${clicks} (${clickRate}%)`,
    `Заявок: ${leadsCount} (${convRate}%)`,
  ].join("\n");

  await tgApi("sendMessage", { chat_id: chatId, text });
}

// ─── Telegram polling ───────────────────────────

type TgUpdate = {
  update_id: number;
  callback_query?: {
    id: string;
    data?: string;
    message?: { chat: { id: number }; message_id: number; text?: string };
  };
  message?: {
    chat: { id: number };
    text?: string;
  };
};

async function pollTelegram() {
  if (!TG_BOT_TOKEN) return;

  let offset = 0;

  setInterval(async () => {
    try {
      const res = await fetch(
        `https://api.telegram.org/bot${TG_BOT_TOKEN}/getUpdates?offset=${offset}&timeout=0`,
      );
      const json = await res.json() as { ok: boolean; result: TgUpdate[] };
      if (!json.ok) return;

      for (const update of json.result) {
        offset = update.update_id + 1;

        // --- callback buttons ---
        const cb = update.callback_query;
        if (cb?.data) {
          const match = cb.data.match(/^status:(contacted|rejected):(.+)$/);
          if (match) {
            const [, newStatus, leadId] = match;
            try {
              await prisma.lead.update({
                where: { id: leadId },
                data: { status: newStatus as "contacted" | "rejected" },
              });

              const label = STATUS_LABELS[newStatus] || newStatus;
              const originalText = cb.message?.text || "";

              await tgApi("editMessageText", {
                chat_id: cb.message?.chat.id,
                message_id: cb.message?.message_id,
                text: `${originalText}\n\nСтатус: ${label}`,
              });
            } catch (err) {
              console.error("Callback processing error:", err);
            }
          }
          await tgApi("answerCallbackQuery", { callback_query_id: cb.id });
          continue;
        }

        // --- text commands ---
        const msg = update.message;
        if (!msg?.text) continue;
        const text = msg.text.trim();

        try {
          if (text === "/leads" || text.startsWith("/leads ")) {
            const arg = text.slice("/leads".length);
            await handleLeadsCommand(msg.chat.id, arg);
          } else if (text === "/stats") {
            await handleStatsCommand(msg.chat.id);
          }
        } catch (err) {
          console.error("Command error:", err);
        }
      }
    } catch (err) {
      console.error("Telegram polling error:", err);
    }
  }, 3000);
}

pollTelegram();

app.use(express.json());

// ─── Health ─────────────────────────────────────

app.get("/api/health", async (_req, res) => {
  try {
    await prisma.$queryRaw`SELECT 1`;
    res.json({ status: "ok", db: "connected" });
  } catch {
    res.status(500).json({ status: "error", db: "disconnected" });
  }
});

// ─── Submit lead ────────────────────────────────

const NAME_RE = /^[A-Za-zА-Яа-яЁё\s-]{2,100}$/;
const PHONE_RE = /^\d{11}$/;
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

app.post("/api/leads", async (req, res) => {
  try {
    const { name, contact, consent, fingerprint } = req.body;

    // --- validation ---
    if (!name || typeof name !== "string" || !NAME_RE.test(name.trim())) {
      res.status(400).json({ error: "Некорректное имя (2–100 букв)" });
      return;
    }

    const cleanContact = typeof contact === "string" ? contact.replace(/\D/g, "") : "";
    const isPhone = PHONE_RE.test(cleanContact);
    const isEmail = typeof contact === "string" && EMAIL_RE.test(contact.trim());
    if (!isPhone && !isEmail) {
      res.status(400).json({ error: "Укажите корректный телефон или email" });
      return;
    }

    if (consent !== true) {
      res.status(400).json({ error: "Необходимо согласие на обработку данных" });
      return;
    }

    const contactValue = isPhone ? cleanContact : contact.trim();

    // --- visitor (optional) ---
    let visitorId: string | undefined;
    if (fingerprint && typeof fingerprint === "string") {
      const ip = req.headers["x-forwarded-for"]?.toString().split(",")[0]?.trim()
        || req.socket.remoteAddress
        || "unknown";
      const userAgent = req.headers["user-agent"] || "unknown";

      const visitor = await prisma.visitor.upsert({
        where: { fingerprint },
        update: {},
        create: { fingerprint, ip, userAgent },
      });
      visitorId = visitor.id;
    }

    // --- check duplicate ---
    const existing = await prisma.lead.findUnique({
      where: { contact: contactValue },
    });
    if (existing) {
      res.status(409).json({ error: "Заявка с таким контактом уже существует" });
      return;
    }

    // --- create lead ---
    const lead = await prisma.lead.create({
      data: {
        name: name.trim(),
        contact: contactValue,
        consent,
        visitorId,
      },
    });

    // --- log event ---
    await prisma.eventLog.create({
      data: {
        type: "lead_created",
        source: "internal",
        idempotencyKey: `lead_created:${lead.id}`,
        visitorId,
        leadId: lead.id,
        data: { leadId: lead.id },
      },
    });

    // --- telegram (fire & forget) ---
    notifyTelegram(lead.id, lead.name, lead.contact);

    res.status(201).json({ ok: true, id: lead.id });
  } catch (err) {
    console.error("POST /api/leads error:", err);
    res.status(500).json({ error: "Внутренняя ошибка сервера" });
  }
});

// ─── Track event ────────────────────────────────

const ALLOWED_EVENTS = new Set(["landing_view", "cta_click"]);

app.post("/api/events", async (req, res) => {
  try {
    const { type, fingerprint, data } = req.body;

    if (!type || typeof type !== "string" || !ALLOWED_EVENTS.has(type)) {
      res.status(400).json({ error: "Неизвестный тип события" });
      return;
    }

    let visitorId: string | undefined;
    if (fingerprint && typeof fingerprint === "string") {
      const ip = req.headers["x-forwarded-for"]?.toString().split(",")[0]?.trim()
        || req.socket.remoteAddress
        || "unknown";
      const userAgent = req.headers["user-agent"] || "unknown";

      const visitor = await prisma.visitor.upsert({
        where: { fingerprint },
        update: {},
        create: { fingerprint, ip, userAgent },
      });
      visitorId = visitor.id;
    }

    await prisma.eventLog.create({
      data: {
        type,
        source: "internal",
        visitorId,
        data: data ?? {},
      },
    });

    res.json({ ok: true });
  } catch (err) {
    console.error("POST /api/events error:", err);
    res.status(500).json({ error: "Внутренняя ошибка сервера" });
  }
});

// ─── Webhook inbox ──────────────────────────────

const WEBHOOK_SECRET = process.env.WEBHOOK_SECRET;

app.post("/api/webhook", async (req, res) => {
  try {
    if (!WEBHOOK_SECRET || req.headers["x-webhook-secret"] !== WEBHOOK_SECRET) {
      res.status(401).json({ error: "Unauthorized" });
      return;
    }

    const { type, data, idempotencyKey } = req.body;

    if (!type || typeof type !== "string") {
      res.status(400).json({ error: "Поле type обязательно" });
      return;
    }

    if (!idempotencyKey || typeof idempotencyKey !== "string") {
      res.status(400).json({ error: "Поле idempotencyKey обязательно" });
      return;
    }

    const existing = await prisma.eventLog.findUnique({
      where: { idempotencyKey },
    });
    if (existing) {
      res.json({ ok: true, duplicate: true });
      return;
    }

    await prisma.eventLog.create({
      data: {
        type,
        source: "external",
        idempotencyKey,
        data: data ?? {},
      },
    });

    res.status(201).json({ ok: true });
  } catch (err) {
    console.error("POST /api/webhook error:", err);
    res.status(500).json({ error: "Внутренняя ошибка сервера" });
  }
});

// ─── Static & SPA fallback ──────────────────────

app.use(express.static(path.join(__dirname, "../client")));

app.get("{*path}", (_req, res) => {
  res.sendFile(path.join(__dirname, "../client/index.html"));
});

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
