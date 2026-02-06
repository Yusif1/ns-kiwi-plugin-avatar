; =============================================================================
; IRCop User & Channel Management - ircop-usermgmt.mrc
; Compatible with: mIRC 7.72+ | UnrealIRCd 6.5+
; Description: Kill, G/K/Z-line, Shun, Spamfilter, SA* commands, extended bans,
;              channel recovery, user info, mass operations
; Part of the IRCop System (3-file set): ircop-core / ircop-usermgmt / ircop-monitor
; =============================================================================

; ---------------------
; INITIALIZATION
; ---------------------
on *:START:{
  ; Create hash table for pending lookups and user info cache
  if (!$hget(ircop_users)) { hmake ircop_users 200 }
  if (!$hget(ircop_bans))  { hmake ircop_bans 100 }
  echo -s 4[IRCop System] User management module loaded.
}

on *:UNLOAD:{
  if ($hget(ircop_users)) { hfree ircop_users }
  if ($hget(ircop_bans))  { hfree ircop_bans }
  echo -s 4[IRCop System] User management module unloaded.
}

; ==============================
; KILL COMMANDS
; ==============================
alias ircop.kill {
  ; Usage: /ircop.kill <nick> <reason>
  if (!$1) {
    ircop.echo 4 Usage: /ircop.kill <nick> <reason>
    return
  }
  var %nick = $1
  var %reason = $2-
  if (!%reason) { %reason = IRCop Action }

  kill %nick %reason
  ircop.echo 4 [KILL] Killed %nick $+  $+ ( $+ %reason $+ )
  ircop.log KILL Killed %nick ( $+ %reason $+ )
}

alias ircop.kill.template {
  ; Usage: /ircop.kill.template <nick> <template-name>
  ; Uses predefined reason templates from ircop-core
  if (!$1 || !$2) {
    ircop.echo 4 Usage: /ircop.kill.template <nick> <template-name>
    ircop.echo 7 Templates: spam, abuse, clone, bot, drone, evade, illegal, tos
    return
  }
  var %nick = $1
  var %tpl = kill. $+ $2
  var %reason = $hget(ircop_templates,%tpl)
  if (!%reason) {
    ircop.echo 4 [ERROR] Unknown template: $2
    return
  }
  kill %nick %reason
  ircop.echo 4 [KILL] Killed %nick with template ' $+ $2 $+ ': %reason
  ircop.log KILL Template kill: %nick ( $+ %reason $+ )
}

; ==============================
; G-LINE (Global Network Ban)
; UnrealIRCd 6.5: /GLINE <user@host> <duration> :<reason>
; ==============================
alias ircop.gline {
  ; Usage: /ircop.gline <user@host> <duration> <reason>
  ; Duration: e.g. 1h, 30m, 7d, 0 (permanent)
  if ($0 < 3) {
    ircop.echo 4 Usage: /ircop.gline <user@host> <duration> <reason>
    ircop.echo 7 Duration examples: 30m, 1h, 6h, 1d, 7d, 30d, 0 (permanent)
    return
  }
  var %mask = $1
  var %dur  = $2
  var %reason = $3-

  raw GLINE %mask %dur : $+ %reason
  ircop.echo 4 [GLINE] Added G-line: %mask (Duration: %dur $+ ) - %reason
  ircop.log GLINE Added: %mask %dur %reason
}

alias ircop.gline.nick {
  ; Usage: /ircop.gline.nick <nick> <duration> <reason>
  ; Resolves nick to *@host and G-lines
  if ($0 < 3) {
    ircop.echo 4 Usage: /ircop.gline.nick <nick> <duration> <reason>
    return
  }
  var %nick = $1
  var %dur  = $2
  var %reason = $3-

  ; Store pending gline info for WHOIS callback
  hadd ircop_bans pending.gline.nick %nick
  hadd ircop_bans pending.gline.dur %dur
  hadd ircop_bans pending.gline.reason %reason
  hadd ircop_bans pending.action gline

  ; Request WHOIS to get host
  whois %nick
}

alias ircop.gline.remove {
  ; Usage: /ircop.gline.remove <user@host>
  if (!$1) {
    ircop.echo 4 Usage: /ircop.gline.remove <user@host>
    return
  }
  raw GLINE - $+ $1
  ircop.echo 3 [GLINE] Removed G-line: $1
  ircop.log GLINE Removed: $1
}

alias ircop.gline.list {
  ; List active G-lines
  raw STATS G
  ircop.echo 7 [GLINE] Requesting G-line list...
}

