import winim/inc/winbase
import winim/[winstr, lean]
import strformat
import base, ezcommon/version_code

type LANGANDCODEPAGE {.pure, final.} = object
  lang, code: uint16

type InvalidFileInfoError* = object of ValueError

template queryKind(x: static string): string =
  var desc: LPWSTR
  var desc_n: UINT
  let path = basepart & x
  if VerQueryValue(pblock, path, cast[ptr PVOID](addr desc), addr desc_n) == 0:
    raise newException(InvalidFileInfoError, x & " not found in file")
  $desc
template queryOptionalKind(x: static string): string =
  var desc: LPWSTR
  var desc_n: UINT
  let path = basepart & x
  if VerQueryValue(pblock, path, cast[ptr PVOID](addr desc), addr desc_n) == 0:
    ""
  else:
    $desc

proc parseModFile*(str: string): tuple[id: string, desc: ref ModDescription] =
  new result.desc
  let size = GetFileVersionInfoSize(str, nil)
  if size == 0:
    raise newException(InvalidFileInfoError, "invalid mod")
  var buffer = newSeq[byte](size)
  let pblock = addr buffer[0]
  if GetFileVersionInfo(str, 0, size, pblock) == 0:
    raise newException(InvalidFileInfoError, "failed to read file version")
  var fixed: ptr VS_FIXEDFILEINFO
  if VerQueryValue(pblock, L"\\", cast[ptr PVOID](addr fixed), nil) == 0:
    raise newException(InvalidFileInfoError, "no version information")
  result.desc.version = VersionCode((uint64(fixed[].dwFileVersionMS) shl 32) or uint64(fixed[].dwFileVersionLS))
  if result.desc.version == VersionCode(0):
    raise newException(InvalidFileInfoError, "zero version code found")
  var langcode: ptr LANGANDCODEPAGE
  var langcode_n: UINT
  if VerQueryValue(pblock, L"\\VarFileInfo\\Translation", cast[ptr PVOID](addr langcode), addr langcode_n) == 0:
    raise newException(InvalidFileInfoError, "no version translation found")
  if langcode_n == 0 or langcode_n mod sizeof(LANGANDCODEPAGE) != 0:
    raise newException(InvalidFileInfoError, "invalid version translation count")
  let lc = langcode[]
  let basepart = fmt"\StringFileInfo\{lc.lang:04x}{lc.code:04x}\"
  result.id = queryKind("InternalName")
  result.desc.name = queryKind("OriginalFilename")
  result.desc.desc = queryKind("FileDescription")
  result.desc.author = queryKind("CompanyName")
  result.desc.comment = queryOptionalKind("Comments")
  result.desc.license = queryKind("LegalCopyright")
