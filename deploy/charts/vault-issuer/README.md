# vault-issuer

<!-- AUTO-GENERATED -->

### Global

#### **replicaCount** ~ `number`
> Default value:
> ```yaml
> 1
> ```

Number of replicas of the controller to run.  
  
Leader election is enabled, so only one replica reconciles at a time; the others stand by.
#### **image.repository** ~ `string`
> Default value:
> ```yaml
> quay.io/jetstack/vault-issuer
> ```

The container registry and repository to pull the controller image from.

#### **image.tag** ~ `string`

Override the image tag. Defaults to the chart's appVersion.

#### **image.digest** ~ `string`

Pull the image by digest instead of by tag.

#### **image.pullPolicy** ~ `string`
> Default value:
> ```yaml
> IfNotPresent
> ```

Image pull policy.
#### **imagePullSecrets** ~ `array`
> Default value:
> ```yaml
> []
> ```

Secrets used to pull the controller image from a private registry.  
For example:

```yaml
imagePullSecrets:
  - name: my-registry-credentials
```
#### **nameOverride** ~ `string`
> Default value:
> ```yaml
> ""
> ```

Override the name of the resources this chart creates.
#### **fullnameOverride** ~ `string`
> Default value:
> ```yaml
> ""
> ```

Override the fully qualified name of the resources this chart creates.
### Controller

#### **clusterResourceNamespace** ~ `string`
> Default value:
> ```yaml
> ""
> ```

The namespace Secrets referenced by a ClusterIssuer are read from.  
  
Namespaced Issuers always read their Secrets from their own namespace. This setting only applies to cluster-scoped Issuers, which have no namespace of their own. Defaults to the namespace the chart is installed into.

#### **issuerAmbientCredentials** ~ `bool`
> Default value:
> ```yaml
> false
> ```

Allow namespaced Issuers to authenticate with credentials drawn from the controller's environment, such as instance metadata or IRSA, rather than from the Issuer's spec.  
  
This is off by default: anyone who can create an Issuer in any namespace could otherwise borrow the controller's cloud identity.
#### **clusterIssuerAmbientCredentials** ~ `bool`
> Default value:
> ```yaml
> true
> ```

Allow ClusterIssuers to authenticate with credentials drawn from the controller's environment. ClusterIssuers are cluster-scoped and therefore managed by cluster administrators, so this is on by default.
#### **maxRetryDuration** ~ `string`
> Default value:
> ```yaml
> 2m
> ```

How long a CertificateRequest is retried after a transient signing error, measured from when the request was created. Once exceeded, the request fails and cert-manager creates a new one.
#### **extraArgs** ~ `array`
> Default value:
> ```yaml
> []
> ```

Extra command line arguments passed to the controller.
#### **logLevel** ~ `number`
> Default value:
> ```yaml
> 0
> ```

Log verbosity. 0 is info, 1 is debug.
### Deployment

#### **serviceAccount.create** ~ `bool`
> Default value:
> ```yaml
> true
> ```

Create a ServiceAccount for the controller.
#### **serviceAccount.name** ~ `string`
> Default value:
> ```yaml
> ""
> ```

Name of the ServiceAccount. Generated from the chart name when empty.

#### **serviceAccount.annotations** ~ `object`
> Default value:
> ```yaml
> {}
> ```

Annotations to add to the ServiceAccount, for example to bind a cloud identity to it.
#### **serviceAccount.automountServiceAccountToken** ~ `bool`
> Default value:
> ```yaml
> true
> ```

Mount the ServiceAccount's API token into the controller Pod. Required: the controller talks to the Kubernetes API.
#### **resources** ~ `object`
> Default value:
> ```yaml
> {}
> ```

Resource requests and limits for the controller.  
For example:

```yaml
resources:
  requests:
    cpu: 10m
    memory: 32Mi
```
#### **podSecurityContext.runAsNonRoot** ~ `bool`
> Default value:
> ```yaml
> true
> ```
#### **podSecurityContext.seccompProfile.type** ~ `string`
> Default value:
> ```yaml
> RuntimeDefault
> ```
#### **securityContext.allowPrivilegeEscalation** ~ `bool`
> Default value:
> ```yaml
> false
> ```
#### **securityContext.capabilities.drop[0]** ~ `string`
> Default value:
> ```yaml
> ALL
> ```
#### **securityContext.readOnlyRootFilesystem** ~ `bool`
> Default value:
> ```yaml
> true
> ```
#### **nodeSelector** ~ `object`
> Default value:
> ```yaml
> kubernetes.io/os: linux
> ```

Node selector for the controller Pod.  
  
The default keeps Pods off Windows nodes in a mixed-OS cluster.

#### **tolerations** ~ `array`
> Default value:
> ```yaml
> []
> ```

Tolerations for the controller Pod.
#### **affinity** ~ `object`
> Default value:
> ```yaml
> {}
> ```

Affinity rules for the controller Pod.
#### **podAnnotations** ~ `object`
> Default value:
> ```yaml
> {}
> ```

Annotations to add to the controller Pod.
#### **podLabels** ~ `object`
> Default value:
> ```yaml
> {}
> ```

Labels to add to the controller Pod.

<!-- /AUTO-GENERATED -->
