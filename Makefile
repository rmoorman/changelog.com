SHELL := bash# we want bash behaviour in all shell invocations

RED := $(shell tput setaf 1)
GREEN := $(shell tput setaf 2)
YELLOW := $(shell tput setaf 3)
BOLD := $(shell tput bold)
NORMAL := $(shell tput sgr0)

PLATFORM := $(shell uname)
ifneq ($(PLATFORM),Darwin)
ifneq ($(PLATFORM),Linux)
  $(warning $(RED)$(PLATFORM) is not supported$(NORMAL), only macOS and Linux are supported.)
  $(error $(BOLD)Please contribute support for your platform.$(NORMAL))
endif
endif

ifneq (4,$(firstword $(sort $(MAKE_VERSION) 4)))
  $(warning $(BOLD)$(RED)GNU Make v4 or newer is required$(NORMAL))
ifeq ($(PLATFORM),Darwin)
  $(info On macOS it can be installed with $(BOLD)brew install make$(NORMAL) and run as $(BOLD)gmake$(NORMAL))
endif
  $(error Please run with GNU Make v4 or newer)
endif

### VARS ###
#
export LC_ALL := en_US.UTF-8
export LANG := en_US.UTF-8

### DEPS ###
#
CURL := /usr/bin/curl

ifeq ($(PLATFORM),Darwin)
CASK := brew cask

DOCKER := /usr/local/bin/docker
$(DOCKER):
	@$(CASK) install docker

COMPOSE := $(DOCKER)-compose
$(COMPOSE):
	@[ -f $(COMPOSE) ] || (\
	  echo "Please install Docker via $(BOLD)brew cask docker$(NORMAL) so that $(BOLD)docker-compose$(NORMAL) will be managed in lock-step with Docker" && \
	  exit 1 \
	)

JQ := /usr/local/bin/jq
$(JQ):
	@brew install jq

LPASS := /usr/local/bin/lpass
$(LPASS):
	@brew install lastpass-cli
endif

ifeq ($(PLATFORM),Linux)
DOCKER := /usr/bin/docker
$(DOCKER):
	$(error $(RED)Please install $(BOLD)docker$(NORMAL))

COMPOSE := $(DOCKER)-compose
$(COMPOSE):
	$(error $(RED)Please install $(BOLD)docker-compose$(NORMAL))

$(CURL):
	$(error $(RED)Please install $(BOLD)curl$(NORMAL))

JQ := /usr/bin/jq
$(JQ):
	$(error $(RED)Please install $(BOLD)jq$(NORMAL))
endif

SECRETS := $(LPASS) ls "Shared-changelog/secrets"

### TARGETS ###
#
.DEFAULT_GOAL := help

.PHONY: build
build: $(COMPOSE) ## Re-build changelog.com app container
	@$(COMPOSE) build

.PHONY: help
help:
	@grep -E '^[a-zA-Z_-]+:+.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN { FS = "[:#]" } ; { printf "\033[36m%-16s\033[0m %s\n", $$1, $$4 }' | sort

.PHONY: contrib
contrib: $(COMPOSE) ## Contribute to changelog.com by running a local copy (c)
	@bash -c "trap '$(COMPOSE) down' INT; \
	  $(COMPOSE) up; \
	  [[ $$? =~ 0|2 ]] || \
	    ( echo 'You might want to run $(BOLD)make build contrib$(NORMAL) if app dependencies have changed' && exit 1 )"
.PHONY: c
c: contrib

.PHONY: proxy
proxy: $(DOCKER) ## Builds & publishes thechangelog/proxy image
	@cd nginx && export BUILD_VERSION=$$(date +'%Y-%m-%d') ; \
	$(DOCKER) build -t thechangelog/proxy:$$BUILD_VERSION . && \
	$(DOCKER) push thechangelog/proxy:$$BUILD_VERSION && \
	$(DOCKER) tag thechangelog/proxy:$$BUILD_VERSION thechangelog/proxy:latest && \
	$(DOCKER) push thechangelog/proxy:latest

.PHONY: md
md: $(DOCKER) ## Preview Markdown locally, as it will appear on GitHub
	@$(DOCKER) run --interactive --tty --rm --name changelog_md \
	  --volume $(CURDIR):/data \
	  --volume $(HOME)/.grip:/.grip \
	  --expose 5000 --publish 5000:5000 \
	  mbentley/grip --context=. 0.0.0.0:5000

define ENVRC

PATH_add script

export CIRCLE_TOKEN=

endef
export ENVRC
.PHONY: circle_token
circle_token:
ifndef CIRCLE_TOKEN
	@echo "$(RED)CIRCLE_TOKEN$(NORMAL) environment variable must be set" && \
	echo "Learn more about CircleCI API tokens $(BOLD)https://circleci.com/docs/2.0/managing-api-tokens/$(NORMAL) " && \
	echo "We like $(BOLD)https://direnv.net/$(NORMAL) to manage environment variables, but you do what works for you." && \
	echo "This is an $(BOLD).envrc$(NORMAL) template that you can use as a starting point for this repo:" && \
	echo "$$ENVRC" && \
	exit 1
endif

