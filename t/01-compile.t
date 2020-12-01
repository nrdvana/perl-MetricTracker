use Test2::V0;

eval { use MetricTracker; 1 } or bail_out($@);

is( MetricTracker->new, object { etc; }, 'Create empty MetricTracker' );

done_testing;
