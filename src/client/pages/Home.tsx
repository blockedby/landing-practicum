import { useEffect } from "react";
import { Hero } from "../sections/Hero";
import { Proof } from "../sections/Proof";
import { Benefits } from "../sections/Benefits";
import { Faq } from "../sections/Faq";
import { Cta } from "../sections/Cta";
import { trackEvent } from "../tracking";

export function Home() {
  useEffect(() => {
    trackEvent("landing_view", {
      url: window.location.href,
      referrer: document.referrer || null,
    });
  }, []);

  return (
    <>
      <Hero />
      <Proof />
      <Benefits />
      <Faq />
      <Cta />
    </>
  );
}
