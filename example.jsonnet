// Simple example of using kustomize.libsonnet to overlay changes to
// an upstream repo - inspired by the kustomize example of adapting
// "helloWorld" for staging.
// https://github.com/kubernetes-sigs/kustomize/tree/master/examples/helloWorld
//
// Run me with:
//  kubecfg show example.jsonnet
//

local kustomize = import "kustomize.libsonnet";
local kubecfg = import "kubecfg.libsonnet";

// NB: kubecfg can import from URLs too, if you want to consume
// upstream manifests directly from a remote repo (remember to use
// "raw" URLs for github content).
// Eg: kubecfg.parseYaml(importstr "https://github.com/kubernetes-sigs/kustomize/raw/master/examples/helloWorld/configMap.yaml")

local input =
  kubecfg.parseYaml(importstr "examples/deployment.yaml") +
  kubecfg.parseYaml(importstr "examples/service.yaml") +
  kubecfg.parseYaml(importstr "examples/configMap.yaml");

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
