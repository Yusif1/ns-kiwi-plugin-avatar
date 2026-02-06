; =============================================================================
; IRCop Core System - ircop-core.mrc
; Compatible with: mIRC 7.72+ | UnrealIRCd 6.5+
; Description: Core IRCop foundation - configuration, oper-up, raw numerics,
;              oper notification routing, custom @IRCop window, menus
; Part of the IRCop System (3-file set): ircop-core / ircop-usermgmt / ircop-monitor
; =============================================================================

; ---------------------
; INITIALIZATION
; ---------------------
on *:START:{
  ; Create hash tables for configuration and runtime state
  if (!$hget(ircop_config)) { hmake ircop_config 50 }
  if (!$hget(ircop_state))  { hmake ircop_state 100 }
  if (!$hget(ircop_templates)) { hmake ircop_templates 50 }

  ; Load saved configuration
  ircop.loadconfig

  ; Initialize default kill reason templates
  ircop.init.templates

  echo -s 4[IRCop System] Core module loaded. mIRC $version / UnrealIRCd 6.5+ mode.
}

on *:UNLOAD:{
  ; Save configuration before unloading
  ircop.saveconfig

  ; Clean up hash tables
  if ($hget(ircop_config)) { hfree ircop_config }
  if ($hget(ircop_state))  { hfree ircop_state }
  if ($hget(ircop_templates)) { hfree ircop_templates }

  ; Close custom window
  if ($window(@IRCop)) { window -c @IRCop }

  echo -s 4[IRCop System] Core module unloaded.
}

; ---------------------
; CONFIGURATION SYSTEM
; ---------------------
alias ircop.loadconfig {
  var %f = $scriptdirircop.conf
  if ($isfile(%f)) {
    hload ircop_config %f
  }
  else {
    ; Set defaults on first run
    ircop.setdefaults
  }
}

alias ircop.saveconfig {
  var %f = $scriptdirircop.conf
  if ($hget(ircop_config)) { hsave ircop_config %f }
}

alias ircop.setdefaults {
  ; Connection defaults
  hadd ircop_config oper.name $null
  hadd ircop_config oper.pass $null
  hadd ircop_config oper.auto 0
  hadd ircop_config oper.modes +gswoSqHtWGnN

  ; Logging
  hadd ircop_config log.enabled 1
  hadd ircop_config log.dir $scriptdirlogs

  ; Window settings
  hadd ircop_config window.auto 1
  hadd ircop_config window.timestamp 1
  hadd ircop_config window.maxlines 5000

  ; Alert settings
  hadd ircop_config alert.sound 1
  hadd ircop_config alert.flash 1
  hadd ircop_config alert.clones 3

  ; Network
  hadd ircop_config network.name MyNetwork

  ; Save immediately
  ircop.saveconfig
}

alias ircop.init.templates {
  hadd ircop_templates kill.spam Spamming/Flooding
  hadd ircop_templates kill.abuse Abusive behavior
  hadd ircop_templates kill.clone Unauthorized clones
  hadd ircop_templates kill.bot Unauthorized bot
  hadd ircop_templates kill.drone Drone/Compromised host
  hadd ircop_templates kill.evade Ban evasion
  hadd ircop_templates kill.illegal Illegal activity
  hadd ircop_templates kill.tos Terms of Service violation
  hadd ircop_templates gline.spam Spamming - network ban applied
  hadd ircop_templates gline.abuse Abusive behavior - network ban applied
  hadd ircop_templates gline.drone Drone/Compromised host - network ban applied
  hadd ircop_templates shun.spam Shunned for spamming
  hadd ircop_templates shun.abuse Shunned for abusive behavior
}

; ---------------------
; @IRCop CUSTOM WINDOW
; ---------------------
alias ircop.window {
  if (!$window(@IRCop)) {
    window -eknz @IRCop
    titlebar @IRCop - IRCop System Console
    aline @IRCop 12,0 IRCop System Console - $asctime(yyyy-mm-dd HH:nn:ss)
    aline @IRCop 12,0 mIRC $version $+ , UnrealIRCd 6.5+ compatible
    aline @IRCop 12,0 $str(-,70)
  }
}

