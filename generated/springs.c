/* Generated from o7ir.kernels; SI magnitudes, explicit domain checks. */
#include <math.h>
#include <stddef.h>

double spring_force(double k, double x) {
  if (!isfinite(k) || k <= 0.0) return NAN;
  if (!isfinite(x) || x < 0.0) return NAN;
  double t0 = k;
  double t1 = x;
  double t2 = t0 * t1;
  return isfinite(t2) ? t2 : NAN;
}

void spring_force_batch(size_t n, const double *a, const double *b, double *out) {
  for (size_t i = 0; i < n; ++i) out[i] = spring_force(a[i], b[i]);
}

double spring_extension(double f, double k) {
  if (!isfinite(f) || f < 0.0) return NAN;
  if (!isfinite(k) || k <= 0.0) return NAN;
  double t0 = f;
  double t1 = k;
  double t2 = t0 / t1;
  return isfinite(t2) ? t2 : NAN;
}

void spring_extension_batch(size_t n, const double *a, const double *b, double *out) {
  for (size_t i = 0; i < n; ++i) out[i] = spring_extension(a[i], b[i]);
}

double spring_stiffness(double f, double x) {
  if (!isfinite(f) || f < 0.0) return NAN;
  if (!isfinite(x) || x <= 0.0) return NAN;
  double t0 = f;
  double t1 = x;
  double t2 = t0 / t1;
  return isfinite(t2) ? t2 : NAN;
}

void spring_stiffness_batch(size_t n, const double *a, const double *b, double *out) {
  for (size_t i = 0; i < n; ++i) out[i] = spring_stiffness(a[i], b[i]);
}

double spring_energy(double k, double x) {
  if (!isfinite(k) || k <= 0.0) return NAN;
  if (!isfinite(x) || x < 0.0) return NAN;
  double t0 = 0x1.0000000000000p-1;
  double t1 = k;
  double t2 = t0 * t1;
  double t3 = x;
  double t4 = t2 * t3;
  double t5 = t4 * t3;
  return isfinite(t5) ? t5 : NAN;
}

void spring_energy_batch(size_t n, const double *a, const double *b, double *out) {
  for (size_t i = 0; i < n; ++i) out[i] = spring_energy(a[i], b[i]);
}

double spring_period(double m, double k) {
  if (!isfinite(m) || m <= 0.0) return NAN;
  if (!isfinite(k) || k <= 0.0) return NAN;
  double t0 = 0x1.0000000000000p+1;
  double t1 = 0x1.921fb54442d18p+1;
  double t2 = t0 * t1;
  double t3 = m;
  double t4 = k;
  double t5 = t3 / t4;
  double t6 = sqrt(t5);
  double t7 = t2 * t6;
  return isfinite(t7) ? t7 : NAN;
}

void spring_period_batch(size_t n, const double *a, const double *b, double *out) {
  for (size_t i = 0; i < n; ++i) out[i] = spring_period(a[i], b[i]);
}

double spring_frequency(double m, double k) {
  if (!isfinite(m) || m <= 0.0) return NAN;
  if (!isfinite(k) || k <= 0.0) return NAN;
  double t0 = 0x1.0000000000000p+0;
  double t1 = 0x1.0000000000000p+1;
  double t2 = 0x1.921fb54442d18p+1;
  double t3 = t1 * t2;
  double t4 = m;
  double t5 = k;
  double t6 = t4 / t5;
  double t7 = sqrt(t6);
  double t8 = t3 * t7;
  double t9 = t0 / t8;
  return isfinite(t9) ? t9 : NAN;
}

void spring_frequency_batch(size_t n, const double *a, const double *b, double *out) {
  for (size_t i = 0; i < n; ++i) out[i] = spring_frequency(a[i], b[i]);
}

