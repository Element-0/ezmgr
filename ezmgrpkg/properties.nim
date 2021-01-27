import os, parseopt, strformat, strutils, sugar, options, streams

type PGameMode* {.pure.} = enum
  gmSurvival = "survival"
  gmCreative = "creative"
  gmAdventure = "adventure"

type PDifficulty* {.pure.} = enum
  dfPeaceful = "peaceful"
  dfEasy = "easy"
  dfNormal = "normal"
  dfHard = "hard"

type PPermissionLevel* {.pure.} = enum
  plVisitor = "visitor"
  plMember = "member"
  plOperator = "operator"

type PMovement* {.pure.} = enum
  mServerAuth = "server-auth"
  mClientAuth = "client-auth"

type Properities* {.pure, final.} = object
  server_name*: string
  game_mode*: PGameMode
  difficulty*: PDifficulty
  allow_cheats*: bool
  max_players*: int
  online_mode*: bool
  white_list*: bool
  force_gamemode*: bool
  op_permission_level*: int
  server_port, server_portv6*: int
  wserver_retry_time*: int
  wserver_encryption*: bool
  view_distance, tick_distance*: int
  player_idle_timeout*: int
  language*: string
  max_threads*: int
  level_name, server_type, level_seed*: string
  default_player_permission_level*: PPermissionLevel
  server_wakeup_frequency*: int
  texturepack_required*: bool
  compression_threshold*: int
  msa_gamertags_only*: bool
  item_transaction_logging_enabled*: bool
  player_movement*: PMovement
  player_movement_score_threshold*: int
  player_movement_distance_threshold*: float
  player_movement_duration_threshold_in_ms*: int
  correct_player_movement*: bool

proc initCfg*(): Properities =
  result.game_mode = gmCreative
  result.difficulty = dfPeaceful
  result.default_player_permission_level = plMember
  result.player_movement = mServerAuth
  result.op_permission_level = 4
  result.server_port = 19132
  result.server_portv6 = 19133
  result.max_players = 12
  result.view_distance = 8
  result.tick_distance = 4
  result.player_idle_timeout = 30
  result.server_wakeup_frequency = 200
  result.max_threads = 8
  result.compression_threshold = 1
  result.player_movement_score_threshold = 20
  result.player_movement_distance_threshold = 0.3
  result.player_movement_duration_threshold_in_ms = 500
  result.correct_player_movement = true
  result.server_name = "Element Zero"
  result.level_name = "default"
  result.server_type = "normal"
  result.language = "en_US"

proc assumeNoEmpty(key: string, str: string): string {.inline.} =
  if str.isEmptyOrWhitespace():
    raise newException(ValueError, &"empty option {key}")
  str

proc toBool(str: string): bool {.inline.} =
  if str.isEmptyOrWhitespace(): true else: parseBool(str)

proc verify[T](key: string, val: T, check: (T) -> bool): T {.inline.} =
  if not check(val):
    raise newException(ValueError, &"invalid option {key} value: {val}")
  val

