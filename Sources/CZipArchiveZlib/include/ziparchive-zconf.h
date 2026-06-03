/* zconf.h -- configuration of the zlib compression library
 * Copyright (C) 1995-2026 Jean-loup Gailly, Mark Adler
 * For conditions of distribution and use, see copyright notice in zlib.h
 */

/* @(#) $Id$ */

#ifndef ZIPARCHIVE_ZCONF_H
#define ZIPARCHIVE_ZCONF_H

/*
 * If you *really* need a unique prefix for all types and library functions,
 * compile with -DZ_PREFIX. The "standard" zlib should be compiled without it.
 * Even better than compiling with -DZ_PREFIX would be to use configure to set
 * this permanently in zconf.h using "./configure --zprefix".
 */
#if 1 /* CZIPARCHIVE_Z_PREFIX - cziparchive_z_ */
#  define CZIPARCHIVE_Z_PREFIX_SET

/* all linked symbols and init macros */
#  define _dist_code            cziparchive_z__dist_code
#  define _length_code          cziparchive_z__length_code
#  define _tr_align             cziparchive_z__tr_align
#  define _tr_flush_bits        cziparchive_z__tr_flush_bits
#  define _tr_flush_block       cziparchive_z__tr_flush_block
#  define _tr_init              cziparchive_z__tr_init
#  define _tr_stored_block      cziparchive_z__tr_stored_block
#  define _tr_tally             cziparchive_z__tr_tally
#  define adler32               cziparchive_z_adler32
#  define adler32_combine       cziparchive_z_adler32_combine
#  define adler32_combine64     cziparchive_z_adler32_combine64
#  define adler32_z             cziparchive_z_adler32_z
#  ifndef CZIPARCHIVE_Z_SOLO
#    define compress              cziparchive_z_compress
#    define compress2             cziparchive_z_compress2
#    define compress_z            cziparchive_z_compress_z
#    define compress2_z           cziparchive_z_compress2_z
#    define compressBound         cziparchive_z_compressBound
#    define compressBound_z       cziparchive_z_compressBound_z
#  endif
#  define crc32                 cziparchive_z_crc32
#  define crc32_combine         cziparchive_z_crc32_combine
#  define crc32_combine64       cziparchive_z_crc32_combine64
#  define crc32_combine_gen     cziparchive_z_crc32_combine_gen
#  define crc32_combine_gen64   cziparchive_z_crc32_combine_gen64
#  define crc32_combine_op      cziparchive_z_crc32_combine_op
#  define crc32_z               cziparchive_z_crc32_z
#  define deflate               cziparchive_z_deflate
#  define deflateBound          cziparchive_z_deflateBound
#  define deflateBound_z        cziparchive_z_deflateBound_z
#  define deflateCopy           cziparchive_z_deflateCopy
#  define deflateEnd            cziparchive_z_deflateEnd
#  define deflateGetDictionary  cziparchive_z_deflateGetDictionary
#  define deflateInit           cziparchive_z_deflateInit
#  define deflateInit2          cziparchive_z_deflateInit2
#  define deflateInit2_         cziparchive_z_deflateInit2_
#  define deflateInit_          cziparchive_z_deflateInit_
#  define deflateParams         cziparchive_z_deflateParams
#  define deflatePending        cziparchive_z_deflatePending
#  define deflatePrime          cziparchive_z_deflatePrime
#  define deflateReset          cziparchive_z_deflateReset
#  define deflateResetKeep      cziparchive_z_deflateResetKeep
#  define deflateSetDictionary  cziparchive_z_deflateSetDictionary
#  define deflateSetHeader      cziparchive_z_deflateSetHeader
#  define deflateTune           cziparchive_z_deflateTune
#  define deflateUsed           cziparchive_z_deflateUsed
#  define deflate_copyright     cziparchive_z_deflate_copyright
#  define get_crc_table         cziparchive_z_get_crc_table
#  ifndef CZIPARCHIVE_Z_SOLO
#    define gz_error              cziparchive_z_gz_error
#    define gz_intmax             cziparchive_z_gz_intmax
#    define gz_strwinerror        cziparchive_z_gz_strwinerror
#    define gzbuffer              cziparchive_z_gzbuffer
#    define gzclearerr            cziparchive_z_gzclearerr
#    define gzclose               cziparchive_z_gzclose
#    define gzclose_r             cziparchive_z_gzclose_r
#    define gzclose_w             cziparchive_z_gzclose_w
#    define gzdirect              cziparchive_z_gzdirect
#    define gzdopen               cziparchive_z_gzdopen
#    define gzeof                 cziparchive_z_gzeof
#    define gzerror               cziparchive_z_gzerror
#    define gzflush               cziparchive_z_gzflush
#    define gzfread               cziparchive_z_gzfread
#    define gzfwrite              cziparchive_z_gzfwrite
#    define gzgetc                cziparchive_z_gzgetc
#    define gzgetc_               cziparchive_z_gzgetc_
#    define gzgets                cziparchive_z_gzgets
#    define gzoffset              cziparchive_z_gzoffset
#    define gzoffset64            cziparchive_z_gzoffset64
#    define gzopen                cziparchive_z_gzopen
#    define gzopen64              cziparchive_z_gzopen64
#    ifdef _WIN32
#      define gzopen_w              cziparchive_z_gzopen_w
#    endif
#    define gzprintf              cziparchive_z_gzprintf
#    define gzputc                cziparchive_z_gzputc
#    define gzputs                cziparchive_z_gzputs
#    define gzread                cziparchive_z_gzread
#    define gzrewind              cziparchive_z_gzrewind
#    define gzseek                cziparchive_z_gzseek
#    define gzseek64              cziparchive_z_gzseek64
#    define gzsetparams           cziparchive_z_gzsetparams
#    define gztell                cziparchive_z_gztell
#    define gztell64              cziparchive_z_gztell64
#    define gzungetc              cziparchive_z_gzungetc
#    define gzvprintf             cziparchive_z_gzvprintf
#    define gzwrite               cziparchive_z_gzwrite
#  endif
#  define inflate               cziparchive_z_inflate
#  define inflateBack           cziparchive_z_inflateBack
#  define inflateBackEnd        cziparchive_z_inflateBackEnd
#  define inflateBackInit       cziparchive_z_inflateBackInit
#  define inflateBackInit_      cziparchive_z_inflateBackInit_
#  define inflateCodesUsed      cziparchive_z_inflateCodesUsed
#  define inflateCopy           cziparchive_z_inflateCopy
#  define inflateEnd            cziparchive_z_inflateEnd
#  define inflateGetDictionary  cziparchive_z_inflateGetDictionary
#  define inflateGetHeader      cziparchive_z_inflateGetHeader
#  define inflateInit           cziparchive_z_inflateInit
#  define inflateInit2          cziparchive_z_inflateInit2
#  define inflateInit2_         cziparchive_z_inflateInit2_
#  define inflateInit_          cziparchive_z_inflateInit_
#  define inflateMark           cziparchive_z_inflateMark
#  define inflatePrime          cziparchive_z_inflatePrime
#  define inflateReset          cziparchive_z_inflateReset
#  define inflateReset2         cziparchive_z_inflateReset2
#  define inflateResetKeep      cziparchive_z_inflateResetKeep
#  define inflateSetDictionary  cziparchive_z_inflateSetDictionary
#  define inflateSync           cziparchive_z_inflateSync
#  define inflateSyncPoint      cziparchive_z_inflateSyncPoint
#  define inflateUndermine      cziparchive_z_inflateUndermine
#  define inflateValidate       cziparchive_z_inflateValidate
#  define inflate_copyright     cziparchive_z_inflate_copyright
#  define inflate_fast          cziparchive_z_inflate_fast
#  define inflate_table         cziparchive_z_inflate_table
#  define inflate_fixed         cziparchive_z_inflate_fixed
#  ifndef CZIPARCHIVE_Z_SOLO
#    define uncompress            cziparchive_z_uncompress
#    define uncompress2           cziparchive_z_uncompress2
#    define uncompress_z          cziparchive_z_uncompress_z
#    define uncompress2_z         cziparchive_z_uncompress2_z
#  endif
#  define zError                cziparchive_z_zError
#  ifndef CZIPARCHIVE_Z_SOLO
#    define zcalloc               cziparchive_z_zcalloc
#    define zcfree                cziparchive_z_zcfree
#  endif
#  define zlibCompileFlags      cziparchive_z_zlibCompileFlags
#  define zlibVersion           cziparchive_z_zlibVersion

