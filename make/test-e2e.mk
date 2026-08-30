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

# The Vault Helm chart and the namespace it is installed into. The end-to-end
# tests reach the server through this Service.
vault_helm_chart_repo := https://helm.releases.hashicorp.com
vault_helm_chart_version := 0.25.0
vault_namespace := vault
vault_release_name := vault

# Dev-mode Vault unseals itself and accepts this token. It is a test fixture,
# not a secret.
export E2E_VAULT_TOKEN := vault-root-token
export E2E_VAULT_NAMESPACE := $(vault_namespace)
export E2E_VAULT_POD := $(vault_release_name)-0

.PHONY: e2e-setup-cert-manager
## Install cert-manager into the kind cluster using the preloaded images.
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
              cert-manager cert-manager >/dev/null
	
	# The in-tree Vault controllers must not run: both they and this 	issuer would
	# reconcile the same Issuers and sign the same CertificateRequests.
	$(KUBECTL) -n cert-manager patch deployment cert-manager \
		--type=json \
		-p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--controllers=*,-certificaterequest,-issuers"}]'
	$(KUBECTL) -n cert-manager rollout status deployment cert-manager --timeout=5m

.PHONY: e2e-setup-vault
## Install a dev-mode Vault serv
## @category Testing
e2e-setup-vault: | kind-cluster L)
	$(HELM) upgrade \
              --install \
              --create-namespace \
              --wait \
              --namespace $(vault_namespace) \
              --repo $(vault_helm_chart_repo) \
	      --version $(vault_helm_chart_version) \
              --values make/config/vault/values.yaml \
              --set server.image.tag=$(vault_image_version) \
              --set server.dev.dN) \
              $(vault_release_name) vault >/dev/null
	
	$(KUBECTL) -n $(vault_namespace) rollout status statefulset $(vault_release_name) --timeout=5m
	
	# Vault's Kubernetes auth method needs to call TokenReview.
	$(KUBECTL) apply -f make/config/vault/rbac.yaml

.PHONY: e2e-setup-vault-issuer
## Build, load and deploy the vault-issuer controller into the kind cluster.
## @category Testing
e2e-setup-vault-issuer: oci-load-controller | kind-cluster $(NEEDS_KUBECTL) $(bin_dir)/scratch
	sed -e 's|{{IMAGE}}|$(oci_controller_image_name_development):$(oci_controller_image_tag)|g' \
              deploy/static/vault-issuer.yaml \
              > $(bin_dir)/scratch/vault-issuer.yaml
	$(KUBECTL) apply -f $(bin_dir)/scratch/vault-issuer.yaml
	$(KUBECTL) -n cert-manager rollout status deployment vault-issuer --timeout=5m

.PHONY: e2e-setup
## Install everything the end-to-end tests need into the kind cluster.
## @category Testing
e2e-setup: e2e-setup-cert-manager e2e-setup-vault e2e-setup-vault-issuer

test-e2e-deps: e2e-setup

.PHONY: test-e2e
## End-to-end tests. Creates the kind cluster if it does not exist.
##
##    make test-e2e [E2E_FOCUS=TestVaultAppRole]
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
		$(if $(E2E_FOCUS),-run $(E2E_FOCUS),) \
		./...

.PHONY: e2e-logs
## Export kind cluster logs into $(ARTIFACTS), for CI failure triage.
## @category Testing
e2e-logs: | kind-cluster $(NEEDS_KIND) $(ARTIFACTS)
	rm -rf $(ARTIFACTS)/e2e-logs
	mkdir -p $(ARTIFACTS)/e2e-logs
	$(KIND) export logs $(ARTIFACTS)/e2e-logs --name=$(kind_cluster_name)
