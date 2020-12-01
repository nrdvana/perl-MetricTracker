use Test2::V0;
use MetricTracker;

my $heap= [];

MetricTracker::_heap_insert_node($heap, MetricTracker::Watch->new(next_t => 1));
is( $heap, [ object { call next_t => 1; } ], 'insert 1' );

MetricTracker::_heap_remove_node($heap, $heap->[0]);
is( $heap, [], 'remove 1' );

# Random adds and deletes
subtest rand_mutations => sub {
	$heap= [];
	MetricTracker::_heap_insert_node($heap, MetricTracker::Watch->new(next_t => int rand 100))
		for 1..75;
	is( scalar @$heap, 75, '75 inserts' );
	MetricTracker::_heap_remove_node($heap, $heap->[int rand scalar @$heap])
		for 1..20;
	is( scalar @$heap, 55, '20 removes' );
	my $prev= 0;
	while (@$heap) {
		if ($prev > $heap->[0]->next_t) {
			fail('nondecreasing order');
			diag join ' ', map $_->next_t, @$heap;
			last;
		}
		MetricTracker::_heap_remove_node($heap, $heap->[0]);
	}
	pass('nondecreasing order') unless @$heap;
};

done_testing;
