package Plugins::Suggester::Plugin;

# Album Suggester — shows N random albums from the library to browse, then
# play/add. Built on Slim::Plugin::OPMLBased: the menu is navigable in every UI
# (Material, web, CLI, players) and audio items inherit the native menus for
# free (Play / Add / Info / now-playing).

use strict;
use warnings;

use base qw(Slim::Plugin::OPMLBased);

use Slim::Utils::Log;
use Slim::Utils::Prefs;
use Slim::Utils::Strings qw(cstring);

my $log = Slim::Utils::Log->addLogCategory({
	category     => 'plugin.suggester',
	defaultLevel => 'INFO',
	description  => 'PLUGIN_SUGGESTER',
});

my $prefs = preferences('plugin.suggester');

# Number of suggested albums. Configurable via the settings page (Settings.pm).
$prefs->init({ count => 6 });
$prefs->setValidate({ validator => 'intlimit', low => 1, high => 10 }, 'count');

# Cache of the last random selection, per client.
# XMLBrowser re-requests the parent feed to resolve the clicked item (by index):
# without a cache, RANDOM() would return a different list and we would descend
# into the wrong album. So we keep the same selection for a short TTL.
my %CACHE;
my $CACHE_TTL = 300;   # seconds

sub initPlugin {
	my $class = shift;

	$class->SUPER::initPlugin(
		tag    => 'suggester',       # internal id / feed route
		feed   => \&albumsFeed,      # menu entry point (level 1)
		menu   => 'plugins',         # where to attach it in the menu
		is_app => 1,                 # shows up as an "app" (e.g. in Material)
		weight => 50,
	);

	# Web settings page (number of albums). Web UI only.
	if ( main::WEBUI ) {
		require Plugins::Suggester::Settings;
		Plugins::Suggester::Settings->new;
	}
}

sub getDisplayName { 'PLUGIN_SUGGESTER' }

# --- Level 1: N random albums -----------------------------------------------
sub albumsFeed {
	my ($client, $cb, $args) = @_;

	my $key = $client ? $client->id : '_noclient_';

	# Clamp the requested count to what the library actually holds, so we never
	# ask SQLite for more rows than exist (and the cache size check stays sound).
	my $total = Slim::Schema->count('Album') || 0;
	my $count = $prefs->get('count') || 6;
	$count = $total if $count > $total;

	# Reuse the previous selection while it is still valid: this is what keeps
	# clicking an album from opening a different one (parent re-fetch).
	my $cached = $CACHE{$key};
	my @ids;
	if ( $cached && $cached->{expires} > time() && @{ $cached->{ids} } == $count ) {
		@ids = @{ $cached->{ids} };
	}
	else {
		# RANDOM() on the SQLite side via a scalar ref (literal SQL).
		my $rs = Slim::Schema->search('Album', undef, {
			order_by => \'RANDOM()',
			rows     => $count,
		});
		@ids = map { $_->id } $rs->all;
		$CACHE{$key} = { ids => \@ids, expires => time() + $CACHE_TTL };
	}

	my @items;

	for my $id (@ids) {
		my $album = Slim::Schema->find('Album', $id) or next;
		my $artist = eval { $album->contributor->name } || '';

		push @items, {
			name        => $album->title,
			line1       => $album->title,
			line2       => $artist,
			image       => 'music/' . ( $album->artwork || 0 ) . '/cover',
			type        => 'playlist',          # => Play / Add menu
			url         => \&tracksFeed,         # click => descend into tracks
			playlist    => \&tracksFeed,         # Play/Add => the whole album
			passthrough => [ { albumId => $album->id } ],
		};
	}

	# "New selection" button — a footer ACTION (not a navigation item). It must
	# not push a new window: a `url => feed` item would descend a level, change
	# the title and let you go "back" to the old selection. Instead we point at a
	# lightweight action that just drops the cache, and ask the UI to refresh the
	# CURRENT window (nextWindow => 'refresh') so the album list is redrawn in
	# place with a fresh batch. This is tuned for Material/jive; on the classic
	# web skin (which ignores nextWindow) the refresh is less polished, a known
	# trade-off. Kept LAST with its own icon so it doesn't read as an album.
	if (@items) {
		push @items, {
			name        => cstring($client, 'PLUGIN_SUGGESTER_REFRESH'),
			type        => 'link',
			image       => 'plugins/Suggester/html/images/refresh.png',
			url         => \&refreshAction,
			nextWindow  => 'refresh',
		};
	}
	else {
		push @items, {
			name => cstring($client, 'PLUGIN_SUGGESTER_EMPTY'),
			type => 'text',
		};
	}

	$cb->({ items => \@items });
}

# Drop this client's cached selection so the next albumsFeed() draw is fresh.
# Paired with nextWindow => 'refresh' on the button: the UI runs this action,
# then refreshes the album list window in place (no new level, no title change).
sub refreshAction {
	my ($client, $cb, $args, $pt) = @_;

	my $key = $client ? $client->id : '_noclient_';
	delete $CACHE{$key};

	$cb->({ items => [ { type => 'text', name => '' } ] });
}

# --- Level 2: an album's tracks ---------------------------------------------
# Items of type "audio" => Play / Add / Play next / Info, all native.
sub tracksFeed {
	my ($client, $cb, $args, $pt) = @_;

	my $albumId = $pt->{albumId};

	my $rs = Slim::Schema->search('Track', { album => $albumId }, {
		order_by => 'me.disc, me.tracknum, me.titlesort',
	});

	my @items;
	while ( my $track = $rs->next ) {
		push @items, {
			name  => $track->title,
			type  => 'audio',
			url   => $track->url,
			image => 'music/' . ( $track->coverid || 0 ) . '/cover',
		};
	}

	$cb->({ items => \@items });
}

1;
