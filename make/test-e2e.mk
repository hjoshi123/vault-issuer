# Copyright 2026 The cert-manager Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

vault_helm_chart_repo := https://helm.releases.hashicorp.com
vault_helm_chart_version := 0.25.0

# Two Vault servers are installed: a default one, and one that requires client
# certificates. cert-manager runs the same pair, as its e2e-vault and
# e2e-vault-mtls fixtures.
vault_release_name := vault
vault_namespace := vault
vault_mtls_namespace := vault-mtls

vault_tls_dir := $(bin_dir)/scratch/vault-tls
vault_mtls_tls_dir := $(bin_dir)/scratch/vault-mtls-tls

# The namespace the controller is deployed into. The chart defaults
# --cluster-resource-namespace to the release namespace, so this is also where
# ClusterIssuer Secrets are read from.
cluster_resource_namespace := cert-manager

# The environment the end-to-end tests read. This is the entire contract between
# the make targets, which install and configure everything, and the Go tests,
# which only consume it. See test/e2e/framework/addon/vault/details.go.
export E2E_CLUSTER_RESOURCE_NAMESPACE := $(cluster_resource_namespace)

export E2E_VAULT_URL := https://$(vault_release_name).$(vault_namespace).svc.cluster.local:8200
export E2E_VAULT_NAMESPACE := $(vault_namespace)
export E2E_VAULT_POD := $(vault_release_name)-0
export E2E_VAULT_CA_FILE := $(CURDIR)/$(vault_tls_dir)/ca.crt
export E2E_VAULT_CLIENT_CERT_FILE := $(CURDIR)/$(vault_tls_dir)/client.crt
export E2E_VAULT_CLIENT_KEY_FILE := $(CURDIR)/$(vault_tls_dir)/client.key
export E2E_VAULT_ENFORCE_MTLS := false

export MTLS_E2E_VAULT_URL := https://$(vault_release_name).$(vault_mtls_namespace).svc.cluster.local:8200
export MTLS_E2E_VAULT_NAMESPACE := $(vault_mtls_namespace)
export MTLS_E2E_VAULT_POD := $(vault_release_name)-0
export MTLS_E2E_VAULT_CA_FILE := $(CURDIR)/$(vault_mtls_tls_dir)/ca.crt
export MTLS_E2E_VAULT_CLIENT_CERT_FILE := $(CURDIR)/$(vault_mtls_tls_dir)/client.crt
export MTLS_E2E_VAULT_CLIENT_KEY_FILE := $(CURDIR)/$(vault_mtls_tls_dir)/client.key
export MTLS_E2E_VAULT_ENFORCE_MTLS := true

.PHONY: e2e-setup-cert-manager
## Install cert-manager into the kind cluster, using the preloaded images.
## @category Testing
e2e-setup-cert-manager: | kind-cluster $(NEEDS_HELM) $(NEEDS_KUBECTL)
	$(HELM) upgrade \
		--install \
		--create-namespace \
		--wait \
		--version $(quay.io/jetstack/cert-manager-controller.TAG) \
		--namespace cert-manager \
		--repo https://charts.jetstack.io \
		--set crds.enabled=true \
		--set image.repository=$(quay.io/jetstack/cert-manager-controller.REPO) \
		--set image.tag=$(quay.io/jetstack/cert-manager-controller.TAG) \
		--set image.pullPolicy=Never \
		--set cainjector.image.repository=$(quay.io/jetstack/cert-manager-cainjector.REPO) \
		--set cainjector.image.tag=$(quay.io/jetstack/cert-manager-cainjector.TAG) \
		--set cainjector.image.pullPolicy=Never \
		--set webhook.image.repository=$(quay.io/jetstack/cert-manager-webhook.REPO) \
		--set webhook.image.tag=$(quay.io/jetstack/cert-manager-webhook.TAG) \
		--set webhook.image.pullPolicy=Never \
		--set startupapicheck.image.repository=$(quay.io/jetstack/cert-manager-startupapicheck.REPO) \
		--set startupapicheck.image.tag=$(quay.io/jetstack/cert-manager-startupapicheck.TAG) \
		--set startupapicheck.image.pullPolicy=Never \
		--set "extraArgs={--controllers=*\,-certificaterequests-issuer-vault\,-issuers\,-clusterissuers}" \
		cert-manager cert-manager >/dev/null

# Generate the CA, serving certificate and client certificate for a Vault
# installation. $1 is the output directory, $2 the DNS name of the server.
define generate-vault-tls
	cd $(CURDIR)/test/e2e && GOWORK=off $(GO) run ./hack/gen-vault-certs \
		--out-dir $(CURDIR)/$(1) \
		--dns-name $(2)
endef

