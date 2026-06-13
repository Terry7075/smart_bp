int calculatePrice(num distanceKm) {
  if (distanceKm <= 5) return 20;
  if (distanceKm <= 10) return 50;
  return 100;
}
