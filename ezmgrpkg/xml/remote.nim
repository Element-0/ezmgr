import xmlio, vtable, uri, tables, base, ns, streams, fetch, options

declareXmlElement:
  type RemoteRepository* {.id: "eaf01fcf-def7-4d3b-b9e3-e55eede1ba5f".} = object of RootObj
    href: Uri
    cached {.skipped.}: Option[Table[string, ref ModInfo]]

impl RemoteRepository, ModRepository:
  method list*(self: ref RemoteRepository, base: Uri): Table[string, ref ModInfo] =
    if self.cached.isNone:
      let desturl = resolveUri(base, self.href)
      let str = fetchString(desturl)
      self.cached = some readXml(root, str, ref ModRepository).list(desturl)
    self.cached.unsafeGet()

rootns.registerType("remote-repo", ref RemoteRepository, ref ModRepository)

{.used.}
