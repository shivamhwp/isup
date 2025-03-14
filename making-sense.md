### is it imp to make a db file or can we store these sites, their states etc. in a txt or a json file as well.

1. the reason is that sqlite can provide atomicity (ensures the db operations are either done or failed, no in between state).
2. sqlite provides concurrent access ( mutliple reader access, but only single writer access at a time(i didn't know this) ).
3. now the obvious ones, easily query, sort, filter etc. the data. can define schema. and the biggest one indexes for faster lookup.

now if we think about json etc. that doesn't make sense.

1. perf issues : each update will require reading, writing.
2. race conditions : if the bg-service and cli edits at same time, one change might overwrite the another.
3. memory issues : whole dataset needs to be loaded.

<br>

### connection pooling.
