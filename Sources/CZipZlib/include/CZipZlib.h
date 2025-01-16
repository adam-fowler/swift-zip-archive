#ifndef C_COMPRESS_ZLIB_H
#define C_COMPRESS_ZLIB_H

#include <zlib.h>

static inline int CZipZlib_deflateInit2(z_streamp strm,
                                              int level,
                                              int method,
                                              int windowBits,
                                              int memLevel,
                                              int strategy) {
    return deflateInit2(strm, level, method, windowBits, memLevel, strategy);
}

static inline int CZipZlib_inflateInit2(z_streamp strm, int windowBits) {
    return inflateInit2(strm, windowBits);
}

static inline Bytef *CZipZlib_voidPtr_to_BytefPtr(void *in) {
    return (Bytef *)in;
}

#endif
