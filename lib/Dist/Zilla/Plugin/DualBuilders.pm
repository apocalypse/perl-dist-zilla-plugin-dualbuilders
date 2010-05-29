package Dist::Zilla::Plugin::DualBuilders;
use strict; use warnings;
our $VERSION = '0.03';

use Moose 1.01;

# TODO wait for improved Moose that allows "with 'Foo::Bar' => { -version => 1.23 };"
use Dist::Zilla::Role::PrereqSource 3.101461;
use Dist::Zilla::Role::InstallTool 3.101461;
with 'Dist::Zilla::Role::PrereqSource';
with 'Dist::Zilla::Role::InstallTool';

{
	use Moose::Util::TypeConstraints 1.01;

	has prefer => (
		is => 'ro',
		isa => enum( [ qw( build make ) ] ),
		default => 'build',
	);

	no Moose::Util::TypeConstraints;
}

has _buildver => (
	is => 'rw',
	isa => 'Str',
);

has _makever => (
	is => 'rw',
	isa => 'Str',
);

sub setup_installer {
	my ($self, $file) = @_;

	# This is to munge the files
	foreach my $file ( @{ $self->zilla->files } ) {
		if ( $file->name eq 'Build.PL' ) {
			if ( $self->prefer eq 'make' ) {
				$self->log_debug( "Munging Build.PL because we preferred ExtUtils::MakeMaker" );
				my $content = $file->content;
				$content =~ s/'ExtUtils::MakeMaker'\s+=>\s+'.+'/'Module::Build' => '${\$self->_buildver}'/g;

				# TODO do we need to add it to build_requires too? Or is config_requires and the use line sufficient?

				$file->content( $content );
			}
		} elsif ( $file->name eq 'Makefile.PL' ) {
			if ( $self->prefer eq 'build' ) {
				$self->log_debug( "Munging Makefile.PL because we preferred Module::Build" );
				my $content = $file->content;
				$content =~ s/'Module::Build'\s+=>\s+'.+'/'ExtUtils::MakeMaker' => '${\$self->_makever}'/g;

				# TODO since MB adds to build_requires, should we remove EUMM from it? I think it's ok to leave it in...

				$file->content( $content );
			}
		}
	}
}

sub register_prereqs {
	## no critic ( ProhibitAccessOfPrivateData )
	my ($self) = @_;

	# Find out if we have both builders loaded?
	my $config_prereq = $self->zilla->prereqs->requirements_for( 'configure', 'requires' );
	my $build_prereq = $self->zilla->prereqs->requirements_for( 'build', 'requires' );
	my $config_hash = defined $config_prereq ? $config_prereq->as_string_hash : {};
	if ( exists $config_hash->{'Module::Build'} and exists $config_hash->{'ExtUtils::MakeMaker'} ) {
		# conflict!
		if ( $self->prefer eq 'build' ) {
			# Get rid of EUMM stuff
			$self->_makever( $config_hash->{'ExtUtils::MakeMaker'} );

			# As of DZIL v2.101170 DZ:P:Makemaker adds to configure only
			$config_prereq->clear_requirement( 'ExtUtils::MakeMaker' );
			$self->log_debug( 'Preferring "build", removing ExtUtils::MakeMaker from prereqs' );
		} elsif ( $self->prefer eq 'make' ) {
			# Get rid of MB stuff
			$self->_buildver( $config_hash->{'Module::Build'} );

			# As of DZIL v2.101170 DZ:P:ModuleBuild adds to configure and build
			$config_prereq->clear_requirement( 'Module::Build' );
			$build_prereq->clear_requirement( 'Module::Build' );
			$self->log_debug( 'Preferring "make", removing Module::Build from prereqs' );
		}
	} elsif ( exists $config_hash->{'Module::Build'} and $self->prefer eq 'make' ) {
		$self->log_fatal( 'Detected Module::Build in the config but you preferred ExtUtils::MakeMaker!' );
	} elsif ( exists $config_hash->{'ExtUtils::MakeMaker'} and $self->prefer eq 'build' ) {
		$self->log_fatal( 'Detected ExtUtils::MakeMaker in the config but you preferred Module::Build!' );
	} elsif ( ! exists $config_hash->{'ExtUtils::MakeMaker'} and ! exists $config_hash->{'Module::Build'} ) {
		$self->log_fatal( 'Detected no builders loaded, please check your dist.ini!' );
	} else {
		# Our preference matched the builder loaded
	}
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;

=pod

=for stopwords AnnoCPAN CPAN CPANTS Kwalitee MakeMaker ModuleBuild RT dist dzil prereq prereqs

=head1 NAME

Dist::Zilla::Plugin::DualBuilders - Allows use of Module::Build and ExtUtils::MakeMaker in a dzil dist

=head1 DESCRIPTION

This plugin allows you to specify ModuleBuild and MakeMaker in your L<Dist::Zilla> F<dist.ini> and select
only one as your prereq. Normally, if this plugin is not loaded you will end up with both in your prereq list
and this is obviously not what you want!

	# In your dist.ini:
	[ModuleBuild]
	[MakeMaker] ; or [MakeMaker::Awesome], will work too :)
	[DualBuilders] ; needs to be specified *AFTER* the builders

This plugin accepts the following options:

=over 4

=item * prefer

Sets your preferred builder. This builder will be the one added to the prereqs. Valid options are: "make" or "build".

The default is: build

=back

=head1 SEE ALSO

L<Dist::Zilla>

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

	perldoc Dist::Zilla::Plugin::DualBuilders

=head2 Websites

=over 4

=item * Search CPAN

L<http://search.cpan.org/dist/Dist-Zilla-Plugin-DualBuilders>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Dist-Zilla-Plugin-DualBuilders>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Dist-Zilla-Plugin-DualBuilders>

=item * CPAN Forum

L<http://cpanforum.com/dist/Dist-Zilla-Plugin-DualBuilders>

=item * RT: CPAN's Request Tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Dist-Zilla-Plugin-DualBuilders>

=item * CPANTS Kwalitee

L<http://cpants.perl.org/dist/overview/Dist-Zilla-Plugin-DualBuilders>

=item * CPAN Testers Results

L<http://cpantesters.org/distro/D/Dist-Zilla-Plugin-DualBuilders.html>

=item * CPAN Testers Matrix

L<http://matrix.cpantesters.org/?dist=Dist-Zilla-Plugin-DualBuilders>

=item * Git Source Code Repository

L<http://github.com/apocalypse/perl-dist-zilla-plugin-dualbuilders>

=back

=head2 Bugs

Please report any bugs or feature requests to C<bug-dist-zilla-plugin-dualbuilders at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Dist-Zilla-Plugin-DualBuilders>.  I will be
notified, and then you'll automatically be notified of progress on your bug as I make changes.

=head1 AUTHOR

Apocalypse E<lt>apocal@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2010 by Apocalypse

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

The full text of the license can be found in the LICENSE file included with this module.

=cut
