use strict;
use warnings;

system('sudo dnf install -y ansible git');

system('perl manifest_to_playbook.pl');