/* all zlib typedefs in zlib.h and zconf.h */
#  define Byte                  cziparchive_z_Byte
#  define Bytef                 cziparchive_z_Bytef
#  define alloc_func            cziparchive_z_alloc_func
#  define charf                 cziparchive_z_charf
#  define free_func             cziparchive_z_free_func
#  ifndef CZIPARCHIVE_Z_SOLO
#    define gzFile                cziparchive_z_gzFile
#  endif
#  define gz_header             cziparchive_z_gz_header
#  define gz_headerp            cziparchive_z_gz_headerp
#  define in_func               cziparchive_z_in_func
#  define intf                  cziparchive_z_intf
#  define out_func              cziparchive_z_out_func
#  define uInt                  cziparchive_z_uInt
#  define uIntf                 cziparchive_z_uIntf
#  define uLong                 cziparchive_z_uLong
#  define uLongf                cziparchive_z_uLongf
#  define voidp                 cziparchive_z_voidp
#  define voidpc                cziparchive_z_voidpc
#  define voidpf                cziparchive_z_voidpf

/* all zlib structs in zlib.h and zconf.h */
#  define gz_header_s           cziparchive_z_gz_header_s
#  define internal_state        cziparchive_z_internal_state

#endif

#if defined(__MSDOS__) && !defined(MSDOS)
#  define MSDOS
#endif
#if (defined(OS_2) || defined(__OS2__)) && !defined(OS2)
#  define OS2
#endif
#if defined(_WINDOWS) && !defined(WINDOWS)
#  define WINDOWS
#endif
#if defined(_WIN32) || defined(_WIN32_WCE) || defined(__WIN32__)
#  ifndef WIN32
#    define WIN32
#  endif
#endif
#if (defined(MSDOS) || defined(OS2) || defined(WINDOWS)) && !defined(WIN32)
#  if !defined(__GNUC__) && !defined(__FLAT__) && !defined(__386__)
#    ifndef SYS16BIT
#      define SYS16BIT
#    endif
#  endif
#endif

