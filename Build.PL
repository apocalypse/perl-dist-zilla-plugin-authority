# Build.PL
use strict; use warnings;
use Module::Build;

my $build = Module::Build->new(
	# look up Module::Build::API for the info!
	'dynamic_config'	=> 0,
	'module_name'		=> 'Dist::Zilla::Plugin::Authority',
	'license'		=> 'perl',

	'dist_abstract'		=> 'add an $AUTHORITY to your packages',
	'dist_author'		=> 'Apocalypse <APOCAL@cpan.org>',

	'create_packlist'	=> 1,
	'create_makefile_pl'	=> 'traditional',
	'create_readme'		=> 1,
	'create_license'	=> 1,
	'sign'			=> 0,

	'test_files'		=> 't/*.t',

	'build_requires'	=> {
		'Test::More'	=> '0.94',
	},

	'requires'		=> {
		# To use Dzil
		'Dist::Zilla::Role::MetaProvider'	=> '2.101170',
		'Dist::Zilla::Role::FileMunger'		=> '2.101170',
		'Dist::Zilla::Role::FileFinderUser'	=> '2.101170',
		'Moose'					=> '1.01',
		'Moose::Util::TypeConstraints'		=> '1.01',

		# For the mangling of the files
		'PPI'					=> '1.206',

		# we need a recent perl
		'perl'					=> '5.008',
	},

	# include the standard stuff in META.yml
	'meta_merge'	=> {
		'resources'	=> {
			'license'	=> 'http://dev.perl.org/licenses/',
			'homepage'	=> 'http://search.cpan.org/dist/Dist-Zilla-Plugin-Authority',
			'bugtracker'	=> 'http://rt.cpan.org/NoAuth/Bugs.html?Dist=Dist-Zilla-Plugin-Authority',
			'repository'	=> 'http://github.com/apocalypse/perl-dist-zilla-plugin-authority',
		},
	},
);

# all done!
$build->create_build_script;
