; =============================================================================
; IRCop Monitoring & Logging - ircop-monitor.mrc
; Compatible with: mIRC 7.72+ | UnrealIRCd 6.5+
; Description: Clone detection, flood monitoring, server stats dashboard,
;              user search, activity logging, network health alerts
; Part of the IRCop System (3-file set): ircop-core / ircop-usermgmt / ircop-monitor
; =============================================================================

; ---------------------
; INITIALIZATION
; ---------------------
on *:START:{
  ; Hash tables for monitoring data
  if (!$hget(ircop_hosts))   { hmake ircop_hosts 500 }
  if (!$hget(ircop_ips))     { hmake ircop_ips 500 }
  if (!$hget(ircop_connects)) { hmake ircop_connects 200 }
  if (!$hget(ircop_nicktrack)) { hmake ircop_nicktrack 200 }
  if (!$hget(ircop_floodtrack)) { hmake ircop_floodtrack 100 }

  ; Start periodic cleanup timer (every 15 minutes)
  .timerircop.cleanup 0 900 ircop.monitor.cleanup

  echo -s 4[IRCop System] Monitoring module loaded.
}

on *:UNLOAD:{
  ; Stop timers
  .timerircop.cleanup off
  .timerircop.connrate off
  .timerircop.dashboard off

  ; Free hash tables
  if ($hget(ircop_hosts))     { hfree ircop_hosts }
  if ($hget(ircop_ips))       { hfree ircop_ips }
  if ($hget(ircop_connects))  { hfree ircop_connects }
  if ($hget(ircop_nicktrack)) { hfree ircop_nicktrack }
  if ($hget(ircop_floodtrack)) { hfree ircop_floodtrack }

  echo -s 4[IRCop System] Monitoring module unloaded.
}

; ==============================
; CLONE DETECTION SYSTEM
; ==============================

; Signal handler for client connections (from ircop-core)
on *:SIGNAL:ircop.connect:{
  var %msg = $1-

  ; Parse connection message from UnrealIRCd 6.5
  ; Format: "Client connecting: nick (user@host) [ip] {class} [info] [account]"
  ; or similar format depending on snomask configuration
  var %nick = $null
  var %host = $null
  var %ip = $null

  ; Try to extract nick, host, and IP using regex
  ; UnrealIRCd 6.5 format: Client connecting: Nick (user@host) [IP] {class}
  if ($regex(%msg,/Client connecting:?\s+(\S+)\s+\((\S+)@(\S+)\)\s+\[(\S+)\]/)) {
    %nick = $regml(1)
    var %user = $regml(2)
    %host = $regml(3)
    %ip = $regml(4)
  }
  ; Alternate format parsing
  elseif ($regex(%msg,/Client connecting:?\s+(\S+)\s+\(([^)]+)\)\s+\[([^\]]+)\]/)) {
    %nick = $regml(1)
    %host = $regml(2)
    %ip = $regml(3)
  }

  if (!%nick || !%host) { return }

  ; Track host count
  var %hostcount = $hget(ircop_hosts,%host)
  if (!%hostcount) { %hostcount = 0 }
  inc %hostcount
  hadd ircop_hosts %host %hostcount

  ; Track IP count
  if (%ip) {
    var %ipcount = $hget(ircop_ips,%ip)
    if (!%ipcount) { %ipcount = 0 }
    inc %ipcount
    hadd ircop_ips %ip %ipcount
  }

  ; Track connection timestamps (for rate detection)
  hadd ircop_connects %nick $ctime

  ; Clone threshold check
  var %threshold = $hget(ircop_config,alert.clones)
  if (!%threshold) { %threshold = 3 }

  if (%hostcount >= %threshold) {
    ircop.echo 4 [CLONES] Alert: %hostcount connections from host %host (latest: %nick $+ )
    ircop.log CLONES Alert: %hostcount from %host (nick: %nick $+ )

    ; Sound alert
    if ($hget(ircop_config,alert.sound) == 1) { beep 2 }
    if ($hget(ircop_config,alert.flash) == 1 && !$appactive) { flash }
  }

  if (%ip && %ipcount >= %threshold) {
    ircop.echo 4 [CLONES] Alert: %ipcount connections from IP %ip (latest: %nick $+ )
    ircop.log CLONES Alert: %ipcount from IP %ip (nick: %nick $+ )
  }
}