/*
 * Compile with -DMAXSEG_64K if the alloc function cannot allocate more
 * than 64k bytes at a time (needed on systems with 16-bit int).
 */
#ifdef SYS16BIT
#  define MAXSEG_64K
#endif
#ifdef MSDOS
#  define UNALIGNED_OK
#endif

#ifdef __STDC_VERSION__
#  ifndef STDC
#    define STDC
#  endif
#  if __STDC_VERSION__ >= 199901L
#    ifndef STDC99
#      define STDC99
#    endif
#  endif
#endif
#if !defined(STDC) && (defined(__STDC__) || defined(__cplusplus))
#  define STDC
#endif
#if !defined(STDC) && (defined(__GNUC__) || defined(__BORLANDC__))
#  define STDC
#endif
#if !defined(STDC) && (defined(MSDOS) || defined(WINDOWS) || defined(WIN32))
#  define STDC
#endif
#if !defined(STDC) && (defined(OS2) || defined(__HOS_AIX__))
#  define STDC
#endif

#if defined(__OS400__) && !defined(STDC)    /* iSeries (formerly AS/400). */
#  define STDC
#endif

#ifndef STDC
#  ifndef const /* cannot use !defined(STDC) && !defined(const) on Mac */
#    define const       /* note: need a more gentle solution here */
#  endif
#endif