# Install a Vault server. $1 is the namespace, $2 the TLS directory, $3 whether
# the listener requires a client certificate.
define install-vault
	$(KUBECTL) create namespace $(1) --dry-run=client -o yaml | $(KUBECTL) apply -f -

	$(KUBECTL) -n $(1) create secret generic vault-tls \
		--from-file=ca.crt=$(CURDIR)/$(2)/ca.crt \
		--from-file=server.crt=$(CURDIR)/$(2)/server.crt \
		--from-file=server.key=$(CURDIR)/$(2)/server.key \
		--from-file=client.crt=$(CURDIR)/$(2)/client.crt \
		--from-file=client.key=$(CURDIR)/$(2)/client.key \
		--dry-run=client -o yaml | $(KUBECTL) apply -f -

	sed -e 's|{{TLS_REQUIRE_CLIENT_CERT}}|$(3)|g' \
		make/config/vault/values.yaml \
		> $(bin_dir)/scratch/vault-values-$(1).yaml

	$(HELM) upgrade \
		--install \
		--wait \
		--namespace $(1) \
		--repo $(vault_helm_chart_repo) \
		--version $(vault_helm_chart_version) \
		--values $(bin_dir)/scratch/vault-values-$(1).yaml \
		--set server.image.repository=$(docker.io/hashicorp/vault.REPO) \
		--set server.image.tag=$(docker.io/hashicorp/vault.TAG) \
		$(vault_release_name) vault >/dev/null

	$(KUBECTL) -n $(1) rollout status statefulset $(vault_release_name) --timeout=5m

	sed -e 's|{{NAMESPACE}}|$(1)|g' make/config/vault/rbac.yaml | $(KUBECTL) apply -f -
endef

.PHONY: e2e-setup-vault
## Install a Vault server into the kind cluster, serving TLS.
## @category Testing
e2e-setup-vault: | kind-cluster $(NEEDS_GO) $(NEEDS_HELM) $(NEEDS_KUBECTL) $(bin_dir)/scratch
	$(call generate-vault-tls,$(vault_tls_dir),$(vault_release_name).$(vault_namespace).svc.cluster.local)
	$(call install-vault,$(vault_namespace),$(vault_tls_dir),false)

.PHONY: e2e-setup-vault-mtls
## Install a second Vault server that requires client certificates.
## @category Testing
e2e-setup-vault-mtls: | kind-cluster $(NEEDS_GO) $(NEEDS_HELM) $(NEEDS_KUBECTL) $(bin_dir)/scratch
	$(call generate-vault-tls,$(vault_mtls_tls_dir),$(vault_release_name).$(vault_mtls_namespace).svc.cluster.local)
	$(call install-vault,$(vault_mtls_namespace),$(vault_mtls_tls_dir),true)

.PHONY: e2e-setup-vault-issuer
## Build, load and deploy the vault-issuer controller into the kind cluster.
## @category Testing
e2e-setup-vault-issuer: oci-load-controller $(helm_chart_archive) | kind-cluster $(NEEDS_HELM) $(NEEDS_KUBECTL)
	# helm_values_mutation_function has already pointed the chart's default
	# image at the one oci-load-controller just loaded into the cluster.
	$(HELM) upgrade \
		--install \
		--wait \
		--namespace $(cluster_resource_namespace) \
		--set image.pullPolicy=Never \
		$(deploy_name) $(helm_chart_archive) >/dev/null

	$(KUBECTL) -n $(cluster_resource_namespace) rollout status deployment $(deploy_name) --timeout=5m

.PHONY: e2e-setup
## Install everything the end-to-end tests need into the kind cluster.
## @category Testing
e2e-setup: e2e-setup-cert-manager e2e-setup-vault e2e-setup-vault-mtls e2e-setup-vault-issuer

test-e2e-deps: e2e-setup

.PHONY: test-e2e
## Run the end-to-end tests, creating the kind cluster if it does not exist.
##
## To run a subset of the specs:
##
##	make test-e2e E2E_FOCUS='Vault Issuer'
##
## @category Testing
test-e2e: test-e2e-deps | kind-cluster $(NEEDS_GOTESTSUM) $(ARTIFACTS)
	$(eval abs_artifacts := $(abspath $(ARTIFACTS)))
	$(eval E2E_FOCUS ?= )

	cd ./test/e2e && \
	GOWORK=off \
	KUBECONFIG=$(absolute_kubeconfig) \
	$(GOTESTSUM) \
		--junitfile=$(abs_artifacts)/junit-go-e2e.xml \
		-- \
		-timeout 30m \
		. \
		-ginkgo.timeout=25m \
		$(if $(E2E_FOCUS),-ginkgo.focus='$(E2E_FOCUS)',)

.PHONY: e2e-logs
## Export the kind cluster's logs into $(ARTIFACTS), for triaging CI failures.
## @category Testing
e2e-logs: | kind-cluster $(NEEDS_KIND) $(ARTIFACTS)
	rm -rf $(ARTIFACTS)/e2e-logs
	mkdir -p $(ARTIFACTS)/e2e-logs
	$(KIND) export logs $(ARTIFACTS)/e2e-logs --name=$(kind_cluster_name)
