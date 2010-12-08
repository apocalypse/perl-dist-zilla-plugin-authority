package Dist::Zilla::Plugin::Authority;

# ABSTRACT: Add an $AUTHORITY to your packages

use Moose 1.03;
use PPI 1.206;

with(
	'Dist::Zilla::Role::MetaProvider' => { -version => '4.102345' },
	'Dist::Zilla::Role::FileMunger' => { -version => '4.102345' },
	'Dist::Zilla::Role::FileFinderUser' => {
		-version => '4.102345',
		default_finders => [ ':InstallModules', ':ExecFiles' ],
	},
);

=attr authority

The authority you want to use. It should be something like C<cpan:APOCAL>.

Defaults to the username set in the %PAUSE stash in the global config.ini or dist.ini ( Dist::Zilla v4 addition! )

=cut

{
	use Moose::Util::TypeConstraints 1.01;

	has authority => (
		is => 'ro',
		isa => subtype( 'Str'
			=> where { $_ =~ /^\w+\:\w+$/ }
			=> message { "Authority must be in the form of 'cpan:PAUSEID'" }
		),
		lazy => 1,
		default => sub {
			my $self = shift;
			my $stash = $self->zilla->stash_named( '%PAUSE' );
			if ( ! defined $stash ) {
				$self->log_fatal( 'PAUSE credentials not set in config.ini/dist.ini! Please set it or specify an authority for this plugin.' );
			}

			$self->log_debug( [ 'using PAUSE id "%s" for AUTHORITY', $stash->username ] );
			return 'cpan:' . $stash->username;
		},
	);

	no Moose::Util::TypeConstraints;
}

=attr do_metadata

A boolean value to control if the authority should be added to the metadata. ( META.yml or META.json )

Defaults to true.

The metadata will look like this:

	x_authority => 'cpan:APOCAL'

=cut

has do_metadata => (
	is => 'ro',
	isa => 'Bool',
	default => 1,
);

sub metadata {
	my( $self ) = @_;

	return if ! $self->do_metadata;

	$self->log_debug( 'adding AUTHORITY to metadata' );

	return {
		'x_authority'	=> $self->authority,
	};
}

sub munge_files {
	my( $self ) = @_;

	$self->_munge_file( $_ ) for @{ $self->found_files };
}

sub _munge_file {
	my( $self, $file ) = @_;

	return                           if $file->name    =~ /\.t$/i;
	return $self->_munge_perl($file) if $file->name    =~ /\.(?:pm|pl)$/i;
	return $self->_munge_perl($file) if $file->content =~ /^#!(?:.*)perl(?:$|\s)/;
	return;
}

sub _munge_perl {
	my( $self, $file ) = @_;

	my $content = $file->content;
	my $document = PPI::Document->new( \$content ) or Carp::croak( PPI::Document->errstr );

	{
		my $code_only = $document->clone;
		$code_only->prune( "PPI::Token::$_" ) for qw( Comment Pod Quote Regexp );
		if ( $code_only->serialize =~ /\$AUTHORITY\s*=/sm ) {
			$self->log( [ 'skipping %s: assigns to $AUTHORITY', $file->name ] );
			return;
		}
	}

	return unless my $package_stmts = $document->find('PPI::Statement::Package');

	my %seen_pkgs;

	for my $stmt ( @$package_stmts ) {
		my $package = $stmt->namespace;

		# Thanks to rafl ( Florian Ragwitz ) for this
		if ( $seen_pkgs{ $package }++ ) {
			$self->log( [ 'skipping package re-declaration for %s', $package ] );
			next;
		}

		# Thanks to autarch ( Dave Rolsky ) for this
		if ( $stmt->content =~ /package\s*(?:#.*)?\n\s*\Q$package/ ) {
			$self->log([ 'skipping private package %s', $package ]);
			next;
		}

		# Same \x20 hack as seen in PkgVersion, blarh!
		my $perl = "BEGIN {\n  \$$package\::AUTHORITY\x20=\x20'" . $self->authority . "';\n}\n";
		my $doc = PPI::Document->new( \$perl );
		my @children = $doc->schildren;

		$self->log_debug( [ 'adding $AUTHORITY assignment to %s in %s', $package, $file->name ] );

		Carp::carp( "error inserting AUTHORITY in " . $file->name )
			unless $stmt->insert_after( $children[0]->clone )
			and    $stmt->insert_after( PPI::Token::Whitespace->new("\n") );
	}

	$file->content( $document->serialize );
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;

=pod

=for :stopwords RJBS metadata FLORA dist ini json username yml

=for Pod::Coverage metadata munge_files

=head1 DESCRIPTION

This plugin adds the $AUTHORITY marker to your packages. Also, it can add the authority information
to the metadata, if requested.

	# In your dist.ini:
	[Authority]
	authority = cpan:APOCAL
	do_metadata = 1

The resulting hunk of code would look something like this:

	BEGIN {
	  $Dist::Zilla::Plugin::Authority::AUTHORITY = 'cpan:APOCAL';
	}

This code will be added to any package declarations in your perl files.

=head1 SEE ALSO

L<Dist::Zilla>
L<http://www.perlmonks.org/?node_id=694377>
L<http://perlcabal.org/syn/S11.html#Versioning>

=head1 ACKNOWLEDGEMENTS

This module is basically a rip-off of RJBS' excellent L<Dist::Zilla::Plugin::PkgVersion>, thanks!

Props goes out to FLORA for prodding me to improve this module!

=cut
