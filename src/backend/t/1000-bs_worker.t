#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 17;


use FindBin;
use lib "$FindBin::Bin/lib/";

use BSUtil;
use Test::Mock::BSConfig;
use Test::Mock::BSRPC;

use JSON::XS ();


@::ARGV = ('--testcase');
require_ok('./bs_worker');

my ($json_true, $json_false) = @{JSON::XS::decode_json('[ true, false ]')};

$BSConfig::bsdir = $FindBin::Bin;
my $tmpdir = "$FindBin::Bin/tmp/1000";
BSUtil::mkdir_p($tmpdir);
BSUtil::cleandir($tmpdir);
die("could not create tmpdir $tmpdir\n") unless -d $tmpdir;

my $buildinfo = {
  srcserver  => $BSConfig::srcserver,
  project    => 'project1',
  package    => 'package1',
  srcmd5     => 'f157738ddea737a2b7479996175a6cec',
  verifymd5  => 'f157738ddea737a2b7479996175a6cec',
  file       => 'hello_world.spec',
  bdep       => [
                  {
                    'notmeta' => '1',
                    'name' => 'liblua5_4-5',
                    'preinstall' => '1'
                  },
                  {
                    'name' => 'aaa_base',
                    'notmeta' => '1',
                    'preinstall' => '1'
                  },
                  {
                    'preinstall' => '1',
                    'name' => 'filesystem',
                    'notmeta' => '1'
                  },
                ],
  path       => [
                  {
                    'server' => 'http://reposerver',
                    'repository' => 'openSUSE_Tumbleweed',
                    'project' => 'home:Admin'
                  },
                  {
                    'project' => 'openSUSE.org:openSUSE:Factory',
                    'server' => 'http://srcserver',
                    'repository' => 'snapshot'
                  },
                  {
                    'project' => 'openSUSE.org:openSUSE:Tumbleweed',
                    'server' => 'http://srcserver',
                    'repository' => 'standard'
                  },
                  {
                    'repository' => 'dod',
                    'server' => 'http://srcserver',
                    'project' => 'openSUSE.org:openSUSE:Tumbleweed'
                  },
                  {
                    'repository' => 'ports',
                    'server' => 'http://srcserver',
                    'project' => 'openSUSE.org:openSUSE:Factory'
                  }
                ],
  arch       => 'x86_64',
  slsaprovenance => 1,
  slsabuilder => "https://my.api",
};

$Test::Mock::BSRPC::fixtures_map = {
  # getsources
  "srcserver/getsources?project=project1&package=package1&srcmd5=$buildinfo->{srcmd5}"
    => 'data/1000/srcserver/getsources',

  # getfollowupsources
  'reposerver/getjobdata?job=job1&arch=x86_64&jobid=jobid1'
    => 'data/1000/reposerver/getjobdata_followup1.cpio',
  'reposerver/getjobdata?job=job2&arch=x86_64&jobid=jobid2'
    => 'data/1000/reposerver/getjobdata_followup2.cpio',
  "srcserver/source/project1/package1?rev=$buildinfo->{srcmd5}"
    => 'data/1000/srcserver/source_project1_package1',

  # getbinaries
  'reposerver/getbinaries?project=home:Admin&repository=openSUSE_Tumbleweed&arch=x86_64&binaries=liblua5_4-5,aaa_base,filesystem'
    => 'data/1000/reposerver/getbinaries_empty.cpio',
  'srcserver/getbinaries?project=openSUSE.org:openSUSE:Factory&repository=snapshot&arch=x86_64&binaries=liblua5_4-5,aaa_base,filesystem'
    => 'data/1000/srcserver/getbinaries_empty.cpio',
  'srcserver/getbinaries?project=openSUSE.org:openSUSE:Tumbleweed&repository=standard&arch=x86_64&binaries=liblua5_4-5,aaa_base,filesystem'
    => 'data/1000/srcserver/getbinaries_empty.cpio',
  'srcserver/getbinaries?project=openSUSE.org:openSUSE:Tumbleweed&repository=dod&arch=x86_64&binaries=liblua5_4-5,aaa_base,filesystem'
    => 'data/1000/srcserver/getbinaries.cpio',
};

my ($got, @got, @expected);


# getsources