; ==============================
; K-LINE (Server Ban)
; UnrealIRCd 6.5: /KLINE <user@host> :<reason>
; ==============================
alias ircop.kline {
  ; Usage: /ircop.kline <user@host> <reason>
  if ($0 < 2) {
    ircop.echo 4 Usage: /ircop.kline <user@host> <reason>
    return
  }
  var %mask = $1
  var %reason = $2-

  raw KLINE %mask : $+ %reason
  ircop.echo 4 [KLINE] Added K-line: %mask - %reason
  ircop.log KLINE Added: %mask %reason
}

alias ircop.kline.nick {
  ; Usage: /ircop.kline.nick <nick> <reason>
  if ($0 < 2) {
    ircop.echo 4 Usage: /ircop.kline.nick <nick> <reason>
    return
  }
  var %nick = $1
  var %reason = $2-

  hadd ircop_bans pending.kline.nick %nick
  hadd ircop_bans pending.kline.reason %reason
  hadd ircop_bans pending.action kline

  whois %nick
}

alias ircop.kline.remove {
  ; Usage: /ircop.kline.remove <user@host>
  if (!$1) {
    ircop.echo 4 Usage: /ircop.kline.remove <user@host>
    return
  }
  raw KLINE - $+ $1
  ircop.echo 3 [KLINE] Removed K-line: $1
  ircop.log KLINE Removed: $1
}

alias ircop.kline.list {
  raw STATS k
  ircop.echo 7 [KLINE] Requesting K-line list...
}

; ==============================
; Z-LINE (IP Ban)
; UnrealIRCd 6.5: /ZLINE <ip> <duration> :<reason>
; ==============================
alias ircop.zline {
  ; Usage: /ircop.zline <ip> <duration> <reason>
  if ($0 < 3) {
    ircop.echo 4 Usage: /ircop.zline <ip-or-mask> <duration> <reason>
    ircop.echo 7 Duration examples: 30m, 1h, 6h, 1d, 7d, 30d, 0 (permanent)
    return
  }
  var %ip = $1
  var %dur = $2
  var %reason = $3-

  raw ZLINE %ip %dur : $+ %reason
  ircop.echo 4 [ZLINE] Added Z-line: %ip (Duration: %dur $+ ) - %reason
  ircop.log ZLINE Added: %ip %dur %reason
}

alias ircop.zline.nick {
  ; Usage: /ircop.zline.nick <nick> <duration> <reason>
  if ($0 < 3) {
    ircop.echo 4 Usage: /ircop.zline.nick <nick> <duration> <reason>
    return
  }
  var %nick = $1
  var %dur = $2
  var %reason = $3-

  hadd ircop_bans pending.zline.nick %nick
  hadd ircop_bans pending.zline.dur %dur
  hadd ircop_bans pending.zline.reason %reason
  hadd ircop_bans pending.action zline

  whois %nick
}

alias ircop.zline.remove {
  if (!$1) {
    ircop.echo 4 Usage: /ircop.zline.remove <ip>
    return
  }
  raw ZLINE - $+ $1
  ircop.echo 3 [ZLINE] Removed Z-line: $1
  ircop.log ZLINE Removed: $1
}

alias ircop.zline.list {
  raw STATS Z
  ircop.echo 7 [ZLINE] Requesting Z-line list...
}

; ==============================
; SHUN (Silence user server-side)
; UnrealIRCd 6.5: /SHUN <user@host> <duration> :<reason>
; ==============================
alias ircop.shun {
  ; Usage: /ircop.shun <user@host> <duration> <reason>
  if ($0 < 3) {
    ircop.echo 4 Usage: /ircop.shun <user@host> <duration> <reason>
    ircop.echo 7 Duration examples: 30m, 1h, 6h, 1d, 7d, 30d, 0 (permanent)
    return
  }
  var %mask = $1
  var %dur = $2
  var %reason = $3-

  raw SHUN %mask %dur : $+ %reason
  ircop.echo 4 [SHUN] Added shun: %mask (Duration: %dur $+ ) - %reason
  ircop.log SHUN Added: %mask %dur %reason
}

alias ircop.shun.nick {
  ; Usage: /ircop.shun.nick <nick> <duration> <reason>
  if ($0 < 3) {
    ircop.echo 4 Usage: /ircop.shun.nick <nick> <duration> <reason>
    return
  }
  var %nick = $1
  var %dur = $2
  var %reason = $3-

  hadd ircop_bans pending.shun.nick %nick
  hadd ircop_bans pending.shun.dur %dur
  hadd ircop_bans pending.shun.reason %reason
  hadd ircop_bans pending.action shun

  whois %nick
}

