use strict;
use warnings;

use JSON;
use YAML;
use Config::INI::Reader;
use File::Slurp;
use Data::Dumper;

my $json = read_file('manifest.json');
my $manifest = decode_json($json);
    my $desktop_user = $manifest->{'general'}->{'desktop_user'};

my @tasks;

my @data = {
    'name' => 'generated playbook',
    'hosts' => 'localhost',
    'connection' => 'local',
    'remote_user' => 'root',
    'vars' => {
        'dektop_user' => $manifest->{'general'}->{'desktop_user'},
        'distro_revision' => $manifest->{'general'}->{'distro_release'}
    },
    'tasks' => \@tasks
};

sub add_rm {
    my ($path) = @_;
    my (@add, @rm);

    foreach (@{$path}) {
        if (rindex($_, '+', 0) == 0) {
            push (@add, substr($_, 1));
        }
        if (rindex($_, '-', 0) == 0) {
            push (@rm, substr($_, 1));
        }
    }

    return {
        'add' => [@add],
        'rm' => [@rm]
    }
}

sub copr {
    my ($json_path) = @_;

    my @add = @{add_rm($json_path)->{'add'}};
    my @rm = @{add_rm($json_path)->{'rm'}};

    if (@add) {
        push @tasks, {
            'name' => 'add copr repos',
            'community.general.copr' => {
                'host' => 'copr.fedorainfracloud.org',
                'state' => 'enabled',
                'name' => '{{ item }}'
            },
            'loop' => \@add
        };
    }

    if (@rm) {
        push @tasks, {
            'name' => 'remove copr repos',
            'community.general.copr' => {
                'host' => 'copr.fedorainfracloud.org',
                'state' => 'disabled',
                'name' => '{{ item }}'
            },
            'loop' => \@rm
        };
    }
}

sub dnf {
    my ($json_path) = @_;

    my @add = @{add_rm($json_path)->{'add'}};
    my @rm = @{add_rm($json_path)->{'rm'}};

    if (@add) {
        push @tasks, {
            'name' => 'install dnf packages',
            'dnf' => {
                'name' => "{{ item }}",
                'update_cache' => 'yes',
                'disable_gpg_check' => 'yes',
                'state' => 'present'
            },
            'loop' => \@add
        };
    }

    if (@rm) {
        push @tasks, {
            'name' => 'remove dnf packages',
            'dnf' => {
                'name' => "{{ item }}",
                'state' => 'absent'
            },
            'loop' => \@rm
        };
    }
}

sub dnf_update {
    my ($json_path) = @_;
    if ($json_path eq 'yes') {
        push @tasks, {
            'name' => 'update all dnf packages',
            'dnf' => {
                'name' => "*",
                'state' => 'latest'
            }
        }
    }
}

sub dnf_extra {
    my ($json_path) = @_;
    foreach (@{$json_path}) {
        if ($_->{'key'}) {
            push @tasks, {
                'name' => sprintf('add %s rpm key', $_->{'package'}),
                    'rpm_key' => {
                    'state' => 'present',
                    'key' => $_->{'key'}
                }
            };
        }
        push @tasks, {
            'name' => sprintf('add %s yum repo', $_->{'package'}),
            'yum_repository' => {
                'name' => $_->{'package'},
                'description' => $_->{'package'},
                'baseurl' => $_->{'repo'},
                'enabled' => 'yes'
            }
        };

        if ($_->{'present'} eq 'yes') {
            dnf([sprintf('+%s', $_->{'package'})]);
        }
        if ($_->{'present'} eq 'no') {
            dnf([sprintf('-%s', $_->{'package'})]);
        }
    }
}

