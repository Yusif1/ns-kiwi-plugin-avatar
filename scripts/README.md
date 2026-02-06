# IRCop System for mIRC 7.72+ / UnrealIRCd 6.5+

A comprehensive three-file mIRC scripting system designed for IRC Operators. All three script files work together as a unified system while running from separate script files in mIRC.

## Compatibility

- **mIRC**: Version 7.72 or later (uses hash tables, regex, modern dialog syntax, signals)
- **IRCd**: UnrealIRCd 6.5 or later (correct numerics, extended bans, SA* commands, snomasks, spamfilter syntax)

## Files

| File | Purpose |
|------|---------|
| `ircop-core.mrc` | Core foundation: configuration, oper-up, raw numerics, server notices, @IRCop window, logging, menus |
| `ircop-usermgmt.mrc` | User & channel management: kill, G/K/Z-line, shun, E-line, spamfilter, SA* commands, extended bans, channel recovery, mass operations, ban dialog |
| `ircop-monitor.mrc` | Monitoring & logging: clone detection, flood tracking, connection rate, user search, server stats, dashboard, nick tracking, log viewer |

## Installation

1. Copy all three `.mrc` files to your mIRC scripts directory (e.g., `C:\Users\<you>\mIRC\scripts\`)
2. In mIRC, open the Script Editor (`Alt+R`)
3. Go to **File > Load** and load each file in order:
   - `ircop-core.mrc` (load first)
   - `ircop-usermgmt.mrc`
   - `ircop-monitor.mrc`
4. Run `/ircop.setup` to configure your oper credentials and preferences
5. Connect to your UnrealIRCd 6.5+ server

## Quick Start

```
/ircop.setup          - Open the configuration dialog
/oper.up              - Oper up using saved credentials
/ircop.status         - Show system status
/ircop.help           - Full command reference
/ircop.dashboard      - Network overview dashboard
```

## Command Reference

### Core Commands (`ircop-core.mrc`)

| Command | Description |
|---------|-------------|
| `/ircop.setup` | Open configuration dialog (oper name, password, modes, logging, alerts) |
| `/ircop.window` | Open the @IRCop console window |
| `/ircop.status` | Display system status report |
| `/ircop.help` | Show full command reference |
| `/oper.up [name] [pass]` | Oper up (uses saved credentials if no params) |
| `/oper.down` | Remove oper status |
| `/ircop.snomask <modes>` | Set server notice mask (e.g., `+cfksoGnqSe`) |
| `/ircop.lusers` | Show network user counts |
| `/ircop.map` | Show network server map |
| `/ircop.uptime` | Show server uptime |
| `/ircop.opers` | Show online operators |
| `/ircop.links` | Show server links |
| `/ircop.modules` | List loaded server modules |

### User Management Commands (`ircop-usermgmt.mrc`)

| Command | Description |
|---------|-------------|
| `/ircop.kill <nick> <reason>` | Kill a user |
| `/ircop.kill.template <nick> <tpl>` | Kill using a preset reason template (`spam`, `abuse`, `clone`, `bot`, `drone`, `evade`, `illegal`, `tos`) |
| `/ircop.gline <mask> <dur> <reason>` | Add a G-line (network ban) |
| `/ircop.gline.nick <nick> <dur> <reason>` | G-line by nick (auto-resolves host) |
| `/ircop.gline.remove <mask>` | Remove a G-line |
| `/ircop.gline.list` | List active G-lines |
| `/ircop.kline <mask> <reason>` | Add a K-line (server ban) |
| `/ircop.kline.nick <nick> <reason>` | K-line by nick |
| `/ircop.kline.remove <mask>` | Remove a K-line |
| `/ircop.kline.list` | List active K-lines |
| `/ircop.zline <ip> <dur> <reason>` | Add a Z-line (IP ban) |
| `/ircop.zline.nick <nick> <dur> <reason>` | Z-line by nick (uses resolved IP) |
| `/ircop.zline.remove <ip>` | Remove a Z-line |
| `/ircop.zline.list` | List active Z-lines |
| `/ircop.shun <mask> <dur> <reason>` | Shun a user (server-side silence) |
| `/ircop.shun.nick <nick> <dur> <reason>` | Shun by nick |
| `/ircop.shun.remove <mask>` | Remove a shun |
| `/ircop.shun.list` | List active shuns |
| `/ircop.eline <mask> <dur> <reason>` | Add an E-line (ban exception) |
| `/ircop.eline.remove <mask>` | Remove an E-line |
| `/ircop.eline.list` | List active E-lines |
| `/ircop.sajoin <nick> <#chan>` | Force a user to join a channel |
| `/ircop.sapart <nick> <#chan>` | Force a user to part a channel |
| `/ircop.sanick <nick> <newnick>` | Force a nick change |
| `/ircop.samode <#chan> <modes>` | Force channel modes |
| `/ircop.satopic <#chan> <topic>` | Force set channel topic |
| `/ircop.extban <#chan> <+b/-b> <type> <val>` | Manage UnrealIRCd 6.5 extended bans (`account`, `certfp`, `country`, `operclass`, `realname`, `text`, `time`) |
| `/ircop.spamfilter <add\|del\|list>` | Manage spamfilters |
| `/ircop.chanrecover <#chan>` | Recover a channel (join, op self, clear modes) |
| `/ircop.chanunban <#chan>` | Request channel ban list for clearing |
| `/ircop.chankill <#chan> <reason>` | Kill all non-oper users in a channel |
| `/ircop.masskill <n1,n2,...> <reason>` | Kill multiple users at once |
| `/ircop.massgline <m1,m2,...> <dur> <reason>` | G-line multiple masks |
| `/ircop.userinfo <nick>` | Display detailed user info |
| `/ircop.banmenu [nick]` | Open the GUI ban manager dialog |

### Monitoring Commands (`ircop-monitor.mrc`)

| Command | Description |
|---------|-------------|
| `/ircop.dashboard` | Show network status dashboard |
| `/ircop.dashboard.auto [secs]` | Toggle auto-refreshing dashboard |
| `/ircop.clones [threshold]` | Show clone report (default threshold: 2) |
| `/ircop.clones.kill <host> <reason>` | Kill all users from a specific host |
| `/ircop.gline.clones <host> <dur> <reason>` | G-line a clone host |
| `/ircop.search <pattern>` | Search users by nick/host pattern |
| `/ircop.search.account <name>` | Search users by services account |
| `/ircop.search.realname <pattern>` | Search users by realname |
| `/ircop.connrate [on\|off] [secs]` | Monitor connection rate |
| `/ircop.stats <letter>` | Query specific server stats |
| `/ircop.stats.bans` | Request all ban-type stats at once |
| `/ircop.log.view [lines] [date]` | View log entries |
| `/ircop.log.search <pattern> [date]` | Search log entries |
| `/ircop.log.clear [date]` | Clear a day's log file |
| `/ircop.monitor.dialog` | Open the monitoring GUI dialog |

## Duration Format

For G-lines, Z-lines, and Shuns, durations follow UnrealIRCd 6.5 format:

- `30m` - 30 minutes
- `1h` - 1 hour
- `6h` - 6 hours
- `1d` - 1 day
- `7d` - 7 days
- `30d` - 30 days
- `0` - permanent

## UnrealIRCd 6.5 SNOMask Reference

Set with `/ircop.snomask <+modes>`:

| Mask | Description |
|------|-------------|
| `c` | Client connections/disconnections |
| `f` | Flood notices |
| `F` | Flood alerts (high-level) |
| `k` | Kill notices |
| `s` | Server notices (general) |
| `o` | Oper-up notices |
| `j` | Junk notices |
| `G` | G-line/ban notices |
| `n` | Nick change notices |
| `q` | Connection reject notices |
| `S` | Spamfilter matches |
| `e` | Oper-override / eyes |
| `v` | Virus/DCC reject notices |

## UnrealIRCd 6.5 Extended Ban Types

Used with `/ircop.extban`:

| Type | Format | Description |
|------|--------|-------------|
| `account` | `~account:<name>` | Ban by services account name |
| `certfp` | `~certfp:<fingerprint>` | Ban by TLS certificate fingerprint |
| `country` | `~country:<CC>` | Ban by country code (GeoIP) |
| `operclass` | `~operclass:<class>` | Ban by oper class |
| `realname` | `~realname:<pattern>` | Ban by realname/gecos |
| `text` | `~text:block:<pattern>` | Block text matching pattern |
| `time` | `~time:<duration>:<mask>` | Time-limited ban |

## Configuration

Run `/ircop.setup` to open the configuration dialog. Settings are saved to `ircop.conf` in the script directory.

### Configuration Options

- **Oper Name/Password**: Credentials for automatic oper-up
- **Auto Oper-Up**: Automatically oper up when connecting to the server
- **Oper Modes**: User modes to set after opering up (default: `+gswoSqHtWGnN`)
- **Auto-open Window**: Open @IRCop console on connect
- **Timestamps**: Show timestamps in the @IRCop window
- **Max Lines**: Maximum lines in the @IRCop window before trimming
- **Logging**: Enable/disable file logging
- **Log Directory**: Where log files are stored
- **Flash/Sound Alerts**: Taskbar flash and beep on critical events
- **Clone Threshold**: Number of connections from same host to trigger clone alert

## Architecture

The three scripts communicate through:
- **Shared hash tables**: `ircop_config`, `ircop_state`, `ircop_templates` (created by core, used by all)
- **mIRC signals**: `.signal ircop.connect`, `.signal ircop.exit`, `.signal ircop.flood` (sent by core, received by monitor)
- **Common aliases**: `ircop.echo`, `ircop.log`, `ircop.window` (defined in core, called by all)

## Right-Click Menus

All scripts add context-sensitive right-click menus:
- **Channel/Query**: IRCop System (console, status, oper, info), IRCop Monitor (dashboard, clones, stats)
- **Nicklist**: IRCop Actions (whois, kill, bans, SA* commands), IRCop Ban Menu (quick kill, G-line, shun), IRCop Monitor User (search, clone check)

## License

These scripts are provided as-is for IRC network administration purposes.