.PHONY: list-ci-secrets
list-ci-secrets: circle_token $(CURL) ## List secrets stored in CircleCI (cis)
	@$(CURL) --silent --fail "https://circleci.com/api/v1.1/project/github/thechangelog/changelog.com/envvar?circle-token=$(CIRCLE_TOKEN)" | $(JQ) "."
.PHONY: cis
cis: list-ci-secrets

.PHONY: sync-secrets
sync-secrets: $(LPASS)
	@$(LPASS) sync

.PHONY: postgres
postgres: $(LPASS)
	@echo "export PG_DOTCOM_PASS=$$($(LPASS) show --notes 7298637973371173308)"
.PHONY: campaignmonitor
campaignmonitor: $(LPASS)
	@echo "export CM_SMTP_TOKEN=$$($(LPASS) show --notes 4518157498237793892)" && \
	echo "export CM_API_TOKEN=$$($(LPASS) show --notes 2172742429466797248)"
.PHONY: github
github: $(LPASS)
	@echo "export GITHUB_CLIENT_ID=$$($(LPASS) show --notes 6311620502443842879)" && \
	echo "export GITHUB_CLIENT_SECRET=$$($(LPASS) show --notes 6962532309857955032)" && \
	echo "export GITHUB_API_TOKEN=$$($(LPASS) show --notes 5059892376198418454)"
.PHONY: aws
aws: $(LPASS)
	@echo "export AWS_ACCESS_KEY_ID=$$($(LPASS) show --notes 5523519094417729320)" && \
	echo "export AWS_SECRET_ACCESS_KEY=$$($(LPASS) show --notes 1520570655547620905)"
.PHONY: twitter
twitter: $(LPASS)
	@echo "export TWITTER_CONSUMER_KEY=$$($(LPASS) show --notes 1932439368993537002)" && \
	echo "export TWITTER_CONSUMER_SECRET=$$($(LPASS) show --notes 5671723614506961548)"
.PHONY: app
app: $(LPASS)
	@echo "export SECRET_KEY_BASE=$$($(LPASS) show --notes 7272253808960291967)" && \
	echo "export SIGNING_SALT=$$($(LPASS) show --notes 8954230056631744101)"
.PHONY: dns
dns: $(LPASS)
	@echo "export DNSIMPLE_EMAIL=$$($(LPASS) show --notes 4657841044703321334)" && \
	echo "export DNSIMPLE_API_TOKEN=$$($(LPASS) show --notes 8003458400976532679)"
.PHONY: slack
slack: $(LPASS)
	@echo "export SLACK_INVITE_API_TOKEN=$$($(LPASS) show --notes 3107315517561229870)" && \
	echo "export SLACK_APP_API_TOKEN=$$($(LPASS) show --notes 1152178239154303913)"
.PHONY: rollbar
rollbar: $(LPASS)
	@echo "export ROLLBAR_ACCESS_TOKEN=$$($(LPASS) show --notes 5433360937426957091)"
.PHONY: buffer
buffer: $(LPASS)
	@echo "export BUFFER_TOKEN=$$($(LPASS) show --notes 4791620911166920938)"
.PHONY: codecov
codecov: $(LPASS)
	@echo "export CODECOV_TOKEN=$$($(LPASS) show --notes 2203313003035524967)"
.PHONY: coveralls
coveralls: $(LPASS)
	@echo "export COVERALLS_REPO_TOKEN=$$($(LPASS) show --notes 8654919576068551356)"
.PHONY: algolia
algolia: $(LPASS)
	@echo "export ALGOLIA_APPLICATION_ID=$$($(LPASS) show --notes 5418916921816895235)" && \
	echo "export ALGOLIA_API_KEY=$$($(LPASS) show --notes 1668162557359149736)"
.PHONY: list-lp-secrets
list-lp-secrets: postgres campaignmonitor github aws twitter app dns slack rollbar buffer codecov coveralls algolia ## List secrets stored in LastPass (lps)
.PHONY: lps
lps: list-lp-secrets

.PHONY: mirror-secrets
mirror-secrets: $(LPASS) $(JQ) $(CURL) circle_token ## Mirror all LastPass secrets into CircleCI (mis)
	@$(SECRETS) | \
	  awk '! /secrets\/ / { system("$(LPASS) show --json " $$1) }' | \
	  $(JQ) --compact-output '.[] | {name: .name, value: .note}' | while read -r envvar; \
	  do \
	  $(CURL) --silent --fail --request POST --header "Content-Type: application/json" -d $$envvar "https://circleci.com/api/v1.1/project/github/thechangelog/changelog.com/envvar?circle-token=$(CIRCLE_TOKEN)"; \
	  done
.PHONY: mis
mis: mirror-secrets

.PHONY: add-secret
add-secret: $(LPASS) ## Add secret to origin (as)
ifndef SECRET
	@echo "$(RED)SECRET$(NORMAL) environment variable must be set to the name of the secret that will be added" && \
	echo "This value must be in upper-case, e.g. $(BOLD)SOME_SECRET$(NORMAL)" && \
	echo "This value must not match any of the existing secrets:" && \
	$(SECRETS) && \
	exit 1
endif
	@$(LPASS) add --notes "Shared-changelog/secrets/$(SECRET)"
.PHONY: as
as: add-secret

.PHONY: secrets
secrets: $(LPASS) ## List secrets at origin (s)
	@$(SECRETS)
.PHONY: s
s: secrets
