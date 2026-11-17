#include "sehtag_instr.h"

uintptr_t allocate_one_object(void)
{
    return sehtag_halloc_const(32, 1);
}