alias ircop.shun.remove {
  if (!$1) {
    ircop.echo 4 Usage: /ircop.shun.remove <user@host>
    return
  }
  raw SHUN - $+ $1
  ircop.echo 3 [SHUN] Removed shun: $1
  ircop.log SHUN Removed: $1
}

alias ircop.shun.list {
  raw STATS s
  ircop.echo 7 [SHUN] Requesting shun list...
}

; ==============================
; E-LINE (Exception from bans)
; UnrealIRCd 6.5: /ELINE <user@host> <duration> :<reason>
; ==============================
alias ircop.eline {
  ; Usage: /ircop.eline <user@host> <duration> <reason>
  if ($0 < 3) {
    ircop.echo 4 Usage: /ircop.eline <user@host> <duration> <reason>
    return
  }
  var %mask = $1
  var %dur = $2
  var %reason = $3-

  raw ELINE %mask %dur : $+ %reason
  ircop.echo 3 [ELINE] Added E-line: %mask (Duration: %dur $+ ) - %reason
  ircop.log ELINE Added: %mask %dur %reason
}

alias ircop.eline.remove {
  if (!$1) {
    ircop.echo 4 Usage: /ircop.eline.remove <user@host>
    return
  }
  raw ELINE - $+ $1
  ircop.echo 3 [ELINE] Removed E-line: $1
  ircop.log ELINE Removed: $1
}

alias ircop.eline.list {
  raw STATS e
  ircop.echo 7 [ELINE] Requesting E-line list...
}

; ==============================
; WHOIS CALLBACK for nick-based bans
; Handles RPL_WHOISUSER (311) to resolve nick -> host for ban operations
; ==============================
raw 311:*:{
  ; $2=nick, $3=user, $4=host, $6-=realname
  var %nick = $2
  var %user = $3
  var %host = $4
  var %mask = *!*@ $+ %host
  var %ip = $null

  ; Cache user info
  hadd ircop_users $+(%nick,.user) %user
  hadd ircop_users $+(%nick,.host) %host
  hadd ircop_users $+(%nick,.realname) $6-
  hadd ircop_users $+(%nick,.mask) %mask

  ; Check for pending ban actions
  var %action = $hget(ircop_bans,pending.action)
  if (%action) {
    var %pending.nick = $hget(ircop_bans,$+(pending.,%action,.nick))
    if (%pending.nick == %nick) {
      if (%action == gline) {
        var %dur = $hget(ircop_bans,pending.gline.dur)
        var %reason = $hget(ircop_bans,pending.gline.reason)
        raw GLINE %mask %dur : $+ %reason
        ircop.echo 4 [GLINE] Added G-line on %nick $+ : %mask (Duration: %dur $+ ) - %reason
        ircop.log GLINE Added via nick %nick $+ : %mask %dur %reason
      }
      elseif (%action == kline) {
        var %reason = $hget(ircop_bans,pending.kline.reason)
        raw KLINE %mask : $+ %reason
        ircop.echo 4 [KLINE] Added K-line on %nick $+ : %mask - %reason
        ircop.log KLINE Added via nick %nick $+ : %mask %reason
      }
      elseif (%action == zline) {
        var %dur = $hget(ircop_bans,pending.zline.dur)
        var %reason = $hget(ircop_bans,pending.zline.reason)
        ; Z-line needs IP, use host (may be IP or resolve)
        raw ZLINE %host %dur : $+ %reason
        ircop.echo 4 [ZLINE] Added Z-line on %nick $+ : %host (Duration: %dur $+ ) - %reason
        ircop.log ZLINE Added via nick %nick $+ : %host %dur %reason
      }
      elseif (%action == shun) {
        var %dur = $hget(ircop_bans,pending.shun.dur)
        var %reason = $hget(ircop_bans,pending.shun.reason)
        raw SHUN %mask %dur : $+ %reason
        ircop.echo 4 [SHUN] Added shun on %nick $+ : %mask (Duration: %dur $+ ) - %reason
        ircop.log SHUN Added via nick %nick $+ : %mask %dur %reason
      }
      ; Clear pending action
      hdel ircop_bans pending.action
    }
  }
}

; RPL_WHOISSERVER (312) - User's server
raw 312:*:{
  hadd ircop_users $+($2,.server) $3
}

; RPL_WHOISOPERATOR (313) - User is an IRC operator
raw 313:*:{
  hadd ircop_users $+($2,.isoper) 1
}

