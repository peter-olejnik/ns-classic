/*
 * LD_PRELOAD fix for Valve's HLTV demo recording crash.
 *
 * HLTV's proxy.so copies the 7-byte string "HLDEMO" (with its NUL) into the
 * 6-byte szFileStamp field of the demo header (DemoFile::StartRecording,
 * DemoFile.cpp:313). The extra byte lands in struct padding, which is
 * harmless, but the binary is built with _FORTIFY_SOURCE, so glibc aborts
 * with "*** buffer overflow detected ***" whenever a demo starts recording.
 *
 * This library allows exactly that one copy and passes every other checked
 * copy to glibc unchanged. Built 32-bit by hosting/Dockerfile and loaded only
 * for hltv (scripts/entry.sh).
 */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <string.h>

typedef void *(*memcpy_chk_fn)(void *, const void *, size_t, size_t);
typedef char *(*strcpy_chk_fn)(char *, const char *, size_t);

static int is_demo_stamp(const void *src, size_t len, size_t destlen)
{
    return destlen == 6 && len == 7 && memcmp(src, "HLDEMO", 7) == 0;
}

void *__memcpy_chk(void *dest, const void *src, size_t len, size_t destlen)
{
    static memcpy_chk_fn real;
    if (is_demo_stamp(src, len, destlen))
        return memcpy(dest, src, len);
    if (!real)
        real = (memcpy_chk_fn)dlsym(RTLD_NEXT, "__memcpy_chk");
    return real(dest, src, len, destlen);
}

char *__strcpy_chk(char *dest, const char *src, size_t destlen)
{
    static strcpy_chk_fn real;
    if (is_demo_stamp(src, strlen(src) + 1, destlen))
        return memcpy(dest, src, 7);
    if (!real)
        real = (strcpy_chk_fn)dlsym(RTLD_NEXT, "__strcpy_chk");
    return real(dest, src, destlen);
}
