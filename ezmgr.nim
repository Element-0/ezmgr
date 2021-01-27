when not isMainModule:
  {.error: "cannot be imported".}

import ezmgrpkg/cli/dispatcher

handleCLI()
