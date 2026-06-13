# LMS Album Suggester

A small plugin for Lyrion Music Server (LMS): shows **N random albums** from your
library to browse and play. Each album is a native LMS item — clicking opens the
native album/tracks view, playing uses the native now-playing bar. No iframe, no
separate server.

> Deliberately minimal scope: **suggestion only**. LMS does the rest (playback,
> album info, now-playing).

## Structure

The repository **is** the plugin folder (module `Plugins::Suggester::Plugin`):

```
install.xml     plugin metadata (version, module, LMS compatibility)
strings.txt     EN/FR labels
Plugin.pm       the core: menu + album picking
```

## Installation

Copy the plugin folder into your LMS **local** plugins directory and restart the
server. On a Debian-based install this is:

```
/var/lib/squeezeboxserver/Plugins/Suggester
```

> Do **not** install it under `cache/InstalledPlugins/Plugins/`: that folder is
> managed by the extensions auto-updater, which schedules the removal of any
> plugin it doesn't find in a known repository — the plugin would disappear on
> the next restart.

After the first install, enable it if needed: Settings → Plugins → **Album
Suggester**.

## Dev / debug loop

- Edit `Plugin.pm` → redeploy → restart LMS → check the log.
  (Perl is loaded at LMS startup, hence the restart each time.)
- Logs: Settings → Logging, or tail `server.log` in the cache folder from the
  command line. Dedicated log category: `plugin.suggester` (adjustable under
  Settings → Logging). On a Perl error at load time the plugin does not show up
  → that's the first place to look.
- Quick feed test without clicking around, via the CLI (telnet port 9090):
  `<player_mac> suggester items 0 10`

## Things that may need adjusting on first run

The skeleton targets the stable public API, but worth validating on your LMS
version:

- `image => 'music/<artwork>/cover'`: cover URL format.
- `$album->contributor->name`: the "album artist" relation per the schema.
- Behaviour of `playlist => \&tracksFeed` for "Play" at the album level.

If one of these breaks, the `plugin.suggester` and `server.log` logs will say
what to fix.

## Possible improvements

- Settings page for the number of albums (`count`, already a pref).
- Filters: never played, by genre, by decade.
- A "refresh" button / new batch.
