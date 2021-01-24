import xmlio, vtable, tables, base, ns

declareXmlElement:
  type FallbackRepository* {.id: "df4cd0df-ce37-457f-a3f8-ac5d38742b21".} = object of RootObj
    repos {.check(value.len == 0, r"no repo found").}: seq[ref ModRepository]

impl FallbackRepository, ModRepository:
  method list*(self: ref FallbackRepository): Table[string, ref ModInfo] =
    for repo in self.repos:
      try:
        return repo.list()
      except:
        discard
    raise newException(ValueError, "all fallback failed")

rootns.registerType("fallback-repo", ref FallbackRepository, ref ModRepository)

{.used.}
