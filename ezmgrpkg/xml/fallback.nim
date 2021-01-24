import xmlio, vtable, tables, base, ns, uri

declareXmlElement:
  type FallbackRepository* {.id: "df4cd0df-ce37-457f-a3f8-ac5d38742b21", children: repos.} = object of RootObj
    repos {.check(value.len == 0, r"no repo found").}: seq[ref ModRepository]

impl FallbackRepository, ModRepository:
  method list*(self: ref FallbackRepository, base: Uri): Table[string, ref ModInfo] =
    for repo in self.repos:
      try:
        return repo.list(base)
      except:
        discard
    raise newException(ValueError, "all fallback failed")

rootns.registerType("fallback-repo", ref FallbackRepository, ref ModRepository)

{.used.}
