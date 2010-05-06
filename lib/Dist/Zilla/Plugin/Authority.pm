package Dist::Zilla::Plugin::Authority;
use strict; use warnings;
our $VERSION = '0.01';

use Moose 1.01;
use PPI 1.206;

# TODO wait for improved Moose that allows "with 'Foo::Bar' => { -version => 1.23 };"
use Dist::Zilla::Role::MetaProvider 2.101170;
use Dist::Zilla::Role::FileMunger 2.101170;
use Dist::Zilla::Role::FileFinderUser 2.101170;
with(
	'Dist::Zilla::Role::MetaProvider',
	'Dist::Zilla::Role::FileMunger',
	'Dist::Zilla::Role::FileFinderUser' => {
		default_finders => [ ':InstallModules' ],
	},
);

{
	use Moose::Util::TypeConstraints 1.01;

	subtype 'authority'
		=> as 'Str',
		=> where { $_ =~ /^\w+\:\w+$/ },
		=> message { "Authority must be in the form of 'cpan:PAUSEID'." };

	has authority => (
		is => 'ro',
		isa => 'authority',
		required => 1,
	);

	no Moose::Util::TypeConstraints;
}

has do_metadata => (
	is => 'ro',
	isa => 'Bool',
	default => 0,
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

	my $document = PPI::Document->new(\$content) or Carp::croak( PPI::Document->errstr );

	{
		my $code_only = $document->clone;
		$code_only->prune( "PPI::Token::$_" ) for qw( Comment Pod Quote Regexp );
		if ( $code_only->serialize =~ /\$AUTHORITY\s*=/sm ) {
			$self->log( sprintf( 'skipping %s: assigns to $AUTHORITY', $file->name ) );
			return;
		}
	}

	return unless my $package_stmts = $document->find('PPI::Statement::Package');

	for my $stmt ( @$package_stmts ) {
		my $package = $stmt->namespace;

		my $perl = "BEGIN {\n  \$$package\::AUTHORITY\x20=\x20'" . $self->authority . "';\n}\n";
		my $doc = PPI::Document->new( \$perl );
		my @children = $doc->schildren;

		$self->log_debug([
			'adding $AUTHORITY assignment in %s',
			$file->name,
		]);

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

=for stopwords AnnoCPAN CPAN CPANTS Kwalitee RT dist prereqs

=head1 NAME

Dist::Zilla::Plugin::Authority - add an $AUTHORITY to your packages

=head1 DESCRIPTION

This plugin adds the $AUTHORITY marker to your packages. Also, it can add the authority information
to the metadata, if requested.

	# In your dist.ini:
	[Authority]
	authority = cpan:APOCAL
	do_metadata = 1

This plugin accepts the following options:

=over 4

=item * authority

The authority you want to use. It should be something like C<cpan:APOCAL>. Required.

=item * do_metadata

A boolean value to control if the authority should be added to the metadata. Defaults to false.

The metadata will look like this:

	x_authority => 'cpan:APOCAL',

=back

=head1 SEE ALSO

L<Dist::Zilla>

L<http://www.perlmonks.org/?node_id=694377>

L<http://perlcabal.org/syn/S11.html#Versioning>

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

	perldoc Dist::Zilla::Plugin::Authority

=head2 Websites

=over 4

=item * Search CPAN

L<http://search.cpan.org/dist/Dist-Zilla-Plugin-Authority>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Dist-Zilla-Plugin-Authority>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Dist-Zilla-Plugin-Authority>

=item * CPAN Forum

L<http://cpanforum.com/dist/Dist-Zilla-Plugin-Authority>

=item * RT: CPAN's Request Tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Dist-Zilla-Plugin-Authority>

=item * CPANTS Kwalitee

L<http://cpants.perl.org/dist/overview/Dist-Zilla-Plugin-Authority>

=item * CPAN Testers Results

L<http://cpantesters.org/distro/D/Dist-Zilla-Plugin-Authority.html>

=item * CPAN Testers Matrix

L<http://matrix.cpantesters.org/?dist=Dist-Zilla-Plugin-Authority>

=item * Git Source Code Repository

L<http://github.com/apocalypse/perl-dist-zilla-plugin-authority>

=back

=head2 Bugs

Please report any bugs or feature requests to C<bug-dist-zilla-plugin-authority at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Dist-Zilla-Plugin-Authority>.  I will be
notified, and then you'll automatically be notified of progress on your bug as I make changes.

=head1 AUTHOR

Apocalypse E<lt>apocal@cpan.orgE<gt>

This module is basically a rip-off of RJBS' excellent L<Dist::Zilla::Plugin::PkgVersion>, thanks!

=head1 COPYRIGHT AND LICENSE

Copyright 2010 by Apocalypse

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

The full text of the license can be found in the LICENSE file included with this module.

=cut
