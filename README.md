# warewulf-imagebuilder

A self-contained example of an Ansible-driven [Warewulf](https://warewulf.org/) node image
build pipeline. The `wwimgbuild` role renders Apptainer definitions, builds sandboxes on the
Warewulf control node, imports each one into Warewulf under its image name, and assigns it
to the node profile of the same name.

## Layout

```
ansible.cfg                       force_handlers=True (required), inventory and roles paths
inventory/hosts.yml               phony target: ww-control-node in group example_cluster
inventory/group_vars/example_cluster/
  warewulf.yml                    warewulf_cluster_name, warewulf_images, archive_dir
  images.yml                      variables consumed by the definitions (OS, kernel pin, Warewulf version, ...)
  secrets.yml                     node_root_password_hash (encrypt with ansible-vault before use)
playbooks/                        deploy_nodes.yml
roles/wwimgbuild/                 the pipeline role
  templates/example/definitions/  base.def.j2 -> user.def.j2 -> login.def.j2
  files/build-context/example/    files available inside each image build
```

`warewulf_cluster_name` selects the per-cluster source trees inside the role, so one role and
one playbook can serve several clusters. Add a second group under `head` with its own
`warewulf_cluster_name`, `roles/wwimgbuild/templates/<name>/definitions/` and
`roles/wwimgbuild/files/build-context/<name>/` to build a second cluster.

## Example image chain

| Image | Builds from | Contents |
|-------|-------------|----------|
| `base` | Rocky Linux mirror (`Bootstrap: dnf`) | kernel, core OS, `warewulf-dracut`, common tools, dracut emergency-reboot module, timezone service |
| `user` | `base` sandbox | Slurm client, munge, Apptainer, Lmod, user tooling, cluster profile script |
| `login` | `user` sandbox | firewalld, fail2ban, `user.slice` resource limits |

Only `login` is meant to boot nodes. `base` and `user` are intermediate layers, but the
role treats every image uniformly, so a Warewulf profile with the matching name must
exist for each (see [Prerequisites](#prerequisites)).

## Build flow

The build is handler-driven: tasks only stage the build context and render the definition,
and `notify` when something changed. The handler chain then archives the definition, removes
the old sandbox, runs `apptainer build --sandbox`, imports the result with
`wwctl image import --force <image>`, runs `wwctl image build`, sets the image on the
`<image>` profile, and rebuilds overlays. The chain is flushed at the end of each image so the
next image can build from the finished sandbox. Unchanged images are skipped unless
`force=true`. See [`roles/wwimgbuild/README.md`](roles/wwimgbuild/README.md).

## Setup

```bash
make install        # uv sync + ansible-galaxy collection install
```

Then edit `inventory/hosts.yml` to point `ww-control-node` at your control node, review
`inventory/group_vars/example_cluster/*.yml`, and encrypt `secrets.yml`:

```bash
ansible-vault encrypt inventory/group_vars/example_cluster/secrets.yml
```

Uncomment `vault_password_file` in `ansible.cfg` so playbooks can decrypt it.

## Usage

Image names are tags; no tags means every image in `warewulf_images`, in order.

```bash
# Build images and import them into Warewulf
ansible-playbook playbooks/deploy_nodes.yml -t base
ansible-playbook playbooks/deploy_nodes.yml -t user,login

# Force a full rebuild even with no source changes
ansible-playbook playbooks/deploy_nodes.yml -e "force=true"
```

## Prerequisites

On the control node:

- Warewulf 4.6 or newer installed and configured (`wwctl image ...` command set)
- A node profile named after each image in `warewulf_images` (`wwctl profile add base user login`)
- Outbound access to the Rocky mirror, EPEL, and GitHub, or local mirrors substituted into the definitions
- Enough disk under `sandbox_build_dir` for one sandbox per image

## Conventions

- Booleans are lowercase `true`/`false`.
- Files in the build context ending in `.j2` are rendered by Ansible at build time with the
  suffix stripped. Files ending in `.vault` are vault-encrypted whole files, decrypted on copy
  with the suffix stripped. Everything else is copied verbatim.
- Definitions reference staged files via `{{ build_context_dest }}` and chain via
  `{{ sandbox_build_dir }}/<previous image>`.
- Definitions and build context live inside the role under `templates/<cluster>/` and
  `files/build-context/<cluster>/`, selected by `warewulf_cluster_name`.

## License

MIT. See [LICENSE](LICENSE).
