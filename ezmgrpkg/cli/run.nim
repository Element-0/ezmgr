import std/[os, osproc, streams, strtabs, strformat, terminal, oids, tables]
import prompt
import ezpipe, binpak, ezcommon/[log, ipc]

type
  RunResultKind = enum
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

var run_result: Channel[RunResult]

proc daemonThread(ipc: ref IpcPipe) {.thread.} =
  ipc.accept()
  while true:
    let req = RequestPacket <<- ipc.recv()
    # run_result.send RunResult(kind: rrk_dbg, content: $req)
    case req.kind:
    of req_ping:
      ipc.send: ~>$ ResponsePacket(kind: res_pong)
    of req_log:
      run_result.send RunResult(kind: rrk_log, log_data: req.logData)
      ipc.send: ~>$ ResponsePacket(kind: res_pong)
    else:
      ipc.send: ~>$ ResponsePacket(kind: res_failed, errMsg: "TODO")

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
  doAssert dirExists name
  run_result.open(4)
  var ipc_thr: Thread[ref IpcPipe]
  var run_thr: Thread[Process]
  var out_thrs: array[2, Thread[Stream]]
  var inp_thr: Thread[tuple[str: Stream, p: Prompt]]
  var envtab = newStringTable()
  for (key, value) in envPairs():
    envtab[key] = value
  let ipc = newIpcPipeServer()
  ipc_thr.createThread(daemonThread, ipc)
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
  while true:
    let res = run_result.recv()
    case res.kind:
    of rrk_run:
      prompt.hidePrompt()
      prompt.writeLine fgRed, styleBright, "exit code: ", fgWhite, styleBright, styleBlink, $res.exit_code, resetStyle
      run_thr.joinThread()
    of rrk_dbg:
      prompt.writeLine fgYellow, styleBright, res.content, resetStyle
    of rrk_out:
      prompt.writeLine fgWhite, styleBright, res.content, resetStyle
    of rrk_err:
      prompt.writeLine fgRed, res.content, resetStyle
    of rrk_log:
      let color = case res.log_data.level:
        of lvl_notice: fgWhite
        of lvl_info: fgBlue
        of lvl_debug: fgMagenta
        of lvl_warn: fgYellow
        of lvl_error: fgRed
      let txt = case res.log_data.level:
        of lvl_notice: "[V]"
        of lvl_info: "[I]"
        of lvl_debug: "[D]"
        of lvl_warn: "[W]"
        of lvl_error: "[E]"
      prompt.writeLine(
        color, txt, " ",
        styleBright, res.log_data.area, resetStyle, " ",
        styleUnderscore, res.log_data.src_name,
        "(", $res.log_data.src_line, ":", $res.log_data.src_column, ")", resetStyle, " ",
        styleBright, res.log_data.content, resetStyle)
      for key, val in res.log_data.details:
        prompt.writeLine "  ", fgCyan, "=", $val