proc parseCfgFromOpt*(p: var OptParser, props: var Properities): Option[string] =
  while true:
    p.next()
    case p.kind:
    of cmdArgument:
      raise newException(ValueError, &"invalid argument {p.key}")
    of cmdShortOption:
      raise newException(ValueError, &"invalid option {p.key}")
    of cmdLongOption:
      case p.key:
      of "server-name": props.server_name = assumeNoEmpty(p.key, p.val)
      of "game-mode": props.game_mode = parseEnum[PGameMode](p.val)
      of "difficulty": props.difficulty = parseEnum[PDifficulty](p.val)
      of "allow-cheats": props.allow_cheats = toBool p.val
      of "disallow-cheats": props.allow_cheats = not toBool p.val
      of "max-players": props.max_players = verify(p.key, parseInt(p.val), (x) => x is Positive)
      of "online-mode": props.online_mode = toBool p.val
      of "offline-mode": props.online_mode = not toBool p.val
      of "white-list":
        props.white_list = true
        if p.val.isEmptyOrWhitespace():
          result = some p.val.strip()
      of "force-gamemode": props.force_gamemode = toBool p.val
      of "op-permission-level": props.op_permission_level = verify(p.key, parseInt(p.val), (x) => x in 1..6)
      of "server-port": props.server_port = verify(p.key, parseInt(p.val), (x) => x in 1..65535)
      of "server-portv6": props.server_portv6 = verify(p.key, parseInt(p.val), (x) => x in 1..65535)
      of "wserver-retry-time": props.wserver_retry_time = verify(p.key, parseInt(p.val), (x) => x is Positive)
      of "wsserver-encryption": props.wserver_encryption = toBool p.val
      of "view-distance": props.view_distance = verify(p.key, parseInt(p.val), (x) => x is Positive)
      of "tick-distance": props.view_distance = verify(p.key, parseInt(p.val), (x) => x in 4..12)
      of "player-idle-timeout": props.player_idle_timeout = verify(p.key, parseInt(p.val), (x) => x is Natural)
      of "language": props.language = p.val
      of "max-threads": props.max_threads = verify(p.key, parseInt(p.val), (x) => x is Natural)
      of "level-name": props.level_name = assumeNoEmpty(p.key, p.val)
      of "server-type": props.level_name = assumeNoEmpty(p.key, p.val)
      of "level-seed": props.level_seed = assumeNoEmpty(p.key, p.val)
      of "default-player-permission-level":
        props.default_player_permission_level = parseEnum[PPermissionLevel](p.val)
      of "server-wakeup-frequency": props.server_wakeup_frequency = verify(p.key, parseInt(p.val), (x) => x in 1..1000)
      of "texturepack-required": props.texturepack_required = toBool p.val
      of "texturepack-optional": props.texturepack_required = not toBool p.val
      of "compression-threshold": props.compression_threshold = verify(p.key, parseInt(p.val), (x) => x in 0..65535)
      of "msa-gamertags-only": props.msa_gamertags_only = toBool p.val
      of "item-transaction-logging-enabled":
        props.item_transaction_logging_enabled = toBool p.val
      of "server-authoritative-movement": props.player_movement = mServerAuth
      of "client-authoritative-movement": props.player_movement = mClientAuth
      of "player-movement-score-threshold":
        props.player_movement_score_threshold = verify(p.key, parseInt(p.val), (x) => x is Positive)
      of "player-movement-distance-threshold":
        props.player_movement_distance_threshold = verify(p.key, parseFloat(p.val), (x) => x > 0.0)
      of "player-movement-duration-threshold-in-ms":
        props.player_movement_duration_threshold_in_ms = verify(p.key, parseInt(p.val), (x) => x is Positive)
      of "correct-player-movement": props.correct_player_movement = toBool p.val
    of cmdEnd:
      break

template dumpAttr(str: Stream, props: Properities, attr: untyped) =
  const cached {.gensym.} = static: astToStr(attr).replace("_", "-")
  str.writeLine(cached & "=" & $props.attr)

proc writeCfg*(props: Properities, folder: string) =
  let path = folder / "server.properties"
  let str = openFileStream(path, fmWrite)
  defer: str.close()
  str.dumpAttr(props, server_name)
  str.dumpAttr(props, game_mode)
  str.dumpAttr(props, difficulty)
  str.dumpAttr(props, allow_cheats)
  str.dumpAttr(props, max_players)
  str.dumpAttr(props, online_mode)
  str.dumpAttr(props, white_list)
  str.dumpAttr(props, force_gamemode)
  str.dumpAttr(props, server_port)
  str.dumpAttr(props, server_portv6)
  str.dumpAttr(props, wserver_retry_time)
  str.dumpAttr(props, wserver_encryption)
  str.dumpAttr(props, level_name)
  str.dumpAttr(props, server_type)
  str.dumpAttr(props, level_seed)
  str.dumpAttr(props, max_threads)
  str.dumpAttr(props, op_permission_level)
  str.dumpAttr(props, default_player_permission_level)
  str.dumpAttr(props, player_idle_timeout)
  str.dumpAttr(props, server_wakeup_frequency)
  str.dumpAttr(props, texturepack_required)
  str.dumpAttr(props, compression_threshold)
  str.dumpAttr(props, view_distance)
  str.dumpAttr(props, tick_distance)
  str.dumpAttr(props, language)
  str.writeLine("# Official anti-cheat settings")
  str.dumpAttr(props, msa_gamertags_only)
  str.dumpAttr(props, item_transaction_logging_enabled)
  str.writeLine("server-authoritative-movement" & "=" & $props.player_movement)
  str.dumpAttr(props, player_movement_score_threshold)
  str.dumpAttr(props, player_movement_distance_threshold)
  str.dumpAttr(props, player_movement_duration_threshold_in_ms)
  str.dumpAttr(props, correct_player_movement)
  str.writeLine("content-log-file-enabled=true")
  str.writeLine("# Unknown hidden settings")
  str.writeLine("# player-rewind-position-threshold (float)")
  str.writeLine("# player-rewind-velocity-threshold (float)")
  str.writeLine("# player-rewind-position-acceptance (float)")
  str.writeLine("# player-rewind-position-persuasion (float)")
  str.writeLine("# player-rewind-unsupported-position-threshold (float)")
  str.writeLine("# player-rewind-unsupported-velocity-threshold (float)")
  str.writeLine("# player-rewind-unsupported-position-acceptance (float)")
  str.writeLine("# player-rewind-unsupported-position-persuasion (float)")
  str.writeLine("# player-rewind-min-correction-delay-ticks (int)")
