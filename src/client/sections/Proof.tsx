const partners = ["FoodTech", "VitaLab", "GreenCo", "NutriPro"];

export function Proof() {
  return (
    <section className="proof">
      <div className="container">
        <div className="proof__inner">
          <span className="proof__stat">10 000+ доставок</span>
          {partners.map((name) => (
            <div key={name} className="proof__logo">
              {name}
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