@got = getsources($buildinfo, $tmpdir);
@expected = ('f157738ddea737a2b7479996175a6cec  package1');
is_deeply(\@got, \@expected, 'getsources - Return value');

my $expected_material_for_source = {
  'digest' => { 'sha256' => 'e237d5c5ea2b4dd327d2e103afd09572286609fbc9bf43cc9609f1371b4c8dd2' },
  'uri' => 'srcserver/source/project1/package1/hello_world.spec?rev=f157738ddea737a2b7479996175a6cec',
  'intent' => 'source',
  'name' => 'hello_world.spec',
};
my $expected_materials = [
  $expected_material_for_source
];
is_deeply($buildinfo->{'materials'}, $expected_materials, "getsources - Add 'materials' of sources to \$buildinfo");


# getbinaries

my ($dir, $srcdir, $preinstallimagedata, $origins) = (
  "$tmpdir/var/cache/obs/worker/root_1/.pkgs",
  "$tmpdir/var/cache/obs/worker/root_1/.build-srcdir",
  undef,
  undef
);

@got = getbinaries($buildinfo, $dir, $srcdir, $preinstallimagedata, $origins);
@expected = ();
is_deeply(\@got, \@expected, 'getbinaries - Return value');

$expected_materials = [
  $expected_material_for_source,
  {
    'digest' => { 'sha256' => 'acf63da2befc85cee24689330ddf62629681e59b5007fa3ffca09ff789f7cb28' },
    'uri' => 'srcserver/slsa/openSUSE.org:openSUSE:Tumbleweed/dod/x86_64/aaa_base.rpm/acf63da2befc85cee24689330ddf62629681e59b5007fa3ffca09ff789f7cb28',
    'name' => 'aaa_base.rpm',
    'intent' => 'buildenv',
  },
  {
    'digest' => { 'sha256' => 'be546d31264bf3ea084cd6c0bb659872eef0388583983379a72edfb26f021680' },
    'uri' => 'srcserver/slsa/openSUSE.org:openSUSE:Tumbleweed/dod/x86_64/filesystem.rpm/be546d31264bf3ea084cd6c0bb659872eef0388583983379a72edfb26f021680',
    'name' => 'filesystem.rpm',
    'intent' => 'buildenv',
  },
  {
    'digest' => { 'sha256' => '80c185cd2f7d2cc9960308a9ce07d97b20c098d7a71008ba7d74dfd1031cfe26' },
    'uri' => 'srcserver/slsa/openSUSE.org:openSUSE:Tumbleweed/dod/x86_64/liblua5_4-5.rpm/80c185cd2f7d2cc9960308a9ce07d97b20c098d7a71008ba7d74dfd1031cfe26',
    'name' => 'liblua5_4-5.rpm',
    'intent' => 'buildenv',
  }
];
is_deeply($buildinfo->{'materials'}, $expected_materials, "getbinaries - Add 'materials' of binaries to \$buildinfo");

BSUtil::cleandir($tmpdir);
rmdir($tmpdir);


# generate_slsa_provenance_statement_v02 and generate_slsa_provenance_statement_v1

my @send = (
  # An original filename would be:
  # 'filename' => '/var/cache/obs/worker/root_1/.build.packages/RPMS/x86_64/hello_world-1-4.1.x86_64.rpm',
  {
    'filename' => "$FindBin::Bin/data/shared/buildresult/rpm/hello_world-1-4.1.x86_64.rpm",
    'name' => 'hello_world-1-4.1.x86_64.rpm'
  },
  {
    'filename' => "$FindBin::Bin/data/shared/buildresult/rpm/hello_world-1-4.1.src.rpm",
    'name' => 'hello_world-1-4.1.src.rpm'
  },
  {
    'filename' => "$FindBin::Bin/data/shared/buildresult/rpm/_buildenv",
    'name' => '_buildenv'
  },
  {
    'filename' => "$FindBin::Bin/data/shared/buildresult/rpm/_statistics",
    'name' => '_statistics'
  },
  {
    'filename' => "$FindBin::Bin/data/shared/buildresult/rpm/rpmlint.log",
    'name' => 'rpmlint.log'
  } 
);