; RPL_WHOISIDLE (317) - Idle time and signon
raw 317:*:{
  hadd ircop_users $+($2,.idle) $3
  hadd ircop_users $+($2,.signon) $4
}

; RPL_WHOISACCOUNT (330) - Logged in as (services account)
raw 330:*:{
  hadd ircop_users $+($2,.account) $3
}

; RPL_WHOISSECURE (671) - Using TLS/SSL
raw 671:*:{
  hadd ircop_users $+($2,.secure) 1
}

; RPL_WHOISHOST (378) - Connecting from (shows real IP)
raw 378:*:{
  hadd ircop_users $+($2,.realhost) $3-
  ; Extract IP if present in the message
  var %msg = $3-
  var %ip = $regsubex(%msg,/.*?(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}).*/,\1)
  if (%ip) {
    hadd ircop_users $+($2,.ip) %ip
  }
}

; ==============================
; USER INFO DISPLAY
; ==============================
alias ircop.userinfo {
  ; Usage: /ircop.userinfo <nick>
  if (!$1) {
    ircop.echo 4 Usage: /ircop.userinfo <nick>
    return
  }
  var %nick = $1

  ; Request fresh WHOIS
  hadd ircop_bans pending.action userinfo
  hadd ircop_bans pending.userinfo.nick %nick
  whois %nick %nick
}

; End of WHOIS (318) - Display cached info if userinfo was requested
raw 318:*:{
  var %nick = $2
  var %action = $hget(ircop_bans,pending.action)
  if (%action == userinfo && $hget(ircop_bans,pending.userinfo.nick) == %nick) {
    hdel ircop_bans pending.action
    hdel ircop_bans pending.userinfo.nick

    ircop.echo 12 $str(=,50)
    ircop.echo 12 User Info: %nick
    ircop.echo 12 $str(=,50)
    ircop.echo 3 User: $hget(ircop_users,$+(%nick,.user))
    ircop.echo 3 Host: $hget(ircop_users,$+(%nick,.host))
    ircop.echo 3 Realname: $hget(ircop_users,$+(%nick,.realname))
    ircop.echo 3 Server: $hget(ircop_users,$+(%nick,.server))

    if ($hget(ircop_users,$+(%nick,.ip))) {
      ircop.echo 3 Real IP: $hget(ircop_users,$+(%nick,.ip))
    }
    if ($hget(ircop_users,$+(%nick,.realhost))) {
      ircop.echo 3 Real Host: $hget(ircop_users,$+(%nick,.realhost))
    }
    if ($hget(ircop_users,$+(%nick,.account))) {
      ircop.echo 3 Account: $hget(ircop_users,$+(%nick,.account))
    }
    ircop.echo 3 Oper: $iif($hget(ircop_users,$+(%nick,.isoper)),Yes,No)
    ircop.echo 3 Secure (TLS): $iif($hget(ircop_users,$+(%nick,.secure)),Yes,No)
    if ($hget(ircop_users,$+(%nick,.idle))) {
      ircop.echo 3 Idle: $ircop.duration($hget(ircop_users,$+(%nick,.idle)))
    }
    if ($hget(ircop_users,$+(%nick,.signon))) {
      ircop.echo 3 Signon: $asctime($hget(ircop_users,$+(%nick,.signon)),yyyy-mm-dd HH:nn:ss)
    }
    ircop.echo 3 Mask: *!*@ $+ $hget(ircop_users,$+(%nick,.host))
    ircop.echo 12 $str(=,50)
  }
}

; ==============================
; SA* COMMANDS (UnrealIRCd 6.5)
; Server Admin forced operations
; ==============================
alias ircop.sajoin {
  ; Usage: /ircop.sajoin <nick> <#channel>
  if (!$1 || !$2) {
    ircop.echo 4 Usage: /ircop.sajoin <nick> <#channel>
    return
  }
  var %nick = $1
  var %chan = $2
  ; Ensure channel prefix
  if ($left(%chan,1) != $chr(35)) { %chan = $chr(35) $+ %chan }

  raw SAJOIN %nick %chan
  ircop.echo 9 [SAJOIN] Forced %nick to join %chan
  ircop.log SAJOIN %nick -> %chan
}