alias ircop.echo {
  ; Parameters: <color> <text>
  ; Echoes to @IRCop window with optional timestamp
  ircop.window
  var %ts = $null
  if ($hget(ircop_config,window.timestamp) == 1) {
    %ts = $+([,$asctime(HH:nn:ss),])
  }
  if ($1 isnum) {
    aline $1 @IRCop %ts $2-
  }
  else {
    aline @IRCop %ts $1-
  }

  ; Trim window if too many lines
  var %max = $hget(ircop_config,window.maxlines)
  if (!%max) { %max = 5000 }
  while ($line(@IRCop,0) > %max) {
    dline @IRCop 1
  }
}

; ---------------------
; OPER UP SYSTEM
; ---------------------
alias oper.up {
  ; Usage: /oper.up [name] [password]
  ; If no params, uses saved credentials
  var %name = $1
  var %pass = $2

  if (!%name) { %name = $hget(ircop_config,oper.name) }
  if (!%pass) { %pass = $hget(ircop_config,oper.pass) }

  if (!%name || !%pass) {
    ircop.echo 4 [ERROR] Oper credentials not configured. Use /ircop.setup or /oper.up <name> <pass>
    return
  }

  oper %name %pass
}

alias oper.down {
  ; Remove oper status (UnrealIRCd 6.5: MODE -o)
  mode $me -o
  hadd ircop_state is.oper 0
  ircop.echo 7 [OPER] You have de-opered.
}

; Auto oper-up on connect if configured
on *:CONNECT:{
  if ($hget(ircop_config,oper.auto) == 1) {
    .timer.operup 1 3 oper.up
  }

  ; Open IRCop window if configured
  if ($hget(ircop_config,window.auto) == 1) {
    ircop.window
  }
}

; ---------------------
; RAW NUMERIC HANDLERS (UnrealIRCd 6.5+)
; ---------------------

; RPL_YOUREOPER (381) - Successfully opered up
raw 381:*:{
  hadd ircop_state is.oper 1
  hadd ircop_state oper.time $ctime
  hadd ircop_state oper.network $network

  ircop.echo 3 [OPER] $2-

  ; Set oper user modes (UnrealIRCd 6.5 modes)
  var %modes = $hget(ircop_config,oper.modes)
  if (%modes) {
    mode $me %modes
  }

  ; Log it
  ircop.log OPER Opered up as $me on $server
}

; RPL_STATSLINKINFO (211) - Stats L
raw 211:*:{
  ircop.echo 10 [STATS-L] $2-
}

; RPL_STATSCOMMANDS (212) - Stats M
raw 212:*:{
  ircop.echo 10 [STATS-M] $2-
}

; RPL_STATSCLINE (213) - Stats C (server links)
raw 213:*:{
  ircop.echo 10 [STATS-C] $2-
}

; RPL_STATSOLINE (243) - Stats O (oper lines)
raw 243:*:{
  ircop.echo 10 [STATS-O] $2-
}

; RPL_STATSUPTIME (242) - Stats U (uptime)
raw 242:*:{
  ircop.echo 10 [UPTIME] $2-
}

; RPL_LUSERCLIENT (251) - Lusers info
raw 251:*:{
  ircop.echo 12 [LUSERS] $2-
}

; RPL_LUSEROP (252) - Number of opers
raw 252:*:{
  ircop.echo 12 [LUSERS] $2 operator(s) online
  hadd ircop_state oper.count $2
}

; RPL_LUSERUNKNOWN (253) - Unknown connections
raw 253:*:{
  ircop.echo 12 [LUSERS] $2 unknown connection(s)
}

; RPL_LUSERCHANNELS (254) - Number of channels
raw 254:*:{
  ircop.echo 12 [LUSERS] $2 channel(s) formed
}

; RPL_LUSERME (255) - Local client count
raw 255:*:{
  ircop.echo 12 [LUSERS] $2-
}

; RPL_LOCALUSERS (265) - Current/Max local users
raw 265:*:{
  ircop.echo 12 [LUSERS] Current local users: $2 Max: $3
  hadd ircop_state users.local $2
  hadd ircop_state users.local.max $3
}

