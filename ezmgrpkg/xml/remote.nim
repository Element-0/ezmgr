import std/[uri, streams], xmlio, vtable
import ./base, ./ns, ./fetch

declareXmlElement:
  type RemoteRepository* {.id: "eaf01fcf-def7-4d3b-b9e3-e55eede1ba5f".} = object of RootObj
    href: Uri
    cached {.skipped.}: ref ModRepository

proc fillCache(self: ref RemoteRepository, base: Uri): ref ModRepository =
  if self.cached == nil:
    let desturl = resolveUri(base, self.href)
    let str = fetchString(desturl)
    self.cached = readXml(root, str, ref ModRepository)
  self.cached

impl RemoteRepository, ModRepository:
  method query*(self: ref RemoteRepository; base: Uri; query: ModQuery): ref ModInfo =
    self.fillCache(base).query(base, query)
  method list*(self: ref RemoteRepository; base: Uri; callback: ModListCallback) =
    self.fillCache(base).list(base, callback)

rootns.registerType("remote-repo", ref RemoteRepository, ref ModRepository)

{.used.}