#ifndef cziparchive_z_const
#  ifdef CZIPARCHIVE_ZLIB_CONST
#    define cziparchive_z_const const
#  else
#    define cziparchive_z_const
#  endif
#endif

#ifdef CZIPARCHIVE_Z_SOLO
#  ifdef _WIN64
     typedef unsigned long long cziparchive_z_size_t;
#  else
     typedef unsigned long cziparchive_z_size_t;
#  endif
#else
#  define cziparchive_z_longlong long long
#  if defined(NO_SIZE_T)
     typedef unsigned NO_SIZE_T cziparchive_z_size_t;
#  elif defined(STDC)
#    include <stddef.h>
     typedef size_t cziparchive_z_size_t;
#  else
     typedef unsigned long cziparchive_z_size_t;
#  endif
#  undef cziparchive_z_longlong
#endif

/* Maximum value for memLevel in deflateInit2 */
#ifndef MAX_MEM_LEVEL
#  ifdef MAXSEG_64K
#    define MAX_MEM_LEVEL 8
#  else
#    define MAX_MEM_LEVEL 9
#  endif
#endif

/* Maximum value for windowBits in deflateInit2 and inflateInit2.
 * WARNING: reducing MAX_WBITS makes minigzip unable to extract .gz files
 * created by gzip. (Files created by minigzip can still be extracted by
 * gzip.)
 */
#ifndef MAX_WBITS
#  define MAX_WBITS   15 /* 32K LZ77 window */
#endif

/* The memory requirements for deflate are (in bytes):
            (1 << (windowBits+2)) +  (1 << (memLevel+9))
 that is: 128K for windowBits=15  +  128K for memLevel = 8  (default values)
 plus a few kilobytes for small objects. For example, if you want to reduce
 the default memory requirements from 256K to 128K, compile with
     make CFLAGS="-O -DMAX_WBITS=14 -DMAX_MEM_LEVEL=7"
 Of course this will generally degrade compression (there's no free lunch).

   The memory requirements for inflate are (in bytes) 1 << windowBits
 that is, 32K for windowBits=15 (default value) plus about 7 kilobytes
 for small objects.
*/

                        /* Type declarations */

#ifndef OF /* function prototypes */
#  ifdef STDC
#    define OF(args)  args
#  else
#    define OF(args)  ()
#  endif
#endif

/* The following definitions for FAR are needed only for MSDOS mixed
 * model programming (small or medium model with some far allocations).
 * This was tested only with MSC; for other MSDOS compilers you may have
 * to define NO_MEMCPY in zutil.h.  If you don't need the mixed model,
 * just define FAR to be empty.
 */
#ifdef SYS16BIT
#  if defined(M_I86SM) || defined(M_I86MM)
     /* MSC small or medium model */
#    define SMALL_MEDIUM
#    ifdef _MSC_VER
#      define FAR _far
#    else
#      define FAR far
#    endif
#  endif
#  if (defined(__SMALL__) || defined(__MEDIUM__))
     /* Turbo C small or medium model */
#    define SMALL_MEDIUM
#    ifdef __BORLANDC__
#      define FAR _far
#    else
#      define FAR far
#    endif
#  endif
#endif

#if defined(WINDOWS) || defined(WIN32)
   /* If building or using zlib as a DLL, define CZIPARCHIVE_ZLIB_DLL.
    * This is not mandatory, but it offers a little performance increase.
    */
#  ifdef CZIPARCHIVE_ZLIB_DLL
#    if defined(WIN32) && (!defined(__BORLANDC__) || (__BORLANDC__ >= 0x500))
#      ifdef CZIPARCHIVE_ZLIB_INTERNAL
#        define ZEXTERN extern __declspec(dllexport)
#      else
#        define ZEXTERN extern __declspec(dllimport)
#      endif
#    endif
#  endif  /* CZIPARCHIVE_ZLIB_DLL */
   /* If building or using zlib with the WINAPI/WINAPIV calling convention,
    * define CZIPARCHIVE_ZLIB_WINAPI.
    * Caution: the standard ZLIB1.DLL is NOT compiled using CZIPARCHIVE_ZLIB_WINAPI.
    */