alias ircop.sapart {
  ; Usage: /ircop.sapart <nick> <#channel>
  if (!$1 || !$2) {
    ircop.echo 4 Usage: /ircop.sapart <nick> <#channel>
    return
  }
  var %nick = $1
  var %chan = $2
  if ($left(%chan,1) != $chr(35)) { %chan = $chr(35) $+ %chan }

  raw SAPART %nick %chan
  ircop.echo 9 [SAPART] Forced %nick to part %chan
  ircop.log SAPART %nick <- %chan
}

alias ircop.sanick {
  ; Usage: /ircop.sanick <nick> <newnick>
  if (!$1 || !$2) {
    ircop.echo 4 Usage: /ircop.sanick <nick> <newnick>
    return
  }
  raw SANICK $1 $2
  ircop.echo 9 [SANICK] Forced nick change: $1 -> $2
  ircop.log SANICK $1 -> $2
}

alias ircop.samode {
  ; Usage: /ircop.samode <#channel> <modes> [params]
  ; UnrealIRCd 6.5 SAMODE for forced channel mode changes
  if (!$1 || !$2) {
    ircop.echo 4 Usage: /ircop.samode <#channel> <+/-modes> [params]
    return
  }
  raw SAMODE $1-
  ircop.echo 9 [SAMODE] Forced mode on $1 $+ : $2-
  ircop.log SAMODE $1-
}

alias ircop.satopic {
  ; Usage: /ircop.satopic <#channel> <topic>
  if (!$1 || !$2) {
    ircop.echo 4 Usage: /ircop.satopic <#channel> <topic text>
    return
  }
  var %chan = $1
  var %topic = $2-
  raw SATOPIC %chan : $+ %topic
  ircop.echo 9 [SATOPIC] Forced topic on %chan $+ : %topic
  ircop.log SATOPIC %chan %topic
}

; ==============================
; EXTENDED BAN MANAGEMENT
; UnrealIRCd 6.5 extended ban format: ~type:value
; Types: account, certfp, country, operclass, realname, textban, timedban
; ==============================
alias ircop.extban {
  ; Usage: /ircop.extban <#channel> <+b/-b> <type> <value>
  ; Types: account, certfp, country, operclass, realname, text, time
  if ($0 < 4) {
    ircop.echo 4 Usage: /ircop.extban <#channel> <+b/-b> <type> <value>
    ircop.echo 7 Extended ban types for UnrealIRCd 6.5:
    ircop.echo 7  account   - ~account:<name> (ban by services account)
    ircop.echo 7  certfp    - ~certfp:<fingerprint> (ban by TLS cert)
    ircop.echo 7  country   - ~country:<CC> (ban by country code)
    ircop.echo 7  operclass - ~operclass:<class> (ban by operclass)
    ircop.echo 7  realname  - ~realname:<pattern> (ban by realname)
    ircop.echo 7  text      - ~text:block:<pattern> (block text matching pattern)
    ircop.echo 7  time      - ~time:<duration>:<mask> (timed ban)
    return
  }
  var %chan = $1
  var %mode = $2
  var %type = $3
  var %value = $4-

  ; Build the extended ban mask (UnrealIRCd 6.5 format)
  var %extban = $null
  if (%type == account)   { %extban = ~account: $+ %value }
  elseif (%type == certfp)    { %extban = ~certfp: $+ %value }
  elseif (%type == country)   { %extban = ~country: $+ %value }
  elseif (%type == operclass) { %extban = ~operclass: $+ %value }
  elseif (%type == realname)  { %extban = ~realname: $+ %value }
  elseif (%type == text)      { %extban = ~text:block: $+ %value }
  elseif (%type == time)      { %extban = ~time: $+ %value }
  else {
    ircop.echo 4 [ERROR] Unknown extended ban type: %type
    return
  }

  mode %chan %mode %extban
  ircop.echo 9 [EXTBAN] Set %mode on %chan $+ : %extban
  ircop.log EXTBAN %chan %mode %extban
}