; Signal handler for client disconnections
on *:SIGNAL:ircop.exit:{
  var %msg = $1-

  ; Parse exit message - UnrealIRCd 6.5 format
  ; "Client exiting: Nick (user@host) [IP] {class} [reason]"
  if ($regex(%msg,/Client exiting:?\s+(\S+)\s+\((\S+)@(\S+)\)\s+\[(\S+)\]/)) {
    var %nick = $regml(1)
    var %host = $regml(3)
    var %ip = $regml(4)

    ; Decrement host counter
    var %hostcount = $hget(ircop_hosts,%host)
    if (%hostcount > 1) {
      hadd ircop_hosts %host $calc(%hostcount - 1)
    }
    elseif (%hostcount) {
      hdel ircop_hosts %host
    }

    ; Decrement IP counter
    if (%ip) {
      var %ipcount = $hget(ircop_ips,%ip)
      if (%ipcount > 1) {
        hadd ircop_ips %ip $calc(%ipcount - 1)
      }
      elseif (%ipcount) {
        hdel ircop_ips %ip
      }
    }

    ; Remove from connect tracking
    if ($hget(ircop_connects,%nick)) { hdel ircop_connects %nick }
  }
}

; Signal handler for flood events
on *:SIGNAL:ircop.flood:{
  var %msg = $1-
  var %time = $ctime

  ; Track flood events for rate analysis
  var %floodcount = $hget(ircop_floodtrack,count)
  if (!%floodcount) { %floodcount = 0 }
  inc %floodcount
  hadd ircop_floodtrack count %floodcount
  hadd ircop_floodtrack last %time
  hadd ircop_floodtrack $+(flood.,%floodcount) %msg

  ; If flood rate is high, escalate alert
  if (%floodcount > 10) {
    ircop.echo 4 [FLOOD] HIGH FLOOD RATE: %floodcount flood events detected
    ircop.log FLOOD High rate: %floodcount events
  }
}

; ==============================
; CLONE REPORT COMMANDS
; ==============================
alias ircop.clones {
  ; Usage: /ircop.clones [threshold]
  ; Show hosts/IPs with multiple connections
  var %threshold = $iif($1,$1,2)

  ircop.echo 12 $str(=,60)
  ircop.echo 12 Clone Report (threshold: %threshold $+ + connections)
  ircop.echo 12 $str(=,60)

  var %found = 0

  ; Check hosts
  if ($hget(ircop_hosts,0).item > 0) {
    var %i = 1
    while ($hget(ircop_hosts,%i).item) {
      var %host = $hget(ircop_hosts,%i).item
      var %count = $hget(ircop_hosts,%host)
      if (%count >= %threshold) {
        ircop.echo 4 [HOST] %host $+ : %count connection(s)
        inc %found
      }
      inc %i
    }
  }

  ; Check IPs
  if ($hget(ircop_ips,0).item > 0) {
    var %i = 1
    while ($hget(ircop_ips,%i).item) {
      var %ip = $hget(ircop_ips,%i).item
      var %count = $hget(ircop_ips,%ip)
      if (%count >= %threshold) {
        ircop.echo 4 [IP] %ip $+ : %count connection(s)
        inc %found
      }
      inc %i
    }
  }

  if (%found == 0) {
    ircop.echo 3 No clones detected above threshold of %threshold
  }
  else {
    ircop.echo 7 Total entries above threshold: %found
  }
  ircop.echo 12 $str(=,60)
}

alias ircop.clones.kill {
  ; Usage: /ircop.clones.kill <host-or-ip> <reason>
  ; Kill all users matching a specific host
  if ($0 < 2) {
    ircop.echo 4 Usage: /ircop.clones.kill <host-or-ip> <reason>
    return
  }
  var %host = $1
  var %reason = $2-

  ; Use WHO to find matching users, then kill
  ; This triggers a WHO lookup, results handled by raw 352/354
  hadd ircop_state clone.kill.host %host
  hadd ircop_state clone.kill.reason %reason
  hadd ircop_state clone.kill.count 0

  ; UnrealIRCd 6.5 supports WHO with extended matching
  raw WHO %host
  ircop.echo 7 [CLONES] Looking up users matching %host for kill...
}

; WHO response handler for clone kill (RPL_WHOREPLY 352)
raw 352:*:{
  var %killhost = $hget(ircop_state,clone.kill.host)
  if (%killhost) {
    ; $2=chan, $3=user, $4=host, $5=server, $6=nick, $7=flags, $8-=hopcount realname
    var %nick = $6
    var %host = $4

    if (%killhost iswm %host || %killhost == %host) {
      if (%nick != $me) {
        var %reason = $hget(ircop_state,clone.kill.reason)
        kill %nick %reason
        var %count = $hget(ircop_state,clone.kill.count)
        inc %count
        hadd ircop_state clone.kill.count %count
        ircop.echo 4 [CLONES] Killed %nick ( $+ %host $+ )
      }
    }
  }
}

; End of WHO (315)
raw 315:*:{
  var %killhost = $hget(ircop_state,clone.kill.host)
  if (%killhost) {
    var %count = $hget(ircop_state,clone.kill.count)
    ircop.echo 4 [CLONES] Clone kill complete: %count users killed from %killhost
    ircop.log CLONES Killed %count from %killhost
    hdel ircop_state clone.kill.host
    hdel ircop_state clone.kill.reason
    hdel ircop_state clone.kill.count
  }

  ; Also handle user search
  var %searchactive = $hget(ircop_state,search.active)
  if (%searchactive) {
    var %count = $hget(ircop_state,search.count)
    ircop.echo 12 [SEARCH] Search complete: %count result(s)
    ircop.echo 12 $str(=,50)
    hdel ircop_state search.active
    hdel ircop_state search.count
    hdel ircop_state search.pattern
  }
}

; ==============================
; USER SEARCH
; ==============================
alias ircop.search {
  ; Usage: /ircop.search <pattern>
  ; Searches for users matching a nick!user@host pattern
  ; Uses WHO with wildcard matching
  if (!$1) {
    ircop.echo 4 Usage: /ircop.search <nick-or-host-pattern>
    ircop.echo 7 Examples: /ircop.search *bot*  or  /ircop.search *.bad.host.com
    return
  }
  var %pattern = $1

  hadd ircop_state search.active 1
  hadd ircop_state search.count 0
  hadd ircop_state search.pattern %pattern

  ircop.echo 12 $str(=,50)
  ircop.echo 12 Searching for: %pattern
  ircop.echo 12 $str(=,50)

  ; UnrealIRCd 6.5 WHO supports extended matching
  raw WHO %pattern
}

; WHO response handler for user search
; Re-uses raw 352 but checks for search.active state
; We need a separate handling approach - use WHOX (354) if available
raw 354:*:{
  ; WHOX response - UnrealIRCd 6.5 supports this
  ; Format depends on the WHO query flags used
  if ($hget(ircop_state,search.active)) {
    ircop.echo 3 [MATCH] $2-
    var %count = $hget(ircop_state,search.count)
    inc %count
    hadd ircop_state search.count %count
  }
}

alias ircop.search.account {
  ; Usage: /ircop.search.account <account-name>
  ; Search users by services account (UnrealIRCd 6.5 WHO extended)
  if (!$1) {
    ircop.echo 4 Usage: /ircop.search.account <account-name>
    return
  }
  hadd ircop_state search.active 1
  hadd ircop_state search.count 0
  hadd ircop_state search.pattern account: $+ $1

  ircop.echo 12 $str(=,50)
  ircop.echo 12 Searching by account: $1
  ircop.echo 12 $str(=,50)

  ; WHO with account matching (UnrealIRCd 6.5)
  raw WHO $1 a
}

alias ircop.search.realname {
  ; Usage: /ircop.search.realname <pattern>
  if (!$1) {
    ircop.echo 4 Usage: /ircop.search.realname <pattern>
    return
  }
  hadd ircop_state search.active 1
  hadd ircop_state search.count 0
  hadd ircop_state search.pattern realname: $+ $1

  ircop.echo 12 $str(=,50)
  ircop.echo 12 Searching by realname: $1
  ircop.echo 12 $str(=,50)

  ; UnrealIRCd 6.5 WHO with realname matching
  raw WHO $1 r
}

; ==============================
; SERVER STATISTICS
; ==============================
alias ircop.stats {
  ; Usage: /ircop.stats <letter>
  ; UnrealIRCd 6.5 STATS letters:
  ;  c - Server link info        e - E-lines (ban exceptions)
  ;  f - Spamfilter stats        G - G-lines
  ;  g - G-line stats            k - K-lines
  ;  I - I-lines (allow blocks)  K - K-lines (old style)
  ;  l - Link info               L - Link info (detailed)
  ;  m - Command usage stats     O - Oper blocks
  ;  P - Ports/listeners         q - SQL-lines (nick restrictions)
  ;  Q - SQL-lines               s - Shuns
  ;  S - Set blocks (dynamic)    t - Traffic stats
  ;  u - Server uptime           Z - Z-lines
  ;  z - Memory usage stats      F - Spamfilters

  if (!$1) {
    ircop.echo 7 Usage: /ircop.stats <letter>
    ircop.echo 7 UnrealIRCd 6.5 STATS letters:
    ircop.echo 3  c - Server link config    e - E-lines (exceptions)
    ircop.echo 3  F - Spamfilters           G - G-lines
    ircop.echo 3  k - K-lines              l/L - Link info
    ircop.echo 3  m - Command usage         O - Oper blocks
    ircop.echo 3  P - Ports/Listeners       s - Shuns
    ircop.echo 3  t - Traffic stats         u - Server uptime
    ircop.echo 3  Z - Z-lines              z - Memory/resource usage
    return
  }
  raw STATS $1
  ircop.echo 7 [STATS] Requesting STATS $1 ...
}

alias ircop.stats.bans {
  ; Show all ban-type stats at once
  ircop.echo 12 [STATS] Requesting all ban lists...
  raw STATS G
  .timer 1 1 raw STATS k
  .timer 1 2 raw STATS Z
  .timer 1 3 raw STATS s
  .timer 1 4 raw STATS e
  .timer 1 5 raw STATS F
}

; ==============================
; NETWORK DASHBOARD
; ==============================
alias ircop.dashboard {
  ; Display a comprehensive network status dashboard
  ircop.echo 12 $str(=,60)
  ircop.echo 12  NETWORK DASHBOARD - $asctime(yyyy-mm-dd HH:nn:ss)
  ircop.echo 12 $str(=,60)

  ; Connection status
  ircop.echo 7 CONNECTION:
  ircop.echo 3  Server: $server $+  $+ ( $+ $network $+ )
  ircop.echo 3  Oper Status: $iif($hget(ircop_state,is.oper) == 1,3OPERED,4NOT OPERED)
  if ($hget(ircop_state,oper.time)) {
    ircop.echo 3  Oper Duration: $ircop.duration($calc($ctime - $hget(ircop_state,oper.time)))
  }

  ; User counts
  ircop.echo 7 USERS:
  ircop.echo 3  Local: $iif($hget(ircop_state,users.local),$v1,?) / $iif($hget(ircop_state,users.local.max),$v1,?)
  ircop.echo 3  Global: $iif($hget(ircop_state,users.global),$v1,?) / $iif($hget(ircop_state,users.global.max),$v1,?)
  ircop.echo 3  Opers Online: $iif($hget(ircop_state,oper.count),$v1,?)

  ; Monitoring stats
  ircop.echo 7 MONITORING:
  ircop.echo 3  Tracked Hosts: $hget(ircop_hosts,0).item
  ircop.echo 3  Tracked IPs: $hget(ircop_ips,0).item
  ircop.echo 3  Flood Events: $iif($hget(ircop_floodtrack,count),$v1,0)

  ; Clone summary
  var %clonecount = 0
  var %threshold = $iif($hget(ircop_config,alert.clones),$v1,3)
  var %i = 1
  while ($hget(ircop_hosts,%i).item) {
    if ($hget(ircop_hosts,$hget(ircop_hosts,%i).item) >= %threshold) { inc %clonecount }
    inc %i
  }
  ircop.echo 3  Clone Alerts (>= $+ %threshold $+ ): %clonecount host(s)

  ; System info
  ircop.echo 7 SYSTEM:
  ircop.echo 3  mIRC: $version
  ircop.echo 3  Uptime: $ircop.duration($calc($ctime - $uptime(system,3)))
  ircop.echo 3  Logging: $iif($hget(ircop_config,log.enabled) == 1,Enabled,Disabled)

  ircop.echo 12 $str(=,60)

  ; Trigger a lusers refresh for updated counts
  lusers
}

alias ircop.dashboard.auto {
  ; Usage: /ircop.dashboard.auto [interval-seconds]
  ; Start/stop auto-refreshing dashboard
  var %interval = $iif($1,$1,300)

  if ($timer(ircop.dashboard)) {
    .timerircop.dashboard off
    ircop.echo 3 [DASHBOARD] Auto-refresh stopped
  }
  else {
    .timerircop.dashboard 0 %interval ircop.dashboard
    ircop.echo 3 [DASHBOARD] Auto-refresh every %interval seconds
  }
}

; ==============================
; CONNECTION RATE MONITOR
; ==============================
alias ircop.connrate {
  ; Usage: /ircop.connrate [on|off] [interval-seconds]
  ; Monitor connection rate per time interval
  if ($1 == off) {
    .timerircop.connrate off
    ircop.echo 3 [CONNRATE] Connection rate monitoring stopped
    return
  }

  var %interval = $iif($2,$2,60)
  hadd ircop_state connrate.count 0
  hadd ircop_state connrate.interval %interval

  .timerircop.connrate 0 %interval ircop.connrate.report

  ircop.echo 3 [CONNRATE] Monitoring connection rate (interval: %interval $+ s)
}

alias ircop.connrate.report {
  var %count = $iif($hget(ircop_state,connrate.count),$v1,0)
  var %interval = $hget(ircop_state,connrate.interval)

  ircop.echo 7 [CONNRATE] %count connections in last %interval $+ s ( $+ $round($calc(%count / %interval * 60),1) /min)

  ; Reset counter
  hadd ircop_state connrate.count 0

  ; Alert on high rate
  if (%count > 50) {
    ircop.echo 4 [CONNRATE] WARNING: High connection rate detected!
    ircop.log CONNRATE High rate alert: %count in %interval $+ s
  }
}

; ==============================
; NICK CHANGE TRACKING
; ==============================
on *:NICK:{
  ; Track nick changes for suspicious activity detection
  var %old = $nick
  var %new = $newnick
  var %addr = $address(%old,2)

  ; Store last N nick changes for this host
  var %key = $+(nicktrack.,%addr)
  var %history = $hget(ircop_nicktrack,%key)
  hadd ircop_nicktrack %key $+(%old,->,%new) %history

  ; Count rapid nick changes (potential evasion)
  var %countkey = $+(nickcount.,%addr)
  var %count = $hget(ircop_nicktrack,%countkey)
  if (!%count) { %count = 0 }
  inc %count
  hadd ircop_nicktrack %countkey %count

  ; Alert on rapid nick changes (5+ in tracking period)
  if (%count >= 5) {
    ircop.echo 4 [NICKFLOOD] Rapid nick changes from %addr $+ : %count changes (latest: %old -> %new $+ )
    ircop.log NICKFLOOD %addr %count changes
  }
}

