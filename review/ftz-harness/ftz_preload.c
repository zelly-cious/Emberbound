/* LD_PRELOAD helper: switch the main thread to flush-to-zero (FTZ on, DAZ off) before main() runs. */
#include <xmmintrin.h>
__attribute__((constructor)) static void enable_ftz(void) { _MM_SET_FLUSH_ZERO_MODE(_MM_FLUSH_ZERO_ON); }
