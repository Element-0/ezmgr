import std/[uri, os, streams, strutils, parseopt, strformat]
import xmlio
import ../xml

proc loadCfg*(): tuple[content: ref ManagerConfig, base: Uri] =
  let path = getAppDir() / "ezmgr.xml"
  let str = openFileStream(path)
  result.content = readXml(root, str, path, ref ManagerConfig)
  var cururl = initUri()
  cururl.scheme = "file"
  cururl.path = path.replace('\\', '/')
  result.base = cururl

proc nextArgument*(p: var OptParser): string =
  p.next()
  if p.kind == cmdArgument:
    return p.key
  echo &"except argument, got {p.kind}"
  quit 1

proc expectKind*(p: var OptParser, kind: static CmdLineKind) =
  p.next()
  if p.kind != kind:
    echo &"expect {kind}, got {p.kind}"
    quit 1

proc getModCachedName*(id: string, info: ref ModInfo): string =
  &"cached-{id}-{info.version}.dll"