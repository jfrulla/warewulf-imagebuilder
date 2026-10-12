# wwimgbuild

Builds Warewulf node images from Apptainer definitions. One role invocation builds one
image, named `image_name`, and assigns it to the node profile of the same name. The role is
cluster-agnostic: `warewulf_cluster_name` selects which per-cluster source tree is used.

## What it does

1. Creates the definition, sandbox, and build-context directories
2. Stages the image's build context (copying plain files, decrypting `.vault` files, rendering `.j2` files)
3. Renders the image's definition template
4. On change (or `force=true`), runs the handler chain: remove the old sandbox,
   `apptainer build --sandbox`, `wwctl image import --force` as `<image>`, `wwctl image build`,
   `wwctl profile set --image <image> <image>`, `wwctl overlay build`

Nothing happens when neither the definition nor the build context changed.

## Source layout

Given `warewulf_cluster_name` and `image_name`, the role reads from its own directory:

- `templates/<cluster>/definitions/<image>.def.j2` (Jinja template, inside the role)
- `files/build-context/<cluster>/<image>/` (any tree of files, inside the role)

and writes on the control node:

- `definition_dest_dir/<image>.def` (rendered definition)
- `build_context_dest_dir/<image>/` (staged build context, referenced in the definition's `%files`)
- `sandbox_build_dir/<image>` (the Apptainer sandbox, which later images use as `From:`)

## Variables

Set per run with `-e`:

| Variable | Default | Purpose |
|---|---|---|
| `force` | `false` | run the full build chain even with no source changes |

Set per cluster in `inventory/group_vars/<group>/warewulf.yml`:

| Variable | Purpose |
|---|---|
| `warewulf_cluster_name` | selects the source trees above |
| `warewulf_images` | ordered list of images; each is a playbook tag |

Everything else lives in `defaults/main.yml` and `vars/main.yml` and rarely needs changing.

## Handler chain

Handlers are named with `{{ image_name }}` so that one role invocation per image notifies
only its own chain. `tasks/main.yml` ends with `meta: flush_handlers` so image N finishes
before image N+1 (which builds from N's sandbox) starts. `force_handlers=True` in
`ansible.cfg` is required so a failed build does not leave notified handlers pending.

## Requirements

- Warewulf 4.6 or newer on the control node, with a node profile named after every image
- `community.general` collection (for the `filetree` lookup)