$got = generate_slsa_provenance_statement_v02($buildinfo, \@send);
$got = JSON::XS::decode_json($got);
my $expected_statement_v02 = {
  '_type' => 'https://in-toto.io/Statement/v0.1',
  'subject' => [
    {
      'name' => 'hello_world-1-4.1.x86_64.rpm',
      'digest' => { 'sha256' => 'c81e3c817819fb27e74b4d0feae3bf6621c9d49cba51553743456e8cd894e678' },
    },
    {
      'name' => 'hello_world-1-4.1.src.rpm',
      'digest' => { 'sha256' => '927eaebc503a4f508a17231bd430e5320e1ba89e1fa56b428452c0b0e16ac2ef' },
    }
  ],
  'predicateType' => 'https://slsa.dev/provenance/v0.2',
  'predicate' => {
    'buildType' => 'https://open-build-service.org/worker',
    'builder' => {
      'id' => 'https://my.api',
    },
    'invocation' => {
      'configSource' => {
        'uri' => 'srcserver/source/project1/package1?rev=f157738ddea737a2b7479996175a6cec',
        'entryPoint' => 'hello_world.spec',
      },
    },
    'metadata' => {
      'completeness' => {
        'parameters' => $json_true,
        'environment' => $json_true,
        'materials' => $json_true,
      },
      'reproducible' => $json_false,
    },
    'materials' => [
      {
	'digest' => { 'sha256' => 'e237d5c5ea2b4dd327d2e103afd09572286609fbc9bf43cc9609f1371b4c8dd2' },
	'uri' => 'srcserver/source/project1/package1/hello_world.spec?rev=f157738ddea737a2b7479996175a6cec',
      },
      {
	'digest' => { 'sha256' => 'acf63da2befc85cee24689330ddf62629681e59b5007fa3ffca09ff789f7cb28' },
	'uri' => 'srcserver/slsa/openSUSE.org:openSUSE:Tumbleweed/dod/x86_64/aaa_base.rpm/acf63da2befc85cee24689330ddf62629681e59b5007fa3ffca09ff789f7cb28',
      },
      {
	'digest' => { 'sha256' => 'be546d31264bf3ea084cd6c0bb659872eef0388583983379a72edfb26f021680' },
	'uri' => 'srcserver/slsa/openSUSE.org:openSUSE:Tumbleweed/dod/x86_64/filesystem.rpm/be546d31264bf3ea084cd6c0bb659872eef0388583983379a72edfb26f021680',
      },
      {
	'digest' => { 'sha256' => '80c185cd2f7d2cc9960308a9ce07d97b20c098d7a71008ba7d74dfd1031cfe26' },
	'uri' => 'srcserver/slsa/openSUSE.org:openSUSE:Tumbleweed/dod/x86_64/liblua5_4-5.rpm/80c185cd2f7d2cc9960308a9ce07d97b20c098d7a71008ba7d74dfd1031cfe26',
      }
    ],
  }
};
is_deeply($got, $expected_statement_v02, 'generate_slsa_provenance_statement_v02 - Return value');

$got = generate_slsa_provenance_statement_v1($buildinfo, \@send);
$got = JSON::XS::decode_json($got);