#  ifdef CZIPARCHIVE_ZLIB_WINAPI
#    ifdef FAR
#      undef FAR
#    endif
#    ifndef WIN32_LEAN_AND_MEAN
#      define WIN32_LEAN_AND_MEAN
#    endif
#    include <windows.h>
     /* No need for _export, use ZLIB.DEF instead. */
     /* For complete Windows compatibility, use WINAPI, not __stdcall. */
#    define ZEXPORT WINAPI
#    ifdef WIN32
#      define ZEXPORTVA WINAPIV
#    else
#      define ZEXPORTVA FAR CDECL
#    endif
#  endif
#endif

#if defined (__BEOS__)
#  ifdef CZIPARCHIVE_ZLIB_DLL
#    ifdef CZIPARCHIVE_ZLIB_INTERNAL
#      define ZEXPORT   __declspec(dllexport)
#      define ZEXPORTVA __declspec(dllexport)
#    else
#      define ZEXPORT   __declspec(dllimport)
#      define ZEXPORTVA __declspec(dllimport)
#    endif
#  endif
#endif

#ifndef ZEXTERN
#  define ZEXTERN extern
#endif
#ifndef ZEXPORT
#  define ZEXPORT
#endif
#ifndef ZEXPORTVA
#  define ZEXPORTVA
#endif

#ifndef FAR
#  define FAR
#endif

#if !defined(__MACTYPES__)
typedef unsigned char  Byte;  /* 8 bits */
#endif
typedef unsigned int   uInt;  /* 16 bits or more */
typedef unsigned long  uLong; /* 32 bits or more */

#ifdef SMALL_MEDIUM
   /* Borland C/C++ and some old MSC versions ignore FAR inside typedef */
#  define Bytef Byte FAR
#else
   typedef Byte  FAR Bytef;
#endif
typedef char  FAR charf;
typedef int   FAR intf;
typedef uInt  FAR uIntf;
typedef uLong FAR uLongf;

#ifdef STDC
   typedef void const *voidpc;
   typedef void FAR   *voidpf;
   typedef void       *voidp;
#else
   typedef Byte const *voidpc;
   typedef Byte FAR   *voidpf;
   typedef Byte       *voidp;
#endif

#if !defined(CZIPARCHIVE_Z_U4) && !defined(CZIPARCHIVE_Z_SOLO) && defined(STDC)
#  include <limits.h>
#  if (UINT_MAX == 0xffffffffUL)
#    define CZIPARCHIVE_Z_U4 unsigned
#  elif (ULONG_MAX == 0xffffffffUL)
#    define CZIPARCHIVE_Z_U4 unsigned long
#  elif (USHRT_MAX == 0xffffffffUL)
#    define CZIPARCHIVE_Z_U4 unsigned short
#  endif
#endif

#ifdef CZIPARCHIVE_Z_U4
   typedef CZIPARCHIVE_Z_U4 cziparchive_z_crc_t;
#else
   typedef unsigned long cziparchive_z_crc_t;
#endif

#if 1     /* was set to #if 1 by ./configure */
#  define CZIPARCHIVE_Z_HAVE_UNISTD_H
#endif

#if 1     /* was set to #if 1 by ./configure */
#  define CZIPARCHIVE_Z_HAVE_STDARG_H
#endif

#ifdef STDC
#  ifndef CZIPARCHIVE_Z_SOLO
#    include <sys/types.h>      /* for off_t */
#  endif
#endif

#if defined(STDC) || defined(CZIPARCHIVE_Z_HAVE_STDARG_H)
#  ifndef CZIPARCHIVE_Z_SOLO
#    include <stdarg.h>         /* for va_list */
#  endif
#endif

