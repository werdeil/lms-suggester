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

# Number of suggested albums. Will be configurable later via a settings page.
$prefs->init({ count => 5 });

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
}

sub getDisplayName { 'PLUGIN_SUGGESTER' }

# --- Level 1: N random albums -----------------------------------------------
sub albumsFeed {
	my ($client, $cb, $args) = @_;

	my $count = $prefs->get('count') || 5;

	my $key = $client ? $client->id : '_noclient_';

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

	unless (@items) {
		push @items, {
			name => cstring($client, 'PLUGIN_SUGGESTER_EMPTY'),
			type => 'text',
		};
	}

	$cb->({ items => \@items });
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