; RPL_GLOBALUSERS (266) - Current/Max global users
raw 266:*:{
  ircop.echo 12 [LUSERS] Current global users: $2 Max: $3
  hadd ircop_state users.global $2
  hadd ircop_state users.global.max $3
}

; RPL_MAPMORE (610) / RPL_MAP (006) - Network map (UnrealIRCd 6.5)
raw 006:*:{
  ircop.echo 3 [MAP] $2-
}

raw 018:*:{
  ircop.echo 3 [MAP] End of /MAP
}

; RPL_STATS (Various) - End of stats
raw 219:*:{
  ircop.echo 10 [STATS] End of /STATS $2
}

; ---------------------
; SERVER NOTICE HANDLERS (UnrealIRCd 6.5+ SNOMask routing)
; ---------------------

; Catch server notices - UnrealIRCd 6.5 sends them via NOTICE with specific prefixes
on *:SNOTICE:*:{
  var %msg = $1-
  ircop.echo 7 [SNOTICE] %msg
  ircop.log SNOTICE %msg
  ircop.alert.check %msg
}

; Catch WALLOPS from opers/servers
on *:WALLOPS:*:{
  ircop.echo 4 [WALLOPS] $nick $+ : $1-
  ircop.log WALLOPS $nick $1-
}

; ---------------------
; NOTICE-BASED OPER NOTIFICATIONS (UnrealIRCd 6.5)
; ---------------------

; Catch server notices that come as NOTICE from server
on *:NOTICE:*:*:{
  if ($nick == $server || $wildsite == *!*@*) {
    ; This might be a server notice
    var %msg = $1-

    ; Client connecting
    if (*Client connecting* iswm %msg) {
      ircop.echo 3 [CONNECT] %msg
      ircop.log CONNECT %msg

      ; Track for clone detection - signal to monitor module
      .signal ircop.connect %msg
    }

    ; Client exiting
    elseif (*Client exiting* iswm %msg) {
      ircop.echo 7 [EXIT] %msg
      ircop.log EXIT %msg
      .signal ircop.exit %msg
    }

    ; Oper up
    elseif (*is now an operator* iswm %msg) {
      ircop.echo 9 [OPER-UP] %msg
      ircop.log OPER-UP %msg
    }

    ; Nick change
    elseif (*changed nickname* iswm %msg || *is now known as* iswm %msg) {
      ircop.echo 6 [NICK] %msg
      ircop.log NICK %msg
    }

    ; Kill
    elseif (*killed* iswm %msg || *KILL* iswm %msg) {
      ircop.echo 4 [KILL] %msg
      ircop.log KILL %msg
    }

    ; G-line / K-line / Z-line / Shun
    elseif (*line* iswm %msg || *GLINE* iswm %msg || *KLINE* iswm %msg || *ZLINE* iswm %msg) {
      ircop.echo 4 [BAN] %msg
      ircop.log BAN %msg
    }

    elseif (*Shun* iswm %msg || *SHUN* iswm %msg) {
      ircop.echo 4 [SHUN] %msg
      ircop.log SHUN %msg
    }

    ; Spamfilter
    elseif (*Spamfilter* iswm %msg || *SPAMFILTER* iswm %msg) {
      ircop.echo 4 [SPAMFILTER] %msg
      ircop.log SPAMFILTER %msg
    }

    ; Flood
    elseif (*flood* iswm %msg || *Flood* iswm %msg || *excess flood* iswm %msg) {
      ircop.echo 4 [FLOOD] %msg
      ircop.log FLOOD %msg
      .signal ircop.flood %msg
    }

    ; Link / Split
    elseif (*link* iswm %msg || *Netsplit* iswm %msg || *split* iswm %msg) {
      ircop.echo 4 [NETLINK] %msg
      ircop.log NETLINK %msg
    }
  }
}

; ---------------------
; LOGGING
; ---------------------
alias ircop.log {
  ; Parameters: <category> <message>
  if ($hget(ircop_config,log.enabled) != 1) { return }

  var %dir = $hget(ircop_config,log.dir)
  if (!%dir) { %dir = $scriptdirlogs }

  ; Ensure log directory exists
  if (!$isdir(%dir)) { mkdir %dir }

  var %file = $+(%dir,/,ircop-,$asctime(yyyy-mm-dd),.log)
  var %line = $+([,$asctime(HH:nn:ss),]) $+([,$1,]) $2-
  write %file %line
}

