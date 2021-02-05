{.experimental: "caseStmtMacros".}
import std/[os, osproc, streams, strtabs, strformat, terminal, oids, tables, uri], fusion/matching
import ezprompt
import winim/lean except `&`
import ezpipe, binpak, ezcommon/[log, ipc]
import ./shared, ../xml

type
  RunResultKind = enum
    rrk_die
    rrk_run
    rrk_dbg
    rrk_out
    rrk_err
    rrk_log
  RunResult = object
    case kind: RunResultKind
    of rrk_run:
      exit_code: int
    of rrk_dbg, rrk_out, rrk_err:
      content: string
    of rrk_log:
      log_data: LogData
    of rrk_die:
      discard

var run_result: Channel[RunResult]

type DaemonContext = tuple
  ipc: ref IpcPipe
  config: ref ManagerConfig
  base: Uri

proc daemonThread(ctx: DaemonContext) {.thread.} =
  let (ipc, config, base) = ctx
  ipc.accept()
  while true:
    case RequestPacket <<- ipc.recv()
    of bye():
      run_result.send RunResult(kind: rrk_die)
      return
    of ping():
      ipc.send: ~>$ ResponsePacket(kind: res_pong)
    of log(logData: @data):
      run_result.send RunResult(kind: rrk_log, log_data: data)
    of load(modName: @id, minVersion: @minVersion, maxVersion: @maxVersion):
      let modreq = ModQuery(id: id, version: (minVersion..maxVersion))
      try: {.gcsafe.}:
        let modinfo = config.repository.query(base, modreq)
        if modinfo == nil:
          ipc.send: ~>$ ResponsePacket(kind: res_failed, errMsg: "mod not found")
          continue
        let path = config.cache / getModCachedName(id, modinfo)
        if not fileExists path:
          run_result.send RunResult(kind: rrk_dbg, content: &"Fetching mod {id}")
          modinfo.fetch(path)
        ipc.send: ~>$ ResponsePacket(kind: res_load, modPath: path)
      except:
        ipc.send: ~>$ ResponsePacket(kind: res_failed, errMsg: getCurrentExceptionMsg())

proc runThread(prc: Process) {.thread.} =
  let code = prc.waitForExit()
  run_result.send RunResult(kind: rrk_run, exit_code: code)

proc outThread[kind: static RunResultKind](str: Stream) =
  var line = ""
  while str.readLine(line):
    run_result.send RunResult(kind: kind, content: line)

proc inpThread(arg: tuple[str: Stream, p: Prompt]) {.thread.} =
  while true:
    let text = arg.p.readLine()
    arg.str.writeLine(text)

proc runInstance*(name: string) =
  let cfg = loadCfg()
  doAssert dirExists name
  run_result.open(4)
  var ipc_thr: Thread[DaemonContext]
  var run_thr: Thread[Process]
  var out_thrs: array[2, Thread[Stream]]
  var inp_thr: Thread[tuple[str: Stream, p: Prompt]]
  var envtab = newStringTable()
  for (key, value) in envPairs():
    envtab[key] = value
  let ipc = newIpcPipeServer()
  ipc_thr.createThread(daemonThread, (ipc: ipc, config: cfg.content, base: cfg.base))
  envtab["EZPIPE"] = $ipc.id
  let prc = startProcess(
    command = getAppDir() / "bedrock_server.exe",
    workingDir = name,
    env = envtab,
    options = {})
  proc ctrlc() =
    try:
      prc.inputStream().writeLine("stop")
    except:
      quit 0
  let prompt = Prompt.init(&"[EZ]{name}> ", ctrlCHandler = ctrlc)
  run_thr.createThread(runThread, prc)
  out_thrs[0].createThread(outThread[rrk_out], prc.outputStream())
  out_thrs[1].createThread(outThread[rrk_err], prc.errorStream())
  inp_thr.createThread(inpThread, (str: prc.inputStream(), p: prompt))
  defer:
    TerminateProcess(-1, 0)
  while true:
    case run_result.recv()
    of die(): return
    of run(exit_code: @code):
      prompt.hidePrompt()
      styledEcho fgRed, styleBright, "exit code: ", resetStyle, styleBright, styleBlink, $code, resetStyle
    of dbg(content: @content): prompt.writeLine fgYellow, styleBright, content, resetStyle
    of rrk_out(content: @content): prompt.writeLine content
    of rrk_err(content: @content): prompt.writeLine fgRed, content, resetStyle
    of log(log_data: @data):
      let colors = case data.level:
        of lvl_notice: (tag: fgCyan, lvlbg: bgCyan, lvlfg: fgBlack)
        of lvl_info: (tag: fgBlue, lvlbg: bgBlue, lvlfg: fgBlack)
        of lvl_debug: (tag: fgMagenta, lvlbg: bgMagenta, lvlfg: fgBlack)
        of lvl_warn: (tag: fgYellow, lvlbg: bgYellow, lvlfg: fgBlack)
        of lvl_error: (tag: fgRed, lvlbg: bgRed, lvlfg: fgBlack)
      let txt = case data.level:
        of lvl_notice: "[V]"
        of lvl_info: "[I]"
        of lvl_debug: "[D]"
        of lvl_warn: "[W]"
        of lvl_error: "[E]"
      prompt.withOutput do():
        stdout.styledWrite colors.tag, styleBright, txt, resetStyle, " "
        stdout.styledWrite colors.lvlbg, colors.lvlfg, data.area, resetStyle, " "
        for tag in data.tags:
          stdout.styledWrite fgGreen, styleDim, tag, resetStyle, " "
        stdout.styledWrite styleBright, data.content, resetStyle, " "
        stdout.styledWrite data.source, "(", $data.line, ")"
        stdout.write("\n")
        for key, val in data.details:
          stdout.styledWriteLine(
            "    ", resetStyle, styleBright, $key, resetStyle,
            fgCyan, ": ", styleBright, $val, resetStyle)
