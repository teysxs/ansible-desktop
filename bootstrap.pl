use strict;
use warnings;

my @deps = [
    'git',
    'ansible',
    'perl-JSON'
];

system(
    sprintf(
        'sudo dnf install -y --refresh %s',
        join(' ', \@deps)
    )
);

system('perl manifest_to_playbook.pl');