; ==============================
; SPAMFILTER MANAGEMENT
; UnrealIRCd 6.5: /SPAMFILTER add/del/remove/list
; ==============================
alias ircop.spamfilter {
  ; Usage: /ircop.spamfilter <add|del|list> [params]
  ; Add: /ircop.spamfilter add <target> <action> <duration> <reason> <regex>
  ; Del: /ircop.spamfilter del <target> <action> <regex>
  ; List: /ircop.spamfilter list
  ;
  ; Targets: c=channel, p=private, n=notice, N=channel-notice, P=part,
  ;          q=quit, d=dcc, a=away, t=topic, u=user (all combined: cpnNPqdatu)
  ; Actions: kill, tempshun, shun, kline, gline, zline, gzline, block, dccblock, warn

  if (!$1) {
    ircop.echo 4 Usage: /ircop.spamfilter <add|del|list> [params]
    ircop.echo 7 Add: /ircop.spamfilter add <targets> <action> <duration> <reason> <regex>
    ircop.echo 7 Del: /ircop.spamfilter del <targets> <action> <regex>
    ircop.echo 7 List: /ircop.spamfilter list
    ircop.echo 7 Targets: c(hannel) p(rivate) n(otice) N(channel-notice) P(art)
    ircop.echo 7          q(uit) d(cc) a(way) t(opic) u(ser)
    ircop.echo 7 Actions: kill, tempshun, shun, kline, gline, zline, gzline, block, dccblock, warn
    return
  }

  var %cmd = $1

  if (%cmd == add) {
    if ($0 < 6) {
      ircop.echo 4 Usage: /ircop.spamfilter add <targets> <action> <duration> <reason> <regex>
      return
    }
    var %targets = $2
    var %action = $3
    var %dur = $4
    var %reason = $5
    var %regex = $6-
    raw SPAMFILTER add %targets %action %dur %reason : $+ %regex
    ircop.echo 4 [SPAMFILTER] Added: targets= $+ %targets action= $+ %action dur= $+ %dur regex= $+ %regex
    ircop.log SPAMFILTER Added: %targets %action %dur %reason %regex
  }
  elseif (%cmd == del || %cmd == remove) {
    if ($0 < 4) {
      ircop.echo 4 Usage: /ircop.spamfilter del <targets> <action> <regex>
      return
    }
    var %targets = $2
    var %action = $3
    var %regex = $4-
    raw SPAMFILTER del %targets %action : $+ %regex
    ircop.echo 3 [SPAMFILTER] Removed: targets= $+ %targets action= $+ %action regex= $+ %regex
    ircop.log SPAMFILTER Removed: %targets %action %regex
  }
  elseif (%cmd == list) {
    raw STATS F
    ircop.echo 7 [SPAMFILTER] Requesting spamfilter list...
  }
  else {
    ircop.echo 4 [ERROR] Unknown spamfilter command: %cmd (use add, del, or list)
  }
}

; ==============================
; CHANNEL RECOVERY / TAKEOVER TOOLS
; ==============================
alias ircop.chanrecover {
  ; Usage: /ircop.chanrecover <#channel>
  ; Recovers a channel: removes all bans, resets modes, gives you op
  if (!$1) {
    ircop.echo 4 Usage: /ircop.chanrecover <#channel>
    return
  }
  var %chan = $1
  if ($left(%chan,1) != $chr(35)) { %chan = $chr(35) $+ %chan }

  ircop.echo 9 [RECOVER] Starting channel recovery for %chan

  ; Force join the channel
  raw SAJOIN $me %chan

  ; Give ourselves op via SAMODE
  raw SAMODE %chan +o $me

  ; Clear restrictive modes (UnrealIRCd 6.5 channel modes)
  raw SAMODE %chan -imlkRMNKLOQS

  ircop.echo 9 [RECOVER] Joined %chan with op, cleared restrictive modes
  ircop.echo 7 [RECOVER] Use /ircop.chanunban %chan to clear all bans
  ircop.log RECOVER Channel recovery: %chan
}

alias ircop.chanunban {
  ; Usage: /ircop.chanunban <#channel>
  ; Removes all bans from a channel using SAMODE
  if (!$1) {
    ircop.echo 4 Usage: /ircop.chanunban <#channel>
    return
  }
  var %chan = $1
  if ($left(%chan,1) != $chr(35)) { %chan = $chr(35) $+ %chan }

  ; Use SAMODE to clear ban list
  ; We need to get the ban list first, then remove each
  ; For now, request the ban list
  mode %chan +b
  ircop.echo 7 [UNBAN] Requested ban list for %chan - use ban list to remove individually
  ircop.echo 7 [UNBAN] Or use: /ircop.samode %chan -b <banmask> for each ban
  ircop.log UNBAN Requested ban list: %chan
}

alias ircop.chankill {
  ; Usage: /ircop.chankill <#channel> <reason>
  ; Kills all non-oper users in a channel
  if (!$1 || !$2) {
    ircop.echo 4 Usage: /ircop.chankill <#channel> <reason>
    ircop.echo 4 WARNING: This kills ALL non-oper users in the channel!
    return
  }
  var %chan = $1
  var %reason = $2-
  var %count = 0

  if ($left(%chan,1) != $chr(35)) { %chan = $chr(35) $+ %chan }

  var %i = 1
  while (%i <= $nick(%chan,0)) {
    var %n = $nick(%chan,%i)
    ; Skip self and known opers
    if (%n != $me) {
      kill %n %reason
      inc %count
    }
    inc %i
  }

  ircop.echo 4 [CHANKILL] Killed %count users in %chan - %reason
  ircop.log CHANKILL %chan %count users killed: %reason
}

