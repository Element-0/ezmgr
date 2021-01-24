import xmlio, vtable, uri, tables, base, ns, streams, fetch

declareXmlElement:
  type RemoteRepository* {.id: "eaf01fcf-def7-4d3b-b9e3-e55eede1ba5f".} = object of RootObj
    href: Uri
    cached {.skipped.}: ref ModRepository

impl RemoteRepository, ModRepository:
  method list*(self: ref RemoteRepository): Table[string, ref ModInfo] =
    if self.cached == nil:
      let str = fetchString(self.href)
      self.cached = readXml(root, str, ref ModRepository)
    self.cached.list()

rootns.registerType("remote-repo", ref RemoteRepository, ref ModRepository)

{.used.}