sub flatpak {
    my ($json_path) = @_;

    foreach (@{$json_path}) {
        my @add = @{add_rm($_->{'packages'})->{'add'}};
        my @rm = @{add_rm($_->{'packages'})->{'rm'}};

        if (@add or @rm) {
            push @tasks, {
                'name' => sprintf('enable %s remote', $_->{'remote'}),
                'flatpak_remote' => {
                    'name' => $_->{'remote'},
                    'state' => 'present',
                    'flatpakrepo_url' => $_->{'url'},
                    'method' => 'user'
                },
                'become' => 'yes',
                'become_user' => $desktop_user
            };
        }

        if (@add) {
            push @tasks, {
                'name' => sprintf('install from %s remote', $_->{'remote'}),
                'flatpak' => {
                    'name' => '{{ item }}',
                    'remote' => $_->{'remote'},
                    'state' => 'present',
                    'method' => 'user'
                },
                'become' => 'yes',
                'become_user' => $desktop_user,
                'loop' => \@add
            };
        }

        if (@rm) {
            push @tasks, {
                'name' => sprintf('remove from %s remote', $_->{'remote'}),
                'flatpak' => {
                    'name' => '{{ item }}',
                    'remote' => $_->{'remote'},
                    'state' => 'absent',
                    'method' => 'user'
                },
                'become' => 'yes',
                'become_user' => $desktop_user,
                'loop' => \@rm
            };
        }
    }
}

sub kernel {
    my ($json_path) = @_;

    if (@{$json_path}) {
        my $options_line = join(' ', @{$json_path});
        push @tasks, {
            'name' => 'adjust kernel parameters',
            'ini_file' => {
                'path' => '/etc/default/grub',
                'option' => 'GRUB_CMDLINE_LINUX',
                'value' => "\"$options_line\"",
                'no_extra_spaces' => 'yes',
                'section' => 'null'
            }
        };
        push @tasks, {
            'name' => 'update grub',
            'shell' => 'grub2-mkconfig --output=/boot/grub2/grub.cfg'
        };
    }
}

sub systemd {
    my ($json_path) = @_;
    my @add = @{add_rm($json_path)->{'add'}};
    my @rm = @{add_rm($json_path)->{'rm'}};

    if (@add) {
        push @tasks, {
            'name' => 'enable services',
            'systemd' => {
                'name' => "{{ item }}",
                'state' => 'started',
                'enabled' => 'yes'
            },
            'loop' => \@add
        };
    }

    if (@rm) {
        push @tasks, {
            'name' => 'disable services',
            'systemd' => {
                'name' => "{{ item }}",
                'state' => 'stopped',
                'enabled' => 'no'
            },
            'loop' => \@rm
        };
    }
}

sub rpmfusion {
    my ($json_path) = @_;
    my $server = 'https://download1.rpmfusion.org';
    my $dnf_state;

    if ($json_path eq 'yes') {
        $dnf_state = 'present';
    } else {
        $dnf_state = 'absent'
    }

    my @loop = (
        sprintf(
            '%s/free/fedora/rpmfusion-free-release-%s.noarch.rpm',
            $server, $manifest->{'general'}->{'distro_release'}
        ),
        sprintf(
            '%s/nonfree/fedora/rpmfusion-nonfree-release-%s.noarch.rpm',
            $server, $manifest->{'general'}->{'distro_release'}
        )
    );

    push @tasks, {
        'name' => 'configure rpmfusion',
        'dnf' => {
            'name' => "{{ item }}",
            'disable_gpg_check' => 'yes',
            'state' => $dnf_state
        },
        'loop' => \@loop
    };
}

sub dconf {
    my ($json_path) = @_;

    push @tasks, {
        'name' => 'import dconf dump',
        'shell' => sprintf('dconf load / < %s', $json_path)
    }
}

copr($manifest->{'system'}->{'copr_repos'});
dnf($manifest->{'system'}->{'packages'});
dnf_extra($manifest->{'system'}->{'third_party'});
rpmfusion($manifest->{'general'}->{'rpmfusion'});
dnf_update($manifest->{'general'}->{'update_all'});
flatpak($manifest->{'user'}->{'flatpak'});
kernel($manifest->{'kernel'}->{'options'});
systemd($manifest->{'system'}->{'services'});
dconf($manifest->{'user'}->{'dconf'});

print YAML::Dump(\@data);
