use strict;
use warnings;

my $deps = [
    'git',
    'ansible',
    'perl-JSON',
    'perl-YAML',
    'perl-Config-INI',
    'perl-File-Slurp',
    'perl-File-chdir',
    'perl-File-Path',
    'perl-Git-Repository',
    'perl-Digest-SHA1',
    'perl-DateTime'
];

system(sprintf('sudo dnf install -y --refresh %s', join(' ', @{$deps} )));

system('perl manifest_to_playbook.pl');
