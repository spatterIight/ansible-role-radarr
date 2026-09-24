<!--
SPDX-FileCopyrightText: 2020 Aaron Raimist
SPDX-FileCopyrightText: 2020 Chris van Dijk
SPDX-FileCopyrightText: 2020 Dominik Zajac
SPDX-FileCopyrightText: 2020 Mickaël Cornière
SPDX-FileCopyrightText: 2020-2024 MDAD project contributors
SPDX-FileCopyrightText: 2020-2024 Slavi Pantaleev
SPDX-FileCopyrightText: 2022 François Darveau
SPDX-FileCopyrightText: 2022 Julian Foad
SPDX-FileCopyrightText: 2022 Warren Bailey
SPDX-FileCopyrightText: 2023 Antonis Christofides
SPDX-FileCopyrightText: 2023 Felix Stupp
SPDX-FileCopyrightText: 2023 Pierre 'McFly' Marty
SPDX-FileCopyrightText: 2024-2026 Suguru Hirahara

SPDX-License-Identifier: AGPL-3.0-or-later
-->

# Setting up Radarr

This is an [Ansible](https://www.ansible.com/) role which installs [Radarr](https://radarr.video/) to run as a [Docker](https://www.docker.com/) container wrapped in a systemd service.

Radarr is a movie organizer/manager for Usenet and BitTorrent users.

See the project's [documentation](https://wiki.servarr.com/radarr) to learn what Radarr does and why it might be useful to you.

## Adjusting the playbook configuration

To enable Radarr with this role, add the following configuration to your `vars.yml` file.

**Note**: the path should be something like `inventory/host_vars/mash.example.com/vars.yml` if you use the [MASH Ansible playbook](https://github.com/mother-of-all-self-hosting/mash-playbook).

```yaml
########################################################################
#                                                                      #
# radarr                                                               #
#                                                                      #
########################################################################

radarr_enabled: true

########################################################################
#                                                                      #
# /radarr                                                              #
#                                                                      #
########################################################################
```

### Set the hostname

To enable Radarr you need to set the hostname as well. To do so, add the following configuration to your `vars.yml` file. Make sure to replace `example.com` with your own value.

```yaml
radarr_hostname: "example.com"
```

After adjusting the hostname, make sure to adjust your DNS records to point the domain to your server.

>[!NOTE]
> The `radarr_path_prefix` variable can be adjusted to host under a subpath (e.g. `radarr_path_prefix: /radarr`), but this hasn't been tested yet.

### Mounting additional data directories (optional)

To mount additional data directories, add the following configuration to your `vars.yml` file (adapt to your needs):

```yaml
radarr_container_additional_volumes:
  - type: bind
    src: /path/to/blackhole
    dst: /downloads
```

### Extending the configuration

There are some additional things you may wish to configure about the service.

Take a look at:

- [`defaults/main.yml`](../defaults/main.yml) for some variables that you can customize via your `vars.yml` file. You can override settings (even those that don't have dedicated playbook variables) using the `radarr_environment_variables_additional_variables` variable

### Notes on configuration

A freshly installed Radarr has no authentication of its own, and this role does not add any. Radarr also serves its API key to unauthenticated callers on `/initialize.json`, and that key is enough to drive the whole API. It is recommended to turn authentication on under *Settings -> General -> Security* in Radarr itself, or put a middleware in front of it through `radarr_container_labels_additional_labels`, before making an installation reachable from the internet.

## Installing

After configuring the playbook, run the installation command of your playbook as below:

```sh
ansible-playbook -i inventory/hosts setup.yml --tags=setup-all,start
```

If you use the MASH playbook, the shortcut commands with the [`just` program](https://github.com/mother-of-all-self-hosting/mash-playbook/blob/main/docs/just.md) are also available: `just install-all` or `just setup-all`

## Usage

After running the command for installation, Radarr becomes available at the specified hostname like `https://example.com`.

To get started, open the URL with a web browser to create an account. The recommended authentication method is `Forms (Login Page)`.

## Troubleshooting

### Check the service's logs

You can find the logs in [systemd-journald](https://www.freedesktop.org/software/systemd/man/systemd-journald.service.html) by logging in to the server with SSH and running `journalctl -fu radarr` (or how you/your playbook named the service, e.g. `mash-radarr`).
