export function getFingerprint(): string {
  const { userAgent, language, hardwareConcurrency } = navigator;
  const screen = `${window.screen.width}x${window.screen.height}`;
  const tz = Intl.DateTimeFormat().resolvedOptions().timeZone;
  const raw = [userAgent, language, screen, tz, hardwareConcurrency].join("|");
  let hash = 0;
  for (let i = 0; i < raw.length; i++) {
    hash = (hash * 31 + raw.charCodeAt(i)) | 0;
  }
  return Math.abs(hash).toString(36);
}

export function trackEvent(
  type: string,
  payload: Record<string, unknown> = {},
) {
  const body = JSON.stringify({
    type,
    fingerprint: getFingerprint(),
    data: payload,
  });

  if (navigator.sendBeacon) {
    navigator.sendBeacon(
      "/api/events",
      new Blob([body], { type: "application/json" }),
    );
  } else {
    fetch("/api/events", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body,
      keepalive: true,
    }).catch(() => {});
  }
}
