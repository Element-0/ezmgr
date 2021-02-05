import std/parseopt
import ./shared, ./cmds, ./run

proc handleCLI*() =
  var p = initOptParser()
  case p.nextArgument():
  of "help": printHelp()
  of "dump":
    p.expectKind(cmdEnd)
    dumpConfig()
  of "fetch":
    fetchMod(p)
  of "generate":
    generateUserData(p.nextArgument(), p)
  of "run":
    let name = p.nextArgument()
    p.expectKind(cmdEnd)
    runInstance(name)
  else: printHelp()
