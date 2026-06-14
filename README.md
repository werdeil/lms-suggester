# LMS Album Suggester

A small plugin for Lyrion Music Server (LMS): shows **N random albums** from your
library to browse and play. Each album is a native LMS item — clicking opens the
native album/tracks view, playing uses the native now-playing bar. No iframe, no
separate server.

> Deliberately minimal scope: **suggestion only**. LMS does the rest (playback,
> album info, now-playing).

> **Primary target: the Material skin.** The plugin works in every LMS UI, but
> the experience (notably the "New selection" refresh, which relies on
> `nextWindow => 'refresh'`) is tuned for Material. On the classic web skin that
> refresh is less polished — a deliberate trade-off in favour of Material.

## Structure

The repository **is** the plugin folder (module `Plugins::Suggester::Plugin`):

```
install.xml     plugin metadata (version, module, LMS compatibility)
strings.txt     EN/FR labels
Plugin.pm       the core: menu + album picking
Settings.pm     web settings page (number of albums)
HTML/EN/...      settings template (settings/basic.html)
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

## Scope & positioning

This plugin is **not** a rule-based playback engine, and deliberately so. If you
want random/never-played/by-genre **playback** that auto-feeds the queue, AF-1's
[Dynamic Playlist](https://github.com/AF-1/lms-dynamicplaylists) already does it
better: its built-in definitions (e.g. `albums_001_random`, `albums_081_neverplayed`)
are track-driven SQL with a persistent play history, virtual-library and genre
filters, compilation handling, and Alternative Play Count integration. Competing
on selection criteria is a losing race.

What Dynamic Playlist does **not** do is what this plugin is for: present a small
**visual shortlist of N albums to pick from**, with no imposed playback — a
"what do I feel like tonight?" panel, not an auto-fed mix. Future work should
double down on that picking experience, not reimplement a rules engine.

## Possible improvements

Done in v0.2: settings page for the number of albums, a "New selection"
button (fresh batch), and clamping `count` to the library size.

Done in v0.3: "Refresh avoiding the ones I just saw" — a light, plugin-local
recently-shown memory (in-memory rolling window, per client) so a new batch
doesn't repeat the covers you just saw. Bounded by the library size so the
random pool never runs dry. This is the one genuine gap vs Dynamic Playlist's
persistent history.

Next (within the shortlist niche — nothing that re-treads Dynamic Playlist):

- Polish the shortlist UX (cover layout, quick "play this album" affordance).

Dropped (covered by Dynamic Playlist, not worth reimplementing): rule-based
filters (never/seldom played, by genre/decade), and suggesting tracks/artists as
a playback feed.