my $expected_statement_v1 = {
  '_type' => 'https://in-toto.io/Statement/v0.1',
  'subject' => [
    {
      'name' => 'hello_world-1-4.1.x86_64.rpm',
      'digest' => { 'sha256' => 'c81e3c817819fb27e74b4d0feae3bf6621c9d49cba51553743456e8cd894e678' },
    },
    {
      'name' => 'hello_world-1-4.1.src.rpm',
      'digest' => { 'sha256' => '927eaebc503a4f508a17231bd430e5320e1ba89e1fa56b428452c0b0e16ac2ef' },
    }
  ],
  'predicateType' => 'https://slsa.dev/provenance/v1',
  'predicate' => {
    'buildDefinition' => {
    'buildType' => 'https://open-build-service.org/worker',
    'externalParameters' => {
      'source' => 'srcserver/source/project1/package1?rev=f157738ddea737a2b7479996175a6cec',
      'recipeFile' => 'hello_world.spec',
    },
    'resolvedDependencies' => [
      {
	'name' => 'hello_world.spec',
	'digest' => { 'sha256' => 'e237d5c5ea2b4dd327d2e103afd09572286609fbc9bf43cc9609f1371b4c8dd2' },
	'uri' => 'srcserver/source/project1/package1/hello_world.spec?rev=f157738ddea737a2b7479996175a6cec',
	'annotations' => { 'intent' => 'source' },
      },
      {
	'name' => 'aaa_base.rpm',
	'digest' => { 'sha256' => 'acf63da2befc85cee24689330ddf62629681e59b5007fa3ffca09ff789f7cb28' },
	'uri' => 'srcserver/slsa/openSUSE.org:openSUSE:Tumbleweed/dod/x86_64/aaa_base.rpm/acf63da2befc85cee24689330ddf62629681e59b5007fa3ffca09ff789f7cb28',
	'annotations' => { 'intent' => 'buildenv', 'flags' => 'preinstall' },
      },
      {
	'name' => 'filesystem.rpm',
	'digest' => { 'sha256' => 'be546d31264bf3ea084cd6c0bb659872eef0388583983379a72edfb26f021680' },
	'uri' => 'srcserver/slsa/openSUSE.org:openSUSE:Tumbleweed/dod/x86_64/filesystem.rpm/be546d31264bf3ea084cd6c0bb659872eef0388583983379a72edfb26f021680',
	'annotations' => { 'intent' => 'buildenv', 'flags' => 'preinstall' },
      },
      {
	'name' => 'liblua5_4-5.rpm',
	'digest' => { 'sha256' => '80c185cd2f7d2cc9960308a9ce07d97b20c098d7a71008ba7d74dfd1031cfe26' },
	'uri' => 'srcserver/slsa/openSUSE.org:openSUSE:Tumbleweed/dod/x86_64/liblua5_4-5.rpm/80c185cd2f7d2cc9960308a9ce07d97b20c098d7a71008ba7d74dfd1031cfe26',
	'annotations' => { 'intent' => 'buildenv', 'flags' => 'preinstall' },
      }
    ],
    },
    'runDetails' => {
      'id' => 'https://my.api',
    },
  }
};
is_deeply($got, $expected_statement_v1, 'generate_slsa_provenance_statement_v1 - Return value');

# followup build: the results of the previous stage are materials

my $followup_buildinfo = {
  %$buildinfo,
  'file' => 'pesign-repackage.spec',
  'followupfile' => 'pesign-repackage.spec',
  'followupsteps' => 1,
  'followup_materials' => [
    { 'name' => 'hello_world-1-4.1.x86_64.rpm', 'digest' => { 'sha256' => '1111111111111111111111111111111111111111111111111111111111111111' }, 'intent' => 'source' },
    { 'name' => '_slsa_provenance.0.json', 'digest' => { 'sha256' => '2222222222222222222222222222222222222222222222222222222222222222' }, 'intent' => 'followup' },
  ],
};
$got = JSON::XS::decode_json(generate_slsa_provenance_statement_v1($followup_buildinfo, \@send));
is_deeply([ grep {!$_->{'uri'}} @{$got->{'predicate'}->{'buildDefinition'}->{'resolvedDependencies'}} ], [
  { 'name' => 'hello_world-1-4.1.x86_64.rpm', 'digest' => { 'sha256' => '1111111111111111111111111111111111111111111111111111111111111111' }, 'annotations' => { 'intent' => 'source' } },
  { 'name' => '_slsa_provenance.0.json', 'digest' => { 'sha256' => '2222222222222222222222222222222222222222222222222222222222222222' }, 'annotations' => { 'intent' => 'followup' } },
], 'generate_slsa_provenance_statement_v1 - followup materials');
is($got->{'predicate'}->{'buildDefinition'}->{'externalParameters'}->{'recipeFile'}, 'pesign-repackage.spec', 'generate_slsa_provenance_statement_v1 - followup recipe');
is($got->{'predicate'}->{'buildDefinition'}->{'externalParameters'}->{'followupstep'}, 1, 'generate_slsa_provenance_statement_v1 - followup step');
$got = JSON::XS::decode_json(generate_slsa_provenance_statement_v02($followup_buildinfo, \@send));
is_deeply([ grep {!$_->{'uri'}} @{$got->{'predicate'}->{'materials'}} ], [
  { 'name' => 'hello_world-1-4.1.x86_64.rpm', 'digest' => { 'sha256' => '1111111111111111111111111111111111111111111111111111111111111111' }, 'intent' => 'source' },
  { 'name' => '_slsa_provenance.0.json', 'digest' => { 'sha256' => '2222222222222222222222222222222222222222222222222222222222222222' }, 'intent' => 'followup' },
], 'generate_slsa_provenance_statement_v02 - followup materials');
is($got->{'predicate'}->{'invocation'}->{'parameters'}->{'followupstep'}, 1, 'generate_slsa_provenance_statement_v02 - followup step');