; ==============================
; LOG VIEWER
; ==============================
alias ircop.log.view {
  ; Usage: /ircop.log.view [lines] [date]
  ; View recent log entries in @IRCop window
  var %lines = $iif($1,$1,50)
  var %date = $iif($2,$2,$asctime(yyyy-mm-dd))
  var %dir = $iif($hget(ircop_config,log.dir),$v1,$scriptdirlogs)
  var %file = $+(%dir,/,ircop-,%date,.log)

  if (!$isfile(%file)) {
    ircop.echo 4 [LOG] No log file found for %date
    return
  }

  ircop.echo 12 $str(=,60)
  ircop.echo 12 Log Viewer - %date (last %lines lines)
  ircop.echo 12 $str(=,60)

  ; Read last N lines from log file
  var %total = $lines(%file,0)
  var %start = $calc(%total - %lines + 1)
  if (%start < 1) { %start = 1 }

  var %i = %start
  while (%i <= %total) {
    var %line = $read(%file,%i)
    ircop.echo 7 %line
    inc %i
  }

  ircop.echo 12 $str(=,60)
  ircop.echo 12 Showing lines %start to %total of %total total
}

alias ircop.log.search {
  ; Usage: /ircop.log.search <pattern> [date]
  ; Search log file for matching entries
  if (!$1) {
    ircop.echo 4 Usage: /ircop.log.search <pattern> [date]
    return
  }
  var %pattern = $1
  var %date = $iif($2,$2,$asctime(yyyy-mm-dd))
  var %dir = $iif($hget(ircop_config,log.dir),$v1,$scriptdirlogs)
  var %file = $+(%dir,/,ircop-,%date,.log)

  if (!$isfile(%file)) {
    ircop.echo 4 [LOG] No log file found for %date
    return
  }

  ircop.echo 12 $str(=,50)
  ircop.echo 12 Log Search: " $+ %pattern $+ " in %date
  ircop.echo 12 $str(=,50)

  var %total = $lines(%file,0)
  var %found = 0
  var %i = 1
  while (%i <= %total) {
    var %line = $read(%file,%i)
    if (%pattern iswm %line || $regex(%line,$+(.*,%pattern,.*))) {
      ircop.echo 3 [Line %i $+ ] %line
      inc %found
    }
    inc %i
  }

  ircop.echo 12 Found %found match(es)
  ircop.echo 12 $str(=,50)
}

alias ircop.log.clear {
  ; Usage: /ircop.log.clear [date]
  ; Clear a specific day's log
  var %date = $iif($1,$1,$asctime(yyyy-mm-dd))
  var %dir = $iif($hget(ircop_config,log.dir),$v1,$scriptdirlogs)
  var %file = $+(%dir,/,ircop-,%date,.log)

  if ($isfile(%file)) {
    .remove %file
    ircop.echo 3 [LOG] Cleared log for %date
  }
  else {
    ircop.echo 7 [LOG] No log file found for %date
  }
}

; ==============================
; NETWORK EVENT MONITORING
; ==============================

; Track JOINs for monitoring channels of interest
on *:JOIN:#:{
  ; Only process if oper monitoring is active
  if ($hget(ircop_state,is.oper) != 1) { return }

  ; Track in connect list if not self
  if ($nick != $me) {
    hadd ircop_connects $+(join.,$nick,.,#) $ctime
  }
}

; Track QUITs with reason analysis
on *:QUIT:{
  var %reason = $1-
  ; Check for suspicious quit reasons
  if (*Excess Flood* iswm %reason) {
    ircop.echo 4 [QUIT/FLOOD] $nick quit: %reason
  }
  elseif (*Killed* iswm %reason) {
    ircop.echo 4 [QUIT/KILL] $nick quit: %reason
  }
  elseif (*K-lined* iswm %reason || *G-lined* iswm %reason || *Z-lined* iswm %reason) {
    ircop.echo 4 [QUIT/BAN] $nick quit: %reason
  }
}