; ---------------------
; ALERT SYSTEM
; ---------------------
alias ircop.alert.check {
  ; Check incoming messages for alert-worthy patterns
  var %msg = $1-

  ; Flash taskbar if configured
  if ($hget(ircop_config,alert.flash) == 1) {
    if (!$appactive) { flash }
  }

  ; Play sound for critical events
  if ($hget(ircop_config,alert.sound) == 1) {
    if (*flood* iswm %msg || *KILL* iswm %msg || *Netsplit* iswm %msg) {
      ; Use system beep if no custom sound configured
      beep 1
    }
  }
}

; ---------------------
; STATUS & INFO COMMANDS
; ---------------------
alias ircop.status {
  ircop.echo 12 $str(=,60)
  ircop.echo 12 IRCop System Status Report
  ircop.echo 12 $str(=,60)
  ircop.echo 3 Oper Status: $iif($hget(ircop_state,is.oper) == 1,3OPERED,4NOT OPERED)
  if ($hget(ircop_state,is.oper) == 1) {
    ircop.echo 3 Oper Since: $asctime($hget(ircop_state,oper.time),yyyy-mm-dd HH:nn:ss)
  }
  ircop.echo 3 Server: $server
  ircop.echo 3 Network: $network
  ircop.echo 3 mIRC Version: $version
  ircop.echo 3 Local Users: $iif($hget(ircop_state,users.local),$v1,N/A) (Max: $iif($hget(ircop_state,users.local.max),$v1,N/A) $+ )
  ircop.echo 3 Global Users: $iif($hget(ircop_state,users.global),$v1,N/A) (Max: $iif($hget(ircop_state,users.global.max),$v1,N/A) $+ )
  ircop.echo 3 Logging: $iif($hget(ircop_config,log.enabled) == 1,Enabled,Disabled)
  ircop.echo 3 Auto-Oper: $iif($hget(ircop_config,oper.auto) == 1,Enabled,Disabled)
  ircop.echo 12 $str(=,60)
}

; Quick commands for UnrealIRCd 6.5 info
alias ircop.lusers { lusers }
alias ircop.map { map }
alias ircop.modules { raw MODULE }
alias ircop.uptime { stats u }
alias ircop.opers { stats P }
alias ircop.links { links }

; ---------------------
; OPER MODE MANAGEMENT (UnrealIRCd 6.5 snomasks)
; ---------------------
alias ircop.snomask {
  ; Usage: /ircop.snomask <modes>
  ; UnrealIRCd 6.5 snomasks: c=connects, f=flood, k=kills, s=server,
  ; o=oper, j=junk, G=gline, n=nick, q=reject, S=spamfilter, e=eyes
  if (!$1) {
    ircop.echo 7 Usage: /ircop.snomask <+/-modes>
    ircop.echo 7 UnrealIRCd 6.5 snomasks: c(onnects) f(lood) F(lood-alerts)
    ircop.echo 7   k(ills) s(erver) o(per) j(unk) G(line) n(ick) q(reject)
    ircop.echo 7   S(pamfilter) e(yes/oper-override) v(irus/dcc-reject)
    return
  }
  mode $me +s $1
}

; ---------------------
; CONFIGURATION DIALOG
; ---------------------
alias ircop.setup {
  dialog -m ircop_setup ircop_setup
}

dialog ircop_setup {
  title "IRCop System Configuration"
  size -1 -1 340 380
  option pixels

  ; Oper Settings
  text "Oper Name:", 1, 15 15 80 20
  edit "", 10, 100 12 220 22
  text "Oper Password:", 2, 15 42 80 20
  edit "", 11, 100 39 220 22, pass
  check "Auto Oper-Up on Connect", 12, 15 68 200 20
  text "Oper Modes:", 3, 15 93 80 20
  edit "", 13, 100 90 220 22

  ; Window Settings
  box "Window Settings", 20, 10 120 320 75
  check "Auto-open @IRCop Window", 21, 20 140 200 20
  check "Show Timestamps", 22, 20 160 200 20
  text "Max Lines:", 23, 20 183 70 18
  edit "", 24, 95 180 60 22

  ; Logging
  box "Logging", 30, 10 200 320 55
  check "Enable Logging", 31, 20 218 150 20
  text "Log Dir:", 32, 20 240 50 18
  edit "", 33, 75 237 240 22

  ; Alerts
  box "Alerts", 40, 10 260 320 55
  check "Flash on Alerts", 41, 20 278 130 20
  check "Sound on Alerts", 42, 160 278 130 20
  text "Clone Threshold:", 43, 20 300 95 18
  edit "", 44, 120 297 40 22

  ; Buttons
  button "Save", 100, 80 335 80 28, ok
  button "Cancel", 101, 180 335 80 28, cancel
}

