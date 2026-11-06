/* Reproduces BigNum's failing step in plain C doubles, the same operations the Luau VM performs. */
#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <xmmintrin.h>
#include <pmmintrin.h>

static void run(const char *label) {
    volatile double tiny = 5e-324;
    /* toScientific(5e-324): divideByPowerOfTen(m, -324) = m * 1e300 / 10^(-24) */
    volatile double mant = tiny * 1e300 / pow(10.0, -24.0);
    /* tryNormalize -> multiplyByPowerOfTen(m, -324) = m * 10^(power + 300) * 1e-300 */
    volatile double step = mant * pow(10.0, -24.0);
    volatile double value = step * 1e-300;
    char buf[64];
    snprintf(buf, sizeof buf, "%.17ge%d", mant, -324);
    double parsed = strtod(buf, NULL);
    printf("%-26s mantissa=%.17g  m*10^-24=%.17g  *1e-300=%.17g  bits_equal_tiny=%d  strtod(\"%s\")=%.17g  parsed==tiny=%d  half_min_normal=%.17g\n",
           label, mant, step, value, value == tiny, buf, parsed, parsed == tiny, 2.2250738585072014e-308 / 2);
}

int main(void) {
    run("gradual (default)");
    _MM_SET_FLUSH_ZERO_MODE(_MM_FLUSH_ZERO_ON);
    run("FTZ on, DAZ off");
    _MM_SET_DENORMALS_ZERO_MODE(_MM_DENORMALS_ZERO_ON);
    run("FTZ on, DAZ on (extra)");
    return 0;
}
