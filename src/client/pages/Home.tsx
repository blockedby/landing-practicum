import { Hero } from "../sections/Hero";
import { Proof } from "../sections/Proof";
import { Benefits } from "../sections/Benefits";
import { Faq } from "../sections/Faq";
import { Cta } from "../sections/Cta";

export function Home() {
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