# getfollowupsources

sub sha256str { Digest::SHA::sha256_hex($_[0]) }

$followup_buildinfo = { %$buildinfo, 'reposerver' => 'reposerver', 'arch' => 'x86_64', 'job' => 'job1', 'jobid' => 'jobid1', 'followupfile' => 'pesign-repackage.spec', 'followupsteps' => 1 };
my $followupdir = "$tmpdir/followup1";
BSUtil::mkdir_p($followupdir);
getfollowupsources($followup_buildinfo, $followupdir);
is_deeply($followup_buildinfo->{'followup_materials'}, [
  { 'name' => 'hello_world-1-4.1.x86_64.rpm', 'digest' => { 'sha256' => sha256str("rpm1\n") }, 'intent' => 'source' },
  { 'name' => '_slsa_provenance.0.json', 'digest' => { 'sha256' => sha256str("{\"stage\":1}\n") }, 'intent' => 'followup' },
  { 'name' => 'pesign-repackage.spec', 'digest' => { 'sha256' => sha256str("spec\n") }, 'intent' => 'source' },
  { 'name' => 'hello_world.cpio.rsasign', 'digest' => { 'sha256' => sha256str("req\n") }, 'intent' => 'source' },
  { 'name' => 'hello_world.cpio.rsasign.sig', 'digest' => { 'sha256' => sha256str("sig\n") }, 'intent' => 'source' },
], 'getfollowupsources - materials of the first followup');
is_deeply($followup_buildinfo->{'followup_provenance_files'}, { '_slsa_provenance.0.json' => "{\"stage\":1}\n" }, 'getfollowupsources - provenance of the first stage');

$followup_buildinfo = { %$buildinfo, 'reposerver' => 'reposerver', 'arch' => 'x86_64', 'job' => 'job2', 'jobid' => 'jobid2', 'followupfile' => 'pesign-repackage.spec', 'followupsteps' => 2 };
$followupdir = "$tmpdir/followup2";
BSUtil::mkdir_p($followupdir);
getfollowupsources($followup_buildinfo, $followupdir);
is_deeply([ map {$_->{'name'}} grep {$_->{'intent'} eq 'followup'} @{$followup_buildinfo->{'followup_materials'}} ], [ '_slsa_provenance.0.json', '_slsa_provenance.1.json' ], 'getfollowupsources - materials of the second followup');
is_deeply($followup_buildinfo->{'followup_provenance_files'}, { '_slsa_provenance.0.json' => "{\"stage\":1}\n", '_slsa_provenance.1.json' => "{\"stage\":2}\n" }, 'getfollowupsources - provenance of the first two stages');

# getbinaries_product

