#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;

use_ok("BSPublisher::UniqueFilenames");

my $digest = 'a3f9c1d20b7e5566778899aabbccddee';

# digestname
is(BSPublisher::UniqueFilenames::digestname('x86_64/bash-5.2.15-1.2.x86_64.rpm', $digest, 12),
   'x86_64/bash-5.2.15-1.2.a3f9c1d20b7e.x86_64.rpm', 'normal rpm');
is(BSPublisher::UniqueFilenames::digestname('SRPMS/bash-5.2.15-1.2.src.rpm', $digest, 12),
   'SRPMS/bash-5.2.15-1.2.a3f9c1d20b7e.src.rpm', 'src rpm');
is(BSPublisher::UniqueFilenames::digestname('x86_64/bash-5.2.15-1.2.nosrc.rpm', $digest, 12),
   'x86_64/bash-5.2.15-1.2.a3f9c1d20b7e.nosrc.rpm', 'nosrc rpm');
is(BSPublisher::UniqueFilenames::digestname('x86_64/bash-5.2.15-1_5.2.15-2.x86_64.drpm', $digest, 12),
   'x86_64/bash-5.2.15-1_5.2.15-2.a3f9c1d20b7e.x86_64.drpm', 'drpm');
is(BSPublisher::UniqueFilenames::digestname('noarch/tex-2024-1.noarch.rpm', $digest, 16),
   'noarch/tex-2024-1.a3f9c1d20b7e5566.noarch.rpm', 'digit count honored');
is(BSPublisher::UniqueFilenames::digestname('x86_64/a.b.c-1-1.x86_64.rpm', $digest, 12),
   'x86_64/a.b.c-1-1.a3f9c1d20b7e.x86_64.rpm', 'dots in name');
is(BSPublisher::UniqueFilenames::digestname('x86_64/weird.rpm', $digest, 12),
   'x86_64/weird.rpm', 'no arch component is left alone');
is(BSPublisher::UniqueFilenames::digestname('x86_64/bash-1-1.a3f9c1d20b7e.x86_64.rpm', $digest, 12),
   'x86_64/bash-1-1.a3f9c1d20b7e.x86_64.rpm', 'already digested name is left alone');
is(BSPublisher::UniqueFilenames::digestname('x86_64/bash-1-1.x86_64.rpm', undef, 12),
   'x86_64/bash-1-1.x86_64.rpm', 'undef digest is a no-op');

# the digest suffix must not confuse the publisher's filename consumers
my $np = BSPublisher::UniqueFilenames::digestname('x86_64/kernel-debuginfo-6.4-1.1.x86_64.rpm', '0af9c1d20b7e', 12);
like((split('/', $np))[1], qr/^([^\/]+)-[^-]+-[^-]+\.[a-zA-Z][^\/\.\-]*\.rpm$/, 'search index regex still matches');
like($np, qr/-debug(?:info|source)-.*rpm$/, 'dbgsplit filter still matches');

# rename_bins
my %bins = (
  'x86_64/bash-5.2.15-1.2.x86_64.rpm' => '/repo/x86_64/:repo/bash-5.2.15-1.2.x86_64.rpm',
  'x86_64/bash-5.2.15-1.2.x86_64.slsa_provenance.json' => '/repo/x86_64/:repo/bash-5.2.15-1.2.x86_64.slsa_provenance.json',
  'x86_64/bash-5.2.15-1_5.2.15-2.x86_64.drpm' => '/repo/x86_64/:repo/bash-5.2.15-1_5.2.15-2.x86_64.drpm',
  'x86_64/image.iso' => '/repo/x86_64/:repo/image.iso',
);
my %bins_id = (
  'x86_64/bash-5.2.15-1.2.x86_64.rpm' => '100/200/300',
  'x86_64/bash-5.2.15-1.2.x86_64.slsa_provenance.json' => '101/201/301',
  'x86_64/bash-5.2.15-1_5.2.15-2.x86_64.drpm' => '102/202/302',
  'x86_64/image.iso' => '103/203/303',
);
my %binaryorigins = (
  'x86_64/bash-5.2.15-1.2.x86_64.rpm' => 'bash',
  'x86_64/bash-5.2.15-1.2.x86_64.slsa_provenance.json' => 'bash',
  'x86_64/bash-5.2.15-1_5.2.15-2.x86_64.drpm' => 'bash',
);
my %deltainfos = (
  'x86_64/bash-5.2.15-1_5.2.15-2.x86_64.drpm' => {
    'name' => 'bash',
    'delta' => [ { 'filename' => 'x86_64/bash-5.2.15-1_5.2.15-2.x86_64.drpm', 'sequence' => 'xx' } ],
  },
);
my $digestcache = {
  '100/200/300' => $digest,
  '102/202/302' => '0123456789abcdef0123456789abcdef',
  'stale/1/2' => 'feedfacefeedfacefeedfacefeedface',
};