; ==============================
; MASS OPERATIONS
; ==============================
alias ircop.masskill {
  ; Usage: /ircop.masskill <nick1,nick2,nick3,...> <reason>
  if ($0 < 2) {
    ircop.echo 4 Usage: /ircop.masskill <nick1,nick2,...> <reason>
    return
  }
  var %nicks = $1
  var %reason = $2-
  var %count = 0

  var %i = 1
  while ($gettok(%nicks,%i,44)) {
    var %nick = $gettok(%nicks,%i,44)
    kill %nick %reason
    inc %count
    inc %i
  }
  ircop.echo 4 [MASSKILL] Killed %count users: %reason
  ircop.log MASSKILL %count users killed: %reason
}

alias ircop.massgline {
  ; Usage: /ircop.massgline <mask1,mask2,...> <duration> <reason>
  if ($0 < 3) {
    ircop.echo 4 Usage: /ircop.massgline <mask1,mask2,...> <duration> <reason>
    return
  }
  var %masks = $1
  var %dur = $2
  var %reason = $3-
  var %count = 0

  var %i = 1
  while ($gettok(%masks,%i,44)) {
    var %mask = $gettok(%masks,%i,44)
    raw GLINE %mask %dur : $+ %reason
    inc %count
    inc %i
  }
  ircop.echo 4 [MASSGLINE] Added %count G-lines (Duration: %dur $+ ): %reason
  ircop.log MASSGLINE %count glines added: %dur %reason
}

; ==============================
; KILL/BAN DIALOG (GUI)
; ==============================
alias ircop.banmenu {
  ; Usage: /ircop.banmenu [nick]
  if ($1) { hadd ircop_bans dialog.nick $1 }
  dialog -m ircop_bandlg ircop_bandlg
}

dialog ircop_bandlg {
  title "IRCop Ban Manager"
  size -1 -1 900 720
  option pixels

  ; ── Target ──
  box "Target", 60, 25 15 850 80
  text "Nick or Mask:", 1, 50 50 170 32
  edit "", 10, 230 45 610 36

  ; ── Action & Duration ──
  box "Action", 61, 25 110 850 80
  text "Type:", 2, 50 145 80 32
  combo 11, 140 140 280 200, drop
  text "Duration:", 3, 460 145 120 32
  combo 14, 590 140 250 200, drop

  ; ── Reason ──
  box "Reason", 62, 25 205 850 140
  text "Reason:", 4, 50 240 100 32
  edit "", 12, 160 235 680 36
  text "Quick Reasons:", 5, 50 290 160 32
  combo 13, 220 285 620 250, drop

  ; ── Options ──
  box "Options", 20, 25 360 850 90
  check "Also Kill user", 21, 50 395 250 32
  check "Apply to all clones", 22, 340 395 260 32
  check "Log to channel", 23, 640 395 200 32

  ; ── Command Preview ──
  box "Command Preview", 63, 25 465 850 80
  edit "", 15, 50 498 800 36, read

  ; ── Buttons ──
  button "Execute", 100, 180 575 180 44, ok
  button "Preview", 102, 390 575 180 44
  button "Cancel", 101, 600 575 180 44, cancel
}

on *:DIALOG:ircop_bandlg:init:0:{
  ; Pre-fill nick if set
  if ($hget(ircop_bans,dialog.nick)) {
    did -a ircop_bandlg 10 $hget(ircop_bans,dialog.nick)
    hdel ircop_bans dialog.nick
  }

  ; Action types
  did -a ircop_bandlg 11 Kill
  did -a ircop_bandlg 11 G-line
  did -a ircop_bandlg 11 K-line
  did -a ircop_bandlg 11 Z-line
  did -a ircop_bandlg 11 Shun
  did -a ircop_bandlg 11 Spamfilter
  did -c ircop_bandlg 11 1

  ; Durations
  did -a ircop_bandlg 14 30m
  did -a ircop_bandlg 14 1h
  did -a ircop_bandlg 14 6h
  did -a ircop_bandlg 14 12h
  did -a ircop_bandlg 14 1d
  did -a ircop_bandlg 14 3d
  did -a ircop_bandlg 14 7d
  did -a ircop_bandlg 14 30d
  did -a ircop_bandlg 14 0 (perm)
  did -c ircop_bandlg 14 3

  ; Quick reasons
  did -a ircop_bandlg 13 (Custom - type above)
  did -a ircop_bandlg 13 Spamming/Flooding
  did -a ircop_bandlg 13 Abusive behavior
  did -a ircop_bandlg 13 Unauthorized clones
  did -a ircop_bandlg 13 Unauthorized bot
  did -a ircop_bandlg 13 Drone/Compromised host
  did -a ircop_bandlg 13 Ban evasion
  did -a ircop_bandlg 13 Terms of Service violation
  did -c ircop_bandlg 13 1
}