$buildinfo = {
          'rev' => '2',
          'path' => [
                      {
                        'server' => 'http://reposerver',
                        'project' => 'home:Admin:OBS-Kiwi',
                        'repository' => 'OBS'
                      },
                      {
                        'server' => 'http://srcserver',
                        'project' => 'openSUSE.org:OBS:Server:Unstable',
                        'repository' => 'images'
                      },
                      {
                        'project' => 'openSUSE.org:OBS:Server:Unstable',
                        'server' => 'http://srcserver',
                        'repository' => '15.3'
                      },
                      {
                        'project' => 'openSUSE.org:openSUSE:Tools',
                        'server' => 'http://srcserver',
                        'repository' => '15.3'
                      },
                    ],
          'disturl' => 'obs://private/home:Admin:OBS-Kiwi/OBS/7aa92ea9f0986dc7d6280c12d856dca3-OBS-Kiwi',
          'jobid' => '9199941939110fd0cfe02ceab6b62564',
          'versrel' => '2.8.51-2',
          'package' => 'OBS-Kiwi',
          'needed' => '0',
          'file' => 'obs.kiwi',
          'srcserver' => 'http://srcserver',
          'imagetype' => [
                           'product'
                         ],
          'release' => '2.2',
          'nodbgpkgs' => '1',
          'project' => 'home:Admin:OBS-Kiwi',
          'arch' => 'x86_64',
          'reposerver' => 'http://reposerver',
          'job' => 'home:Admin:OBS-Kiwi::OBS::OBS-Kiwi-7aa92ea9f0986dc7d6280c12d856dca3',
          'prjconfconstraint' => [
                                   'linux:version:min 3.0.0'
                                 ],
          'reason' => 'new build',
          'verifymd5' => '7aa92ea9f0986dc7d6280c12d856dca3',
          'nosrcpkgs' => '1',
          'bcnt' => '2',
          'revtime' => '1652262990',
          'srcmd5' => '7aa92ea9f0986dc7d6280c12d856dca3',
          'syspath' => [
                         {
                           'project' => 'home:Admin:OBS-Kiwi',
                           'server' => 'http://reposerver',
                           'repository' => 'OBS'
                         },
                         {
                           'repository' => 'images',
                           'server' => 'http://srcserver',
                           'project' => 'openSUSE.org:OBS:Server:Unstable'
                         },
                         {
                           'repository' => '15.3',
                           'project' => 'openSUSE.org:OBS:Server:Unstable',
                           'server' => 'http://srcserver'
                         },
                         {
                           'server' => 'http://srcserver',
                           'project' => 'openSUSE.org:openSUSE:Tools',
                           'repository' => '15.3'
                         },
                       ],
          'readytime' => '1652341877',
          'repository' => 'OBS',
          'bdep' => [
                      {
                        'release' => '12.8',
                        'repoarch' => 'x86_64',
                        'repository' => '15.3',
                        'package' => '0product:OBS-Addon-release',
                        'version' => '2.8.51',
                        'name' => 'OBS-Addon-release',
                        'arch' => 'x86_64',
                        'project' => 'openSUSE.org:OBS:Server:Unstable'
                      },
                      {
                        'notmeta' => '1',
                        'name' => 'liblua5_4-5',
                        'preinstall' => '1'
                      },
                      {
                        'runscripts' => '1',
                        'preinstall' => '1',
                        'notmeta' => '1',
                        'name' => 'aaa_base'
                      },
                      {
                        'preinstall' => '1',
                        'name' => 'filesystem',
                        'notmeta' => '1'
                      },
                    ],
          'genmetaalgo' => '1'
        };
my $kiwiorigins = {};

$Test::Mock::BSRPC::fixtures_map = {
  # getbinaries
  'reposerver/getbinaries?project=home:Admin:OBS-Kiwi&repository=OBS&arch=x86_64&binaries=liblua5_4-5,aaa_base,filesystem'
    => 'data/1000/reposerver/getbinaries_empty.cpio',
  'srcserver/getbinaries?project=openSUSE.org:OBS:Server:Unstable&repository=images&arch=x86_64&binaries=liblua5_4-5,aaa_base,filesystem'
    => 'data/1000/srcserver/getbinaries_empty.cpio',
  'srcserver/getbinaries?project=openSUSE.org:OBS:Server:Unstable&repository=15.3&arch=x86_64&binaries=liblua5_4-5,aaa_base,filesystem'
    => 'data/1000/srcserver/getbinaries_empty.cpio',
  'srcserver/getbinaries?project=openSUSE.org:openSUSE:Tools&repository=15.3&arch=x86_64&binaries=liblua5_4-5,aaa_base,filesystem'
    => 'data/1000/srcserver/getbinaries.cpio',

  'srcserver/build/openSUSE.org:OBS:Server:Unstable/15.3/x86_64/0product:OBS-Addon-release?view=cpio'
    => 'data/1000/srcserver/build_openSUSE.org:OBS:Server:Unstable_15.3_x86_64_0product:OBS-Addon-release?view=cpio'
};

@got = getbinaries_product($buildinfo, $dir, $srcdir, $kiwiorigins);
@expected = ('c0f190787a4711126abe9d9273a1f6bd  openSUSE.org:OBS:Server:Unstable/15.3/x86_64/0product:OBS-Addon-release/OBS-Addon-release.x86_64');
is_deeply(\@got, \@expected, 'getbinaries_product - Return value');

BSUtil::cleandir($tmpdir);
rmdir($tmpdir);
