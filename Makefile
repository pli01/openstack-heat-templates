#
#
#
stack_name ?=
stack_dir  := openstack-heat/DEFAULT

heat_template := heat.yaml
heat_template_opt := $(shell [ -f "$(stack_dir)/$(heat_template)" ] && echo "-t $(stack_dir)/$(heat_template)" || exit 1)

heat_parameters ?= heat-parameters-$(stack_name).yaml
heat_parameters_opt := $(shell [ -f "$(stack_dir)/$(heat_parameters)" ] && echo "-e $(stack_dir)/$(heat_parameters)" || exit 1)

registry := env.yaml
registry_path := $(shell [ -f "$(stack_dir)/$(registry)" ] && echo "$(stack_dir)/$(registry)" )
registry_opt := $(shell [ -f "$(stack_dir)/$(registry)" ] && echo "-e $(stack_dir)/$(registry)" )

openstack_opt := --insecure
openstack_cli := openstack $(openstack_opt)
heat_cli := heat $(openstack_opt)

FORCE    := false

all:
	@echo make build [stack_dir=$(stack_dir)] [stack_name=$(stack_name)]
	@echo            [heat_template=$(heat_template)] [heat_parameters=$(heat_parameters)] [registry=$(registry)]

build-all: syntax is-running clean build show

build: syntax build-$(stack_name)
	@echo "build: Stack $(stack_name) created"
build-$(stack_name):
	@echo build-$(stack_name): create stack $(stack_name) from $(stack_dir)
	@openstack_cli="$(openstack_cli)" \
           heat_template_opt="$(heat_template_opt)" registry_opt="$(registry_opt)" heat_parameters_opt="$(heat_parameters_opt)" \
           bash ./tools/stack-build.sh "$(stack_name)"

syntax-heat-env:
	@echo syntax-heat-env: $(registry) $(registry_path) $(registry_opt)
syntax-heat-template:
	@echo syntax-heat-template: $(heat_template) $(heat_template_opt)
syntax-heat-parameters:
	@echo syntax-heat-parameters: $(heat_parameters) $(heat_parameters_opt)

syntax: $(stack_dir)/$(heat_template) $(stack_dir)/$(heat_parameters) syntax-heat-template syntax-heat-env syntax-heat-parameters syntax-$(stack_name)
	@echo syntax: Template $(stack_name) validated
syntax-$(stack_name):
	@echo syntax-$(stack_name): validate template $(stack_dir)
	@if $(openstack_cli) --help |grep  "orchestration template validate" ; then \
	  $(openstack_cli) orchestration template validate $(heat_template_opt) $(registry_opt) $(heat_parameters_opt) ; \
	else \
	  $(heat_cli) -k template-validate -f $(stack_dir)/$(heat_template)  $(registry_opt)  $(heat_parameters_opt) ; \
	fi

show: show-$(stack_name)
show-$(stack_name):
	@echo "show-$(stack_name): show stack $(stack_name)"
	@$(openstack_cli) stack show -f json $(stack_name) || true
	@echo

is-running: is-running-$(stack_name)
is-running-$(stack_name):
	@echo "is-running-$(stack_name): show stack $(stack_name)"
	@if $(openstack_cli) stack show -f json $(stack_name) ; then echo ; echo "$(stack_name) is running" ; $(FORCE) ; else true ; fi

is-ready: show-$(stack_name) is-ready-$(stack_name)
is-ready-$(stack_name): SHELL:=/bin/bash
is-ready-$(stack_name):
	@openstack_cli="$(openstack_cli)" bash ./tools/stack-is-ready.sh "$(stack_name)"
	echo "Stack $(stack_name) ready"

clean: clean-$(stack_name)
	@echo "clean: Stack $(stack_name) deleted"
clean-$(stack_name): 
	@echo "clean-$(stack_name): delete stack $(stack_name)"
	@$(openstack_cli) stack show $(stack_name) && $(openstack_cli) stack delete --yes $(stack_name) || true
	@$(openstack_cli) stack event list $(stack_name) --follow || true

list:
	@echo "list: list stack"
	@$(openstack_cli) stack list

status:
	@$(openstack_cli) stack list --property stack_name=$(stack_name)

DESTDIR  ?= dist
GIT_URL_REPO ?= $(shell git config --get remote.origin.url)
GIT_REPO ?= $(shell basename $(GIT_URL_REPO) .git)
GIT_BRANCH ?= master
GIT_BUNDLE=$(GIT_REPO)_$(GIT_BRANCH).bundle
PACKAGENAME ?= $(GIT_REPO)
VERSION ?= $(GIT_BRANCH)
GIT_ARCHIVE=$(PACKAGENAME)-$(VERSION).tar.gz

clean-package:
	if [ -d $(DESTDIR) ] ; then rm -rf $(DESTDIR) ; fi
package: clean-package
	if [ ! -d "$(DESTDIR)" ] ; then mkdir -p $(DESTDIR) ; fi
	git archive $(GIT_BRANCH) | gzip > $(DESTDIR)/$(GIT_ARCHIVE)
bundle:
	git bundle create $(DESTDIR)/$(GIT_BUNDLE) $(GIT_BRANCH) && gzip -c $(DESTDIR)/$(GIT_BUNDLE) > $(DESTDIR)/$(GIT_BUNDLE).gz
unbundle:
	test -f $(DESTDIR)/$(GIT_BUNDLE).gz && gunzip -f $(DESTDIR)/$(GIT_BUNDLE).gz

publish: $(DESTDIR)/$(PACKAGENAME)-$(VERSION).tar.gz
	@echo "# $@ STARTING"
	bash ./tools/publish.sh $(PACKAGENAME) $(VERSION)
	@echo '# $@ SUCCESS'
