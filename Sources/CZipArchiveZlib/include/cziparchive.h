#ifndef C_ZIPARCHIVE_ZLIB_H
#define C_ZIPARCHIVE_ZLIB_H

#include "ziparchive-zlib.h"

static inline int CZipArchiveZlib_deflateInit2(cziparchive_z_streamp strm, int level, int method,
                                        int windowBits, int memLevel,
                                        int strategy) {
  return deflateInit2(strm, level, method, windowBits, memLevel, strategy);
}

static inline int CZipArchiveZlib_inflateInit2(cziparchive_z_streamp strm, int windowBits) {
  return inflateInit2(strm, windowBits);
}

static inline Bytef *CZipArchiveZlib_voidPtr_to_BytefPtr(void *in) {
  return (Bytef *)in;
}

#endif // C_ZIPARCHIVE_ZLIB_H
