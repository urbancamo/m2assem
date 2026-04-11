/* CTime.c -- libc-backed time/date helpers for the m2assem gm2 port.
 *
 * gm2 15.2's bundled wraptime / SysClock libraries are broken on macOS
 * (see ports/gm2/GM2-BUGS.md bug 3): wraptime's Init* allocators all
 * return NULL because they're gated on HAVE_MALLOC_H, which is undefined
 * on macOS (libc malloc lives in <stdlib.h> there).  Any attempt to use
 * the returned NULL handles crashes with "invalid address referenced".
 *
 * This shim sidesteps both wraptime and SysClock by calling libc time
 * and localtime_r directly, and provides the gm2 module-framework
 * symbols (init/fini/dep/ctor) needed for a definition-only Modula-2
 * module — there is no CTime.mod, the procedure bodies live here.
 *
 * Naming convention follows gm2 15.2 user-module mangling on Darwin:
 *   - Procedures: <ModuleName>_<ProcName>  (gets a leading _ from the
 *     C compiler, matching what gm2 emits for module references).
 *   - Framework: _M2_<ModuleName>_{init,fini,dep,ctor}.
 */

#include <time.h>


void
CTime_GetTime (unsigned int *hours, unsigned int *minutes,
               unsigned int *seconds)
{
  time_t now = time (NULL);
  struct tm lt;

  localtime_r (&now, &lt);
  *hours   = (unsigned int) lt.tm_hour;
  *minutes = (unsigned int) lt.tm_min;
  *seconds = (unsigned int) lt.tm_sec;
}


void
CTime_GetDate (unsigned int *year, unsigned int *month, unsigned int *day)
{
  time_t now = time (NULL);
  struct tm lt;

  localtime_r (&now, &lt);
  *year  = (unsigned int) (lt.tm_year + 1900);
  *month = (unsigned int) (lt.tm_mon + 1);
  *day   = (unsigned int) lt.tm_mday;
}


/* GNU Modula-2 module framework.  Mirrors what gm2's wraptime.cc does
 * for its own definition-only module.  init/fini/dep are no-ops; ctor
 * registers the module with the runtime so init/fini get invoked at
 * the right point in the program lifecycle.
 */

extern void m2pim_M2RTS_RegisterModule (
    const char *name,
    const char *libname,
    void (*init) (int, char **, char **),
    void (*fini) (int, char **, char **),
    void (*dep) (void));


void
_M2_CTime_init (int argc, char **argv, char **env)
{
  (void) argc; (void) argv; (void) env;
}


void
_M2_CTime_fini (int argc, char **argv, char **env)
{
  (void) argc; (void) argv; (void) env;
}


void
_M2_CTime_dep (void)
{
}


void __attribute__ ((__constructor__))
_M2_CTime_ctor (void)
{
  m2pim_M2RTS_RegisterModule ("CTime", "m2pim",
                              _M2_CTime_init, _M2_CTime_fini, _M2_CTime_dep);
}
