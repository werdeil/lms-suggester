package Plugins::Suggester::Settings;

# Web settings page for the Suggester plugin. Slim::Web::Settings handles the
# read/save round-trip: prefs() declares which prefs this page owns, and the
# template (basic.html) names its inputs "pref_<name>" so the base handler maps
# them automatically. Validation is enforced on the pref itself (see Plugin.pm).

use strict;
use warnings;

use base qw(Slim::Web::Settings);

use Slim::Utils::Prefs;

my $prefs = preferences('plugin.suggester');

sub name {
	return Slim::Web::HTTP::CSRF->protectName('PLUGIN_SUGGESTER');
}

sub page {
	return Slim::Web::HTTP::CSRF->protectURI('plugins/Suggester/settings/basic.html');
}

sub prefs {
	return ($prefs, qw(count));
}

1;