; Track KICKs
on *:KICK:#:{
  if ($hget(ircop_state,is.oper) == 1) {
    ircop.log KICK $knick kicked from # by $nick ( $+ $1- $+ )
  }
}

; Track MODE changes on monitored channels
on *:MODE:#:{
  if ($hget(ircop_state,is.oper) == 1) {
    ; Log all mode changes when opered
    ircop.log MODE # $nick sets $1-
  }
}

; ==============================
; CLEANUP & MAINTENANCE
; ==============================
alias ircop.monitor.cleanup {
  ; Periodic cleanup of stale tracking data

  ; Clean old nick tracking data (clear counts, they accumulate over time)
  if ($hget(ircop_nicktrack,0).item > 0) {
    var %i = $hget(ircop_nicktrack,0).item
    while (%i > 0) {
      var %key = $hget(ircop_nicktrack,%i).item
      if ($left(%key,10) == nickcount.) {
        hdel ircop_nicktrack %key
      }
      dec %i
    }
  }

  ; Reset flood tracking periodically
  if ($hget(ircop_floodtrack,count)) {
    hadd ircop_floodtrack count 0
  }

  ; Trim connect tracking (remove entries older than 1 hour)
  var %cutoff = $calc($ctime - 3600)
  if ($hget(ircop_connects,0).item > 0) {
    var %i = $hget(ircop_connects,0).item
    while (%i > 0) {
      var %key = $hget(ircop_connects,%i).item
      var %val = $hget(ircop_connects,%key)
      if (%val isnum && %val < %cutoff) {
        hdel ircop_connects %key
      }
      dec %i
    }
  }
}

; ==============================
; QUICK ACTION COMMANDS
; ==============================
alias ircop.gline.clones {
  ; Usage: /ircop.gline.clones <host> <duration> <reason>
  ; G-line a host that has been detected as clones
  if ($0 < 3) {
    ircop.echo 4 Usage: /ircop.gline.clones <host> <duration> <reason>
    return
  }
  var %host = $1
  var %dur = $2
  var %reason = $3-
  var %mask = *!*@ $+ %host

  raw GLINE %mask %dur : $+ %reason
  ircop.echo 4 [GLINE-CLONES] G-lined %mask for %dur $+ : %reason
  ircop.log GLINE-CLONES %mask %dur %reason
}

; ==============================
; SERVER NOTICE FORMAT HANDLERS
; UnrealIRCd 6.5 specific numeric formats
; ==============================

; RPL_STATSGLINE (223) - G-line stats
raw 223:*:{
  ircop.echo 4 [GLINE] $2-
}

; RPL_STATSSHUN (228) - Shun stats
raw 228:*:{
  ircop.echo 4 [SHUN] $2-
}

; RPL_STATSSPAMF (229) - Spamfilter entry
raw 229:*:{
  ircop.echo 4 [SPAMFILTER] $2-
}

; RPL_STATSKLINE (216) - K-line stats
raw 216:*:{
  ircop.echo 4 [KLINE] $2-
}

; RPL_STATSZLINE (225) - Z-line stats (UnrealIRCd uses various for this)
raw 225:*:{
  ircop.echo 4 [ZLINE] $2-
}

; RPL_STATSELINE (223 variant / 225) - E-line stats
raw 247:*:{
  ircop.echo 3 [ELINE] $2-
}

; RPL_STATSDEBUG / traffic (various)
raw 249:*:{
  ircop.echo 10 [STATS] $2-
}

; ==============================
; MONITORING RIGHT-CLICK MENU
; ==============================
menu channel,nicklist,query {
  IRCop Monitor
  .Dashboard:/ircop.dashboard
  .Clone Report:/ircop.clones
  .Clone Report (2+):/ircop.clones 2
  .-
  .Connection Rate (On):/ircop.connrate on
  .Connection Rate (Off):/ircop.connrate off
  .-
  .Auto Dashboard (On):/ircop.dashboard.auto
  .Auto Dashboard (Off):/ircop.dashboard.auto 0
  .-
  .View Log:/ircop.log.view
  .Search Log:/ircop.log.search $$?="Search pattern:"
  .-
  .All Ban Stats:/ircop.stats.bans
}