my $renamed = BSPublisher::UniqueFilenames::rename_bins(\%bins, \%bins_id, \%binaryorigins, \%deltainfos, 12, $digestcache);

is_deeply($renamed, {
  'x86_64/bash-5.2.15-1.2.x86_64.rpm' => 'x86_64/bash-5.2.15-1.2.a3f9c1d20b7e.x86_64.rpm',
  'x86_64/bash-5.2.15-1.2.x86_64.slsa_provenance.json' => 'x86_64/bash-5.2.15-1.2.a3f9c1d20b7e.x86_64.slsa_provenance.json',
  'x86_64/bash-5.2.15-1_5.2.15-2.x86_64.drpm' => 'x86_64/bash-5.2.15-1_5.2.15-2.0123456789ab.x86_64.drpm',
}, 'renamed map');

ok($bins{'x86_64/bash-5.2.15-1.2.a3f9c1d20b7e.x86_64.rpm'}, 'rpm key renamed in bins');
ok(!exists($bins{'x86_64/bash-5.2.15-1.2.x86_64.rpm'}), 'old rpm key gone');
is($bins_id{'x86_64/bash-5.2.15-1.2.a3f9c1d20b7e.x86_64.rpm'}, '100/200/300', 'bins_id follows');
is($binaryorigins{'x86_64/bash-5.2.15-1.2.a3f9c1d20b7e.x86_64.rpm'}, 'bash', 'binaryorigins follows');
ok($bins{'x86_64/bash-5.2.15-1.2.a3f9c1d20b7e.x86_64.slsa_provenance.json'}, 'provenance sibling renamed');
ok(!exists($bins{'x86_64/bash-5.2.15-1.2.x86_64.slsa_provenance.json'}), 'old provenance key gone');
is($bins{'x86_64/image.iso'}, '/repo/x86_64/:repo/image.iso', 'non-rpm untouched');
my $dinfo = $deltainfos{'x86_64/bash-5.2.15-1_5.2.15-2.0123456789ab.x86_64.drpm'};
ok($dinfo, 'deltainfo key renamed');
is($dinfo->{'delta'}->[0]->{'filename'}, 'x86_64/bash-5.2.15-1_5.2.15-2.0123456789ab.x86_64.drpm', 'delta filename rewritten');
ok(!exists($digestcache->{'stale/1/2'}), 'stale cache entry pruned');
is($digestcache->{'100/200/300'}, $digest, 'live cache entry kept');

# missing digest and unreadable file: entry stays under its plain name
{
  local $SIG{__WARN__} = sub {};
  my %bins2 = ( 'x86_64/gone-1-1.x86_64.rpm' => '/nonexistent/gone-1-1.x86_64.rpm' );
  my %bins_id2 = ( 'x86_64/gone-1-1.x86_64.rpm' => '1/2/3' );
  my $renamed2 = BSPublisher::UniqueFilenames::rename_bins(\%bins2, \%bins_id2, {}, {}, 12, {});
  is_deeply($renamed2, {}, 'unreadable file is not renamed');
  ok($bins2{'x86_64/gone-1-1.x86_64.rpm'}, 'unreadable file keeps plain name');
}

done_testing();
