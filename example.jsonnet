local kustomize = import "kustomize.libsonnet";
local kubecfg = import "kubecfg.libsonnet";

local input =
  kubecfg.parseYaml(importstr "https://github.com/kubernetes-sigs/kustomize/raw/master/examples/helloWorld/deployment.yaml") +
  kubecfg.parseYaml(importstr "https://github.com/kubernetes-sigs/kustomize/raw/master/examples/helloWorld/service.yaml") +
  kubecfg.parseYaml(importstr "https://github.com/kubernetes-sigs/kustomize/raw/master/examples/helloWorld/configMap.yaml");

// kubecfg doesn't support client-side strategic-merge-patch (yet),
// but we can do better in jsonnet anyway:
local updateConfig(o) = (
  if o.kind == "ConfigMap" && o.metadata.name == "the-map" then o + {
    data+: {
      altGreeting: "Have a pineapple!",
      enableRisky: "true",
    },
  } else o
);

local kustomization = kustomize.applyList([
  updateConfig,
  kustomize.namePrefix("staging-"),
  kustomize.commonLabels({variant: "staging", org: "acmeCorporation"}),
  kustomize.commonAnnotations({note: "Hello, I am staging!"}),
]);

std.map(kustomization, input)