menu nicklist {
  -
  IRCop Monitor User
  .Search by Host:/ircop.search $address($$1,2)
  .Search by Account:/ircop.search.account $$1
  .Clone Check:/ircop.search $address($$1,3)
}

; ==============================
; MONITOR DIALOG
; ==============================
alias ircop.monitor.dialog {
  dialog -m ircop_mondlg ircop_mondlg
}

dialog ircop_mondlg {
  title "IRCop Network Monitor"
  size -1 -1 450 350
  option pixels

  ; Status panel
  box "Network Status", 1, 10 10 430 100
  text "Server:", 10, 20 30 50 18
  text "", 11, 75 30 355 18
  text "Oper Status:", 12, 20 50 75 18
  text "", 13, 100 50 100 18
  text "Local Users:", 14, 20 70 75 18
  text "", 15, 100 70 100 18
  text "Global Users:", 16, 220 70 85 18
  text "", 17, 310 70 100 18

  ; Clone summary
  box "Clone Detection", 2, 10 115 430 80
  text "Tracked Hosts:", 20, 20 135 90 18
  text "0", 21, 115 135 60 18
  text "Tracked IPs:", 22, 200 135 80 18
  text "0", 23, 285 135 60 18
  text "Clone Alerts:", 24, 20 155 85 18
  text "0", 25, 110 155 60 18
  text "Threshold:", 26, 200 155 65 18
  edit "3", 27, 270 152 40 22
  button "Update", 28, 320 152 60 22

  ; Actions
  box "Quick Actions", 3, 10 200 430 100
  button "Refresh Stats", 30, 20 220 100 28
  button "Clone Report", 31, 130 220 100 28
  button "View Log", 32, 240 220 100 28
  button "Ban Stats", 33, 350 220 80 28
  button "Network Map", 34, 20 256 100 28
  button "Online Opers", 35, 130 256 100 28
  button "Server Uptime", 36, 240 256 100 28
  button "Dashboard", 37, 350 256 80 28

  ; Close
  button "Close", 100, 180 315 90 28, cancel
}

on *:DIALOG:ircop_mondlg:init:0:{
  did -a ircop_mondlg 11 $server $+  $+ ( $+ $network $+ )
  did -a ircop_mondlg 13 $iif($hget(ircop_state,is.oper) == 1,OPERED,NOT OPERED)
  did -a ircop_mondlg 15 $iif($hget(ircop_state,users.local),$v1,N/A)
  did -a ircop_mondlg 17 $iif($hget(ircop_state,users.global),$v1,N/A)
  did -a ircop_mondlg 21 $hget(ircop_hosts,0).item
  did -a ircop_mondlg 23 $hget(ircop_ips,0).item
  did -a ircop_mondlg 27 $iif($hget(ircop_config,alert.clones),$v1,3)
}

on *:DIALOG:ircop_mondlg:sclick:28:{
  ; Update clone threshold
  hadd ircop_config alert.clones $did(ircop_mondlg,27)
  ircop.saveconfig
}

on *:DIALOG:ircop_mondlg:sclick:30:{ lusers }
on *:DIALOG:ircop_mondlg:sclick:31:{ ircop.clones }
on *:DIALOG:ircop_mondlg:sclick:32:{ ircop.log.view }
on *:DIALOG:ircop_mondlg:sclick:33:{ ircop.stats.bans }
on *:DIALOG:ircop_mondlg:sclick:34:{ ircop.map }
on *:DIALOG:ircop_mondlg:sclick:35:{ ircop.opers }
on *:DIALOG:ircop_mondlg:sclick:36:{ ircop.uptime }
on *:DIALOG:ircop_mondlg:sclick:37:{ ircop.dashboard }

; End of ircop-monitor.mrc
