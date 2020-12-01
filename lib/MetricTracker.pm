package MetricTracker;
use Moo 2;
use Carp;
use MetricTracker::Watch;

has metrics         => ( is => 'rw', coerce => \&_coerce_metrics, default => sub { +{} } );
has storage         => ( is => 'rw', coerce => \&_coerce_storage );
has commit_interval => ( is => 'rw' );
has wait_resolution => ( is => 'rw' );

has _time_reference => ( is => 'rw' );
has _last_commit    => ( is => 'rw' );
has _watch_sets     => ( is => 'rw', default => sub { +{} } );
has _watch_queue    => ( is => 'rw', default => sub { [] } );

sub update_metric {
	my ($self, $name, $update, $autocreate_as)= @_;
	my $metric= $self->metrics->{$name}
		|| $self->metrics->storage->get($name)
		|| $autocreate_as? $autocreate_as->new
			: croak "No such metric '$name'";
	my $value= $metric->update($update);
	if (my $watches= $self->_watch_sets->{$name}) {
		for (@$watches) {
			$_->update($value);
			$self->_requeue_watch($_);
		}
	}
}

sub on {
	my ($self, $name, $spec)= @_;
	my $watch= MetricTracker::Watch->new($spec);
	push @{ $self->{_watch_sets}{$name} }, $watch;
	$self->_requeue_watch($watch);
}

sub _requeue_watch {
	my ($self, $watch)= @_;
	_heap_update_node($self->_watch_queue, $watch);
}

# Heap algorithm on the array in _watch_queue
sub _heap_update_node {
	my ($heap, $node)= @_;
	my $ofs= $node->_heap_ofs;
	if (defined $ofs) {
		# must be greater/equal to its parent, and less/equal to both children
		my $t= $node->next_t;
		if ($t >= $heap->[int(($ofs-1)/2)]->next_t
			and (!$heap->[$ofs*2+1] or $t <= $heap->[$ofs*2+1]->next_t)
			and (!$heap->[$ofs*2+2] or $t <= $heap->[$ofs*2+2]->next_t)
		) {
			return; # nothing needs to change
		}
		# else remove the item from the heap
		_heap_remove_node($heap, $node);
	}
	# Add the item to the heap
	_heap_insert_node($heap, $node);
}

sub _heap_remove_node {
	my ($heap, $node)= @_;
	my $ofs= $node->_heap_ofs;
	while ($ofs*2+1 < @$heap) {
		# replace with the smaller of the node's children
		my $c1= $heap->[$ofs*2+1];
		my $c2= $heap->[$ofs*2+2];
		if ($c2 && $c2->next_t <= $c1->next_t) {
			$heap->[$ofs]= $c2;
			$c2->_heap_ofs($ofs);
			$ofs= $ofs*2+2;
		}
		else {
			$heap->[$ofs]= $c1;
			$c1->_heap_ofs($ofs);
			$ofs= $ofs*2+1;
		}
	}
	my $last= pop @$heap;
	_heap_insert_node($heap, $last, $ofs) unless $ofs == @$heap;
	$node->_heap_ofs(undef);
}

sub _heap_insert_node {
	my ($heap, $node, $ofs)= @_;
	$ofs= @$heap unless defined $ofs;
	my $p_ofs= int(($ofs-1)/2);
	while ($ofs > 0 && $heap->[$p_ofs]->next_t > $node->next_t) {
		$heap->[$ofs]= $heap->[$p_ofs];
		$heap->[$ofs]->_heap_ofs($ofs);
		$ofs= $p_ofs;
		$p_ofs= int(($ofs-1)/2);
	}
	$heap->[$ofs]= $node;
	$node->_heap_ofs($ofs);
}

sub time_til_event {
	
}

sub idle_time {
	my $self= shift;
	return $self->idle_end - $self->_time_reference->();
}

sub _coerce_metrics {
	my ($self, $arg)= @_;
	return {} unless defined $arg;
	my %ret= %$arg;
	$_= MetricTracker::Metric->new($_) for values %ret;
	return \%ret;
}

sub _coerce_storage {
	my ($self, $arg)= @_;
	return !defined $arg? undef
		: ref $arg eq 'HASH'? MetricTracker::HashStorage->new($arg)
		: ref($arg)->can('set')? $arg
		: croak "Don't know how to coerce $arg to a Storage object (expect get/set, or hashref)";
}

1;
