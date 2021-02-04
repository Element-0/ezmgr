import std/[uri, algorithm, tables, options, sugar], xmlio, vtable
import ezcommon/version_code
import ./base, ./ns, ./os, ./fileinfo, ./strformat, ./fetch

declareXmlElement:
  type ModManifest* {.id: "e18cdb2d-efda-4d01-bf36-cbdf21eb6db9", children: description.} = object of RootObj
    href: Uri
    description: ref ModDescription
    base {.skipped.}: Uri
    id {.skipped.}: string

func `$`*(self: ref ModManifest): string =
  "(href: " & $self.href & ", version: " & $self.description.version & ")"

impl ModManifest, ModInfo:
  method desc*(self: ref ModManifest): ref ModDescription = self.description
  method fetch*(self: ref ModManifest, dest: string) =
    fetchFile(resolveUri(self.base, self.href), dest)
    let ret = try:
      parseModFile(dest)
    except:
      removeFile(dest)
      raise getCurrentException()
    if ret.id != self.id:
      removeFile(dest)
      raise newException(ValueError, &"mod id not matched, expected {self.id}, but got {ret.id}")
    if ret.desc != self.description:
      removeFile(dest)
      raise newException(ValueError, &"mod version not matched, expected {self.description.version}, but got {ret.desc.version}")

rootns.registerType("manifest", ref ModManifest)

type
  QualifiedModMap = Table[string, seq[ref ModManifest]]
  QualifiedModMapHandler = object of RootObj
    proxy: ptr QualifiedModMap
    tmp: ref QualifiedModMapAttachedHandler
  QualifiedModMapAttachedHandler = object of RootObj
    id: string
    value: ref ModManifest

impl QualifiedModMapAttachedHandler, XmlAttachedAttributeHandler:
  method setAttribute(
      self: ref QualifiedModMapAttachedHandler,
      key: string,
      value: string) =
    case key:
    of "id":
      self.id = value
    else:
      raise newException(ValueError, "unknown attached attribute: " & key)
  method createProxy(self: ref QualifiedModMapAttachedHandler): TypedProxy =
    if self.id.len == 0:
      raise newException(ValueError, "invalid mod id")
    createProxy self.value
  method finish(self: ref QualifiedModMapAttachedHandler) =
    self.value.id = self.id
    if self.id.len == 0:
      raise newException(ValueError, "invalid mod id")

func upperBoundVersion(a: seq[ref ModManifest], k: VersionCode): int {.inline.}=
  return a.upperBound(k, (x, k) => -cmp(x.description.version, k))
func upperBoundVersion(a: seq[ref ModManifest], r: ref ModManifest): int {.inline.}=
  upperBoundVersion(a, r.description.version)

impl QualifiedModMapHandler, XmlAttributeHandler:
  method createChildProxy*(self: ref QualifiedModMapHandler): XmlChild =
    self.tmp = new QualifiedModMapAttachedHandler
    toXmlAttachedAttributeHandler self.tmp
  method addChild*(self: ref QualifiedModMapHandler) =
    assert self.tmp != nil
    template src: QualifiedModMap = self.proxy[]
    src.withValue(self.tmp.id, vals):
      vals[].insert(self.tmp.value, vals[].upperBoundVersion(self.tmp.value))
    do:
      src[self.tmp.id] = @[self.tmp.value]
    self.tmp = nil
  method verify*(self: ref QualifiedModMapHandler) {.nimcall.} =
    discard

proc createAttributeHandlerConcrete*(val: var QualifiedModMap): ref QualifiedModMapHandler =
  new result
  result.proxy = addr val

declareXmlElement:
  type ManifestRepository* {.id: "f0067348-0817-405c-9e1d-44e00492fb34".} = object of RootObj
    children: QualifiedModMap

func findVersion(data: var seq[ref ModManifest], slice: Slice[VersionCode]): ref ModManifest =
  let bound = data.upperBoundVersion(slice.b)
  if data[bound].description.version >= slice.a:
    return data[bound]

impl ManifestRepository, ModRepository:
  method query*(self: ref ManifestRepository; base: Uri; query: ModQuery): ref ModInfo =
    self.children.withValue(query.id, data):
      let tmp = data[].findVersion(query.version)
      tmp.base = base
      return tmp

  method list*(self: ref ManifestRepository, base: Uri; callback: ModListCallback) =
    for id, arr in self.children:
      for item in arr:
        item.base = base
        if callback(id, item):
          return

rootns.registerType("manifest-repo", ref ManifestRepository, ref ModRepository)

{.used.}