on *:DIALOG:ircop_setup:init:0:{
  did -a ircop_setup 10 $hget(ircop_config,oper.name)
  did -a ircop_setup 11 $hget(ircop_config,oper.pass)
  if ($hget(ircop_config,oper.auto) == 1) { did -c ircop_setup 12 }
  did -a ircop_setup 13 $hget(ircop_config,oper.modes)

  if ($hget(ircop_config,window.auto) == 1) { did -c ircop_setup 21 }
  if ($hget(ircop_config,window.timestamp) == 1) { did -c ircop_setup 22 }
  did -a ircop_setup 24 $iif($hget(ircop_config,window.maxlines),$v1,5000)

  if ($hget(ircop_config,log.enabled) == 1) { did -c ircop_setup 31 }
  did -a ircop_setup 33 $iif($hget(ircop_config,log.dir),$v1,$scriptdirlogs)

  if ($hget(ircop_config,alert.flash) == 1) { did -c ircop_setup 41 }
  if ($hget(ircop_config,alert.sound) == 1) { did -c ircop_setup 42 }
  did -a ircop_setup 44 $iif($hget(ircop_config,alert.clones),$v1,3)
}

on *:DIALOG:ircop_setup:sclick:100:{
  hadd ircop_config oper.name $did(ircop_setup,10)
  hadd ircop_config oper.pass $did(ircop_setup,11)
  hadd ircop_config oper.auto $iif($did(ircop_setup,12).state == 1,1,0)
  hadd ircop_config oper.modes $did(ircop_setup,13)

  hadd ircop_config window.auto $iif($did(ircop_setup,21).state == 1,1,0)
  hadd ircop_config window.timestamp $iif($did(ircop_setup,22).state == 1,1,0)
  hadd ircop_config window.maxlines $did(ircop_setup,24)

  hadd ircop_config log.enabled $iif($did(ircop_setup,31).state == 1,1,0)
  hadd ircop_config log.dir $did(ircop_setup,33)

  hadd ircop_config alert.flash $iif($did(ircop_setup,41).state == 1,1,0)
  hadd ircop_config alert.sound $iif($did(ircop_setup,42).state == 1,1,0)
  hadd ircop_config alert.clones $did(ircop_setup,44)

  ircop.saveconfig
  ircop.echo 3 [CONFIG] Settings saved successfully.
}

; ---------------------
; RIGHT-CLICK MENUS
; ---------------------
menu channel,nicklist,query {
  IRCop System
  .Open Console:/ircop.window
  .Status:/ircop.status
  .-
  .Oper Up:/oper.up
  .Oper Down:/oper.down
  .-
  .Setup:/ircop.setup
  .-
  .Refresh Lusers:/ircop.lusers
  .Network Map:/ircop.map
  .Server Uptime:/ircop.uptime
  .Online Opers:/ircop.opers
}

menu nicklist {
  -
  IRCop Actions
  .Whois:whois $$1 $$1
  .User Info:/ircop.userinfo $$1
  .-
  .Kill (Quick):/ircop.kill $$1 IRCop Action
  .Kill (Reason):/ircop.kill $$1 $$?="Enter kill reason:"
  .-
  .G-line (Host):/ircop.gline.nick $$1 1h $$?="Enter G-line reason:"
  .K-line (Host):/ircop.kline.nick $$1 $$?="Enter K-line reason:"
  .Z-line (IP):/ircop.zline.nick $$1 1h $$?="Enter Z-line reason:"
  .Shun:/ircop.shun.nick $$1 1h $$?="Enter shun reason:"
  .-
  .SAJOIN:/ircop.sajoin $$1 $$?="Channel to force-join:"
  .SAPART:/ircop.sapart $$1 $$?="Channel to force-part:"
  .SANICK:/ircop.sanick $$1 $$?="New nickname:"
}

