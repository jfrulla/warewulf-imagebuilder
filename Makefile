VENV_BIN := .venv/bin
UV ?= uv
ANSIBLE := $(VENV_BIN)/ansible

.PHONY: install lint syntax
install: $(ANSIBLE)
	$(ANSIBLE)-galaxy collection install -r requirements.yml

$(ANSIBLE):
	$(UV) sync

lint: $(ANSIBLE)
	$(VENV_BIN)/ansible-lint

syntax: $(ANSIBLE)
	$(VENV_BIN)/ansible-playbook --syntax-check playbooks/deploy_nodes.yml
