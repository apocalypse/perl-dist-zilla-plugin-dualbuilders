package Dist::Zilla::Plugin::DualBuilders;

# ABSTRACT: Allows use of Module::Build and ExtUtils::MakeMaker in a dzil dist

use Moose 1.03;

with 'Dist::Zilla::Role::PrereqSource' => { -version => '3.101461' };
with 'Dist::Zilla::Role::InstallTool' => { -version => '3.101461' };

=attr prefer

Sets your preferred builder. This builder will be the one added to the prereqs. Valid options are: "make" or "build".

The default is: build

=cut

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
			$self->log_debug( 'Preferring Module::Build, removing ExtUtils::MakeMaker from prereqs' );
		} elsif ( $self->prefer eq 'make' ) {
			# Get rid of MB stuff
			$self->_buildver( $config_hash->{'Module::Build'} );

			# As of DZIL v2.101170 DZ:P:ModuleBuild adds to configure and build
			$config_prereq->clear_requirement( 'Module::Build' );
			$build_prereq->clear_requirement( 'Module::Build' );
			$self->log_debug( 'Preferring ExtUtils::MakeMaker, removing Module::Build from prereqs' );
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

=for stopwords MakeMaker ModuleBuild dist dzil prereq prereqs

=for Pod::Coverage register_prereqs setup_installer

=head1 DESCRIPTION

This plugin allows you to specify ModuleBuild and MakeMaker in your L<Dist::Zilla> F<dist.ini> and select
only one as your prereq. Normally, if this plugin is not loaded you will end up with both in your prereq list
and this is obviously not what you want!

	# In your dist.ini:
	[ModuleBuild]
	[MakeMaker] ; or [MakeMaker::Awesome], will work too :)
	[DualBuilders] ; needs to be specified *AFTER* the builders

=head1 SEE ALSO
Dist::Zilla

=cut