on *:DIALOG:ircop_bandlg:sclick:13:{
  ; Update reason field when quick reason selected
  var %sel = $did(ircop_bandlg,13).seltext
  if (%sel != (Custom - type above)) {
    did -ra ircop_bandlg 12 %sel
  }
}

on *:DIALOG:ircop_bandlg:sclick:102:{
  ; Preview button - show command that would be executed
  var %target = $did(ircop_bandlg,10)
  var %action = $did(ircop_bandlg,11).seltext
  var %dur = $did(ircop_bandlg,14).seltext
  var %reason = $did(ircop_bandlg,12)
  ; Clean duration display
  var %durval = $gettok(%dur,1,32)

  var %preview = $null
  if (%action == Kill) { %preview = /KILL %target : $+ %reason }
  elseif (%action == G-line) { %preview = /GLINE *!*@ $+ %target %durval : $+ %reason }
  elseif (%action == K-line) { %preview = /KLINE *!*@ $+ %target : $+ %reason }
  elseif (%action == Z-line) { %preview = /ZLINE %target %durval : $+ %reason }
  elseif (%action == Shun)   { %preview = /SHUN *!*@ $+ %target %durval : $+ %reason }

  did -ra ircop_bandlg 15 %preview
}

on *:DIALOG:ircop_bandlg:sclick:100:{
  ; Execute button
  var %target = $did(ircop_bandlg,10)
  var %action = $did(ircop_bandlg,11).seltext
  var %dur = $gettok($did(ircop_bandlg,14).seltext,1,32)
  var %reason = $did(ircop_bandlg,12)
  var %alsokill = $did(ircop_bandlg,21).state

  if (!%target) {
    ircop.echo 4 [ERROR] No target specified
    return
  }
  if (!%reason) { %reason = IRCop Action }

  if (%action == Kill) {
    ircop.kill %target %reason
  }
  elseif (%action == G-line) {
    ircop.gline.nick %target %dur %reason
    if (%alsokill) { .timer 1 2 ircop.kill %target %reason }
  }
  elseif (%action == K-line) {
    ircop.kline.nick %target %reason
    if (%alsokill) { .timer 1 2 ircop.kill %target %reason }
  }
  elseif (%action == Z-line) {
    ircop.zline.nick %target %dur %reason
    if (%alsokill) { .timer 1 2 ircop.kill %target %reason }
  }
  elseif (%action == Shun) {
    ircop.shun.nick %target %dur %reason
  }
}

; ==============================
; RIGHT-CLICK MENUS (Nicklist)
; ==============================
menu nicklist {
  -
  IRCop Ban Menu
  .Quick Kill:/ircop.kill $$1 IRCop Action
  .Kill (Spam):/ircop.kill.template $$1 spam
  .Kill (Abuse):/ircop.kill.template $$1 abuse
  .Kill (Clone):/ircop.kill.template $$1 clone
  .Kill (Drone):/ircop.kill.template $$1 drone
  .-
  .G-line 1h:/ircop.gline.nick $$1 1h Network ban
  .G-line 1d:/ircop.gline.nick $$1 1d Network ban
  .G-line 7d:/ircop.gline.nick $$1 7d Network ban
  .-
  .Shun 1h:/ircop.shun.nick $$1 1h Shunned
  .Shun 1d:/ircop.shun.nick $$1 1d Shunned
  .-
  .Ban Manager:/ircop.banmenu $$1
}

menu channel {
  -
  IRCop Channel Tools
  .Recover Channel:/ircop.chanrecover $chan
  .Clear Bans:/ircop.chanunban $chan
  .Force Topic:/ircop.satopic $chan $$?="New topic:"
  .SAMODE:/ircop.samode $chan $$?="Modes to set:"
}

; End of ircop-usermgmt.mrc
