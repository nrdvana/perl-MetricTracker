package MetricTracker::Watch;
use Moo 2;
use Carp;

has state          => ( is => 'rw' );
has next_t         => ( is => 'rw' );
has _heap_ofs      => ( is => 'rw' );

sub time_til_event {
	my ($self, $cur_t)= @_;
	return $self->next_t - $cur_t;
}

sub update {
	croak "unimplemented";
}

1;