#ifdef _WIN32
#  ifndef CZIPARCHIVE_Z_SOLO
#    include <stddef.h>         /* for wchar_t */
#  endif
#endif

/* a little trick to accommodate both "#define _LARGEFILE64_SOURCE" and
 * "#define _LARGEFILE64_SOURCE 1" as requesting 64-bit operations, (even
 * though the former does not conform to the LFS document), but considering
 * both "#undef _LARGEFILE64_SOURCE" and "#define _LARGEFILE64_SOURCE 0" as
 * equivalently requesting no 64-bit operations
 */
#if defined(_LARGEFILE64_SOURCE) && -_LARGEFILE64_SOURCE - -1 == 1
#  undef _LARGEFILE64_SOURCE
#endif

#ifndef CZIPARCHIVE_Z_HAVE_UNISTD_H
#  if defined(__WATCOMC__) || defined(__GO32__) || \
      (defined(_LARGEFILE64_SOURCE) && !defined(_WIN32))
#    define CZIPARCHIVE_Z_HAVE_UNISTD_H
#  endif
#endif
#ifndef CZIPARCHIVE_Z_SOLO
#  if defined(CZIPARCHIVE_Z_HAVE_UNISTD_H)
#    include <unistd.h>         /* for SEEK_*, off_t, and _LFS64_LARGEFILE */
#    ifdef VMS
#      include <unixio.h>       /* for off_t */
#    endif
#    ifndef cziparchive_z_off_t
#      define cziparchive_z_off_t off_t
#    endif
#  endif
#endif

#if defined(_LFS64_LARGEFILE) && _LFS64_LARGEFILE-0
#  define CZIPARCHIVE_Z_LFS64
#endif

#if defined(_LARGEFILE64_SOURCE) && defined(CZIPARCHIVE_Z_LFS64)
#  define CZIPARCHIVE_Z_LARGE64
#endif

#if defined(_FILE_OFFSET_BITS) && _FILE_OFFSET_BITS-0 == 64 && defined(CZIPARCHIVE_Z_LFS64)
#  define CZIPARCHIVE_Z_WANT64
#endif

#if !defined(SEEK_SET) && !defined(CZIPARCHIVE_Z_SOLO)
#  define SEEK_SET        0       /* Seek from beginning of file.  */
#  define SEEK_CUR        1       /* Seek from current position.  */
#  define SEEK_END        2       /* Set file pointer to EOF plus "offset" */
#endif

#ifndef cziparchive_z_off_t
#  define cziparchive_z_off_t long long
#endif

#if !defined(_WIN32) && defined(CZIPARCHIVE_Z_LARGE64)
#  define cziparchive_z_off64_t off64_t
#elif defined(__MINGW32__)
#  define cziparchive_z_off64_t long long
#elif defined(_WIN32) && !defined(__GNUC__)
#  define cziparchive_z_off64_t __int64
#elif defined(__GO32__)
#  define cziparchive_z_off64_t offset_t
#else
#  define cziparchive_z_off64_t cziparchive_z_off_t
#endif

/* MVS linker does not support external names larger than 8 bytes */
#if defined(__MVS__)
  #pragma map(deflateInit_,"DEIN")
  #pragma map(deflateInit2_,"DEIN2")
  #pragma map(deflateEnd,"DEEND")
  #pragma map(deflateBound,"DEBND")
  #pragma map(inflateInit_,"ININ")
  #pragma map(inflateInit2_,"ININ2")
  #pragma map(inflateEnd,"INEND")
  #pragma map(inflateSync,"INSY")
  #pragma map(inflateSetDictionary,"INSEDI")
  #pragma map(compressBound,"CMBND")
  #pragma map(inflate_table,"INTABL")
  #pragma map(inflate_fast,"INFA")
  #pragma map(inflate_copyright,"INCOPY")
#endif

#endif /* ZIPARCHIVE_ZCONF_H */
