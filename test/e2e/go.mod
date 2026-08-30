module github.com/cert-manager/vault-issuer/test/e2e

go 1.25.0

require (
	github.com/cert-manager/cert-manager v1.21.1
	github.com/hashicorp/vault/api v1.23.0
	github.com/stretchr/testify v1.12.1
	k8s.io/api v0.36.4
	k8s.io/apimachinery v0.36.4
	k8s.io/client-go v0.36.4
	sigs.k8s.io/controller-runtime v0.24.1
)
