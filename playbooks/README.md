# Playbooks

Run from the repository root (`ansible.cfg` supplies the inventory, roles path, privilege
escalation, and `force_handlers`). Every image name is a tag.

| Playbook | Operation |
|---|---|
| `deploy_nodes.yml` | render definitions, build sandboxes, import them into Warewulf; rebuild with `force=true` |

```bash
ansible-playbook playbooks/deploy_nodes.yml -t base
ansible-playbook playbooks/deploy_nodes.yml -t user,login
ansible-playbook playbooks/deploy_nodes.yml -e "force=true"
```

The playbook loops `include_role: wwimgbuild` over `warewulf_images` with `image_name` as
the loop variable, filtered by the run tags. Images are processed in list order, which
matters because each definition builds from the previous image's sandbox.
