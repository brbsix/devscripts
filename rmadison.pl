#!/usr/bin/perl -w
# vim:sw=4:sta:

# Copyright (C) 2006 Christoph Berg <myon@debian.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301 USA

use strict;
use Getopt::Long;

my $VERSION = '0.1';

sub version($) {
    my ($fd) = @_;
    print $fd "rmadison $VERSION (C) 2006 Christoph Berg <myon\@debian.org>\n";
}

sub usage($$) {
    my ($fd, $exit) = @_;
    print <<EOT;
Usage: rmadison [OPTION] PACKAGE[...]
Display information about PACKAGE(s).

  -a, --architecture=ARCH    only show info for ARCH(s)
  -b, --binary-type=TYPE     only show info for binary TYPE
  -c, --component=COMPONENT  only show info for COMPONENT(s)
  -g, --greaterorequal       show buildd 'dep-wait pkg >= {highest version}' info
  -G, --greaterthan          show buildd 'dep-wait pkg >> {highest version}' info
  -h, --help                 show this help and exit
  -s, --suite=SUITE          only show info for this suite
  -S, --source-and-binary    show info for the binary children of source pkgs

ARCH, COMPONENT and SUITE can be comma (or space) separated lists, e.g.
    --architecture=m68k,i386
EOT
    exit $exit;
}

my $params;
Getopt::Long::config('bundling');
unless (GetOptions(
    '-a=s'                =>  \$params->{'architecture'},
    '--architecture=s'    =>  \$params->{'architecture'},
    '-b=s'                =>  \$params->{'binary-type'},
    '--binary-type=s'     =>  \$params->{'binary-type'},
    '-c=s'                =>  \$params->{'component'},
    '--component=s'       =>  \$params->{'component'},
    '-g'                  =>  \$params->{'greaterorequal'},
    '--greaterorequal'    =>  \$params->{'greaterorequal'},
    '-G'                  =>  \$params->{'greaterthan'},
    '--greaterthan'       =>  \$params->{'greaterthan'},
    '-h'                  =>  \$params->{'help'},
    '--help'              =>  \$params->{'help'},
    '-r'                  =>  \$params->{'regex'},
    '--regex'             =>  \$params->{'regex'},
    '-s=s'                =>  \$params->{'suite'},
    '--suite=s'           =>  \$params->{'suite'},
    '-S'                  =>  \$params->{'source-and-binary'},
    '--source-and-binary' =>  \$params->{'source-and-binary'},
    '--version'           =>  \$params->{'version'},
)) {
    usage(\*STDERR, 1);
};

if ($params->{help}) {
    usage(\*STDOUT, 0);
}
if ($params->{version}) {
    version(\*STDOUT);
    exit 0;
}

unless (@ARGV) {
    print STDERR "E: need at least one package name as an argument.\n";
    exit 1;
}
if ($params->{regex}) {
    print STDERR "E: rmadison does not support the -r --regex option.\n";
    exit 1;
}
if ($params->{greaterorequal} and $params->{greaterthan}) {
    print STDERR "E: -g/--greaterorequal and -G/--greaterthan are mutually exclusive.\n";
    exit 1;
}

my @args;
push @args, "a=$params->{'architecture'}" if $params->{'architecture'};
push @args, "b=$params->{'binary-type'}" if $params->{'binary-type'};
push @args, "c=$params->{'component'}" if $params->{'component'};
push @args, "g" if $params->{'greaterorequal'};
push @args, "G" if $params->{'greaterthan'};
push @args, "s=$params->{'suite'}" if $params->{'suite'};
push @args, "S" if $params->{'source-and-binary'};

my @cmd = -x "/usr/bin/curl" ? qw/curl/ : qw/wget -q -O -/;
system @cmd, "http://qa.debian.org/madison.php?package=" .
    join("+", @ARGV) . "&text=on&" . join ("&", @args);

=pod

=head1 NAME

rmadison -- Remotely query the Debian archive database about packages

=head1 SYNOPSIS

=over

=item B<rmadison> [I<options>] I<package> ...

=back

=head1 DESCRIPTION

The B<madison> tool queries the Debian archive database ("projectb") and
displays which package version is registered per architecture/component/suite.
The CGI at B<http://qa.debian.org/madison.php> provides that service without
requiring ssh access to ftp-master.debian.org or the mirror on
merkel.debian.org. This script, B<rmadison>, is a command line frontend to
this CGI.

=head1 OPTIONS

=over

=item B<-a>, B<--architecture=ARCH>

only show info for ARCH(s)

=item B<-b>, B<--binary-type=TYPE>

only show info for binary TYPE

=item B<-c>, B<--component=COMPONENT>

only show info for COMPONENT(s)

=item B<-g>, B<--greaterorequal>

show buildd 'dep-wait pkg >= {highest version}' info

=item B<-G>, B<--greaterthan>

show buildd 'dep-wait pkg >> {highest version}' info

=item B<-h>, B<--help>

show this help and exit

=item B<-r>, B<--regex>

treat PACKAGE as a regex. Since that can easily DoS the database ("-r ."), this
option is not supported by the CGI and rmadison.

=item B<-s>, B<--suite=SUITE>

only show info for this suite

=item B<-S>, B<--source-and-binary>

show info for the binary children of source pkgs

=item B<--version>

show version and exit

=back

ARCH, COMPONENT and SUITE can be comma (or space) separated lists, e.g.
--architecture=m68k,i386

=head1 SEE ALSO

madison-lite(1), madison(1).

=head1 AUTHOR

rmadison and http://qa.debian.org/madison.php were written by Christoph Berg
<myon@debian.org>. madison itself is part of dak, written by 
James Troup <james@nocrew.org>, Anthony Towns <ajt@debian.org>, and others.

=cut