; ---------------------
; UTILITY IDENTIFIERS
; ---------------------

; Check if we are currently opered
alias ircop.isopered {
  return $iif($hget(ircop_state,is.oper) == 1,$true,$false)
}

; Get oper configuration value
alias ircop.cfg {
  return $hget(ircop_config,$1)
}

; Get runtime state value
alias ircop.state {
  return $hget(ircop_state,$1)
}

; Get kill/ban reason template
alias ircop.template {
  return $hget(ircop_templates,$1)
}

; Format duration for display (seconds -> human readable)
alias ircop.duration {
  var %s = $1
  if (%s < 60) { return %s $+ s }
  if (%s < 3600) { return $calc(%s / 60) $+ m $calc(%s % 60) $+ s }
  if (%s < 86400) { return $calc(%s / 3600) $+ h $calc((%s % 3600) / 60) $+ m }
  return $calc(%s / 86400) $+ d $calc((%s % 86400) / 3600) $+ h
}

; Extract host from full address (nick!user@host)
alias ircop.gethost {
  return $gettok($1,2,64)
}

; Extract IP-based mask from address
alias ircop.getmask {
  var %addr = $1
  if ($gettok(%addr,2,64)) {
    return *!*@ $+ $gettok(%addr,2,64)
  }
  return %addr
}

; ---------------------
; HELP COMMAND
; ---------------------
alias ircop.help {
  ircop.window
  ircop.echo 12 $str(=,60)
  ircop.echo 12 IRCop System Help - mIRC 7.72+ / UnrealIRCd 6.5+
  ircop.echo 12 $str(=,60)
  ircop.echo 7 CORE COMMANDS:
  ircop.echo 3  /ircop.setup - Open configuration dialog
  ircop.echo 3  /ircop.status - Show system status
  ircop.echo 3  /ircop.window - Open @IRCop console
  ircop.echo 3  /oper.up [name] [pass] - Oper up
  ircop.echo 3  /oper.down - Remove oper status
  ircop.echo 3  /ircop.snomask <modes> - Set snomask modes
  ircop.echo 3  /ircop.help - This help message
  ircop.echo 7 INFO COMMANDS:
  ircop.echo 3  /ircop.lusers - Network user counts
  ircop.echo 3  /ircop.map - Network server map
  ircop.echo 3  /ircop.uptime - Server uptime
  ircop.echo 3  /ircop.opers - Online operators
  ircop.echo 3  /ircop.links - Server links
  ircop.echo 7 USER MANAGEMENT (ircop-usermgmt.mrc):
  ircop.echo 3  /ircop.kill <nick> <reason> - Kill a user
  ircop.echo 3  /ircop.gline <mask> <duration> <reason> - Add G-line
  ircop.echo 3  /ircop.kline <mask> <reason> - Add K-line
  ircop.echo 3  /ircop.zline <mask> <duration> <reason> - Add Z-line
  ircop.echo 3  /ircop.shun <mask> <duration> <reason> - Add shun
  ircop.echo 3  /ircop.spamfilter - Spamfilter management
  ircop.echo 3  /ircop.sajoin <nick> <channel> - Force join
  ircop.echo 3  /ircop.sapart <nick> <channel> - Force part
  ircop.echo 3  /ircop.sanick <nick> <newnick> - Force nick change
  ircop.echo 3  /ircop.samode <channel> <modes> - Force channel mode
  ircop.echo 7 MONITORING (ircop-monitor.mrc):
  ircop.echo 3  /ircop.clones - Show clone report
  ircop.echo 3  /ircop.search <pattern> - Search users
  ircop.echo 3  /ircop.stats <letter> - Query server stats
  ircop.echo 3  /ircop.dashboard - Network dashboard
  ircop.echo 3  /ircop.log.view - View recent log entries
  ircop.echo 12 $str(=,60)
}

; End of ircop-core.mrc
