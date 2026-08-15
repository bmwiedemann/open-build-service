#
# Copyright (c) 2026 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2 as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program (see the file COPYING); if not, write to the
# Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA
#
################################################################
#
# content-digest suffixes for published rpm filenames
# (PublishFlags: uniquefilenames)
#

package BSPublisher::UniqueFilenames;

use Build;

use strict;

# insert a digest component before the arch:
#   bash-5.2.15-1.2.x86_64.rpm -> bash-5.2.15-1.2.a3f9c1d20b7e.x86_64.rpm
sub digestname {
  my ($p, $digest, $digits) = @_;
  return $p unless $digest && $p =~ /\.([^.\/]+)\.(d?rpm)$/;
  my $hex = substr($digest, 0, $digits);
  return $p if $p =~ /\.\Q$hex\E\.[^.\/]+\.d?rpm$/;	# already digested
  $p =~ s/\.([^.\/]+)\.(d?rpm)$/.$hex.$1.$2/;
  return $p;
}

# rewrite the publisher's path-keyed hashes so that all rpms/drpms get
# digest-suffixed published names. returns the oldpath -> newpath map.
sub rename_bins {
  my ($bins, $bins_id, $binaryorigins, $deltainfos, $digits, $digestcache) = @_;
  my %renamed;
  my $newdigestcache = {};
  for my $p (sort keys %$bins) {
    next unless $p =~ /\.d?rpm$/;
    my $digest = $digestcache->{$bins_id->{$p}};
    if (!$digest) {
      eval { Build::queryhdrmd5($bins->{$p}, \$digest) };
      warn($@) if $@;
    }
    next unless $digest;
    $newdigestcache->{$bins_id->{$p}} = $digest;
    my $np = digestname($p, $digest, $digits);
    next if $np eq $p;
    $renamed{$p} = $np;
    $bins->{$np} = delete $bins->{$p};
    $bins_id->{$np} = delete $bins_id->{$p};
    $binaryorigins->{$np} = delete $binaryorigins->{$p} if exists $binaryorigins->{$p};
    if ($deltainfos->{$p}) {
      my $dinfo = $deltainfos->{$np} = delete $deltainfos->{$p};
      $_->{'filename'} = $np for @{$dinfo->{'delta'} || []};
    }
    # also rename the provenance sibling so the pairing rule keeps holding
    my $provenance = $p;
    if ($provenance =~ s/\.d?rpm$/.slsa_provenance.json/ && exists $bins->{$provenance}) {
      my $nprovenance = $np;
      $nprovenance =~ s/\.d?rpm$/.slsa_provenance.json/;
      $renamed{$provenance} = $nprovenance;
      $bins->{$nprovenance} = delete $bins->{$provenance};
      $bins_id->{$nprovenance} = delete $bins_id->{$provenance};
      $binaryorigins->{$nprovenance} = delete $binaryorigins->{$provenance} if exists $binaryorigins->{$provenance};
    }
  }
  %$digestcache = %$newdigestcache;	# prune entries for vanished binaries
  return \%renamed;
}

1;
