// An implementation of the core primitives of kustomize, in jsonnet.
// .. as documented by the comments in
//  https://github.com/kubernetes-sigs/kustomize/blob/master/docs/kustomization.yaml
//
// Each of these is implemented as a "factory" function that returns a
// function that acts on a single k8s resource. These can then be
// applied using a common std.map() or similar.

{
  // Handy helper that applies multiple transformations to a single object.
  applyList(funcs):: function(o) std.foldl(function(result, f) f(result), funcs, o),

  // Add a namespace.
  namespace(ns):: function(o) (
    // Exclude non-namespaced resources
    // See kubectl api-resources --namespaced=false
    local nonNamespaced = std.set([
      "ComponentStatus",
      "Namespace",
      "Node",
      "PersistentVolume",
      "MutatingWebhookConfiguration",
      "ValidatingWebhookConfiguration",
      "CustomResourceDefinition",
      "APIService",
      "TokenReview",
      "SelfSubjectAccessReview",
      "SelfSubjectRulesReview",
      "SubjectAccessReview",
      "CertificateSigningRequest",
      "PodSecurityPolicy",
      "ClusterRoleBinding",
      "ClusterRole",
      "PriorityClass",
      "CSIDriver",
      "CSINode",
      "StorageClass",
      "VolumeAttachment",
    ]);
    if !std.setMember(o.kind, nonNamespaced) then o + {
      metadata+: {
        namespace: ns
      }
    } else o
  ),

  // Prepend the value to the resource name.
  namePrefix(p):: function(o) o + {metadata+: {name: p + super.name}},

  // Append the value to the resource name.
  nameSuffix(s):: function(o) o + {metadata+: {name+: s}},

  // Add the labels to all resources and selectors.
  commonLabels(l):: function(o) (
    // Aside: The kustomize code is quite inconsistent on what it uses
    // as the match criteria.
    // Kustomize's list is in https://github.com/kubernetes-sigs/kustomize/blob/master/pkg/transformers/config/defaultconfig/commonlabels.go
    local gv = std.split(o.apiVersion, "/");
    local g = if std.length(gv) == 1 then "" else gv[0];
    local v = if std.length(gv) == 1 then gv[0] else gv[1];
    local k = o.kind;
    o + {
      metadata+: {labels+: l},
    } +
    if (v == "v1" && k == "Service") then {
      spec+: {selector+: l},
    } else {} +
    if (v == "v1" && k == "ReplicationController") then {
      spec+: {
        selector+: l,
        template+: {metadata+: {labels+: l}},
      },
    } else {} +
    if (k == "Deployment" || k == "ReplicaSet" || k == "DaemonSet") then {
      spec+: {
        selector+: {matchLabels+: l},
        template+: {metadata+: {labels+: l}},
      },
    } else {} +
    if (g == "apps" && (k == "Deployment" || k == "StatefulSet")) then {
      spec+: {
        template+: {
          spec+: {
            affinity+: {
              podAffinity+: {
                preferredDuringSchedulingIgnoredDuringExecution+: {
                  podAffinityTerm+: {
                    labelSelector+: {
                      [if super.matchLabels then "matchLabels"]+: l,
                    },
                  },
                },
                requiredDuringSchedulingIgnoredDuringExecution+: {
                  labelSelector+: {
                    [if super.matchLabels then "matchLabels"]+: l,
                  },
                },
              },
              podAntiAffinity+: {
                preferredDuringSchedulingIgnoredDuringExecution+: {
                  podAffinityTerm+: {
                    labelSelector+: {
                      [if super.matchLabels then "matchLabels"]+: l,
                    },
                  },
                },
                requiredDuringSchedulingIgnoredDuringExecution+: {
                  labelSelector+: {
                    [if super.matchLabels then "matchLabels"]+: l,
                  },
                },
              },
            },
          },
        },
      },
    } else {} +
    if (g == "apps" && k == "StatefulSet") then {
      spec+: {volumeClaimTemplates+: {metadata+: {labels+: l}}},
    } else {} +
    if (g == "batch" && k == "Job") then {
      spec+: {
        selector+: {[if super.matchLabels then "matchLabels"]+: l},
        template+: {metadata+: {labels+: l}},
      },
    } else {} +
    if (g == "batch" && k == "CronJob") then {
      spec+: {
        jobTemplate+: {
          metadata+: {labels+: l},
          spec+: {
            selector+: {[if super.matchLabels then "matchLabels"]+: l},
            template+: {metadata+: {labels+: l}},
          },
        },
      },
    } else {} +
    if (g == "policy" && k == "PodDisruptionBudget") then {
      spec+: {
        selector+: {
          [if super.matchLabels then "matchLabels"]+: l,
        },
      },
    } else {} +
    if (g == "networking.k8s.io" && k == "NetworkPolicy") then {
      spec+: {
        podSelector+: {
          [if super.matchLabels then "matchLabels"]+: l,
        },
        ingress+: {
          from+: {
            podSelector+: {
              [if super.matchLabels then "matchLabels"]+: l,
            },
          },
        },
        egress+: {
          to+: {
            podSelector+: {
              [if super.matchLabels then "matchLabels"]+: l,
            },
          },
        },
      },
    } else {}
  ),

  commonAnnotations(a):: function(o) (
    local gv = std.split(o.apiVersion, "/");
    local g = if std.length(gv) == 1 then "" else gv[0];
    local v = if std.length(gv) == 1 then gv[0] else gv[1];
    local k = o.kind;
    o + {
      metadata+: {annotations+: a},
    } +
    if (
      (v == "v1" && k == "ReplicationController") ||
      (k == "Deployment") ||
      (k == "ReplicaSet") ||
      (k == "DaemonSet") ||
      (k == "StatefulSet") ||
      (g == "batch" && k == "Job")
    ) then {
      spec+: {template+: {metadata+: {annotations+: a}}}
    } else {} +
    if (g == "batch" && k == "CronJob") then {
      spec+: {
        jobTemplate+: {
          metadata+: {annotations+: a},
          spec+: {template+: {metadata+: {annotations+: a}}},
        },
      },
    } else {}
  ),

  resources:: error "not relevant - I/O needs to be done separately and explicitly in jsonnet",
  bases:: error "not relevant - I/O needs to be done separately and explicitly in jsonnet",

  configMapGenerator:: error "TODO? unclear what makes sense here",
  secretGenerator:: error "TODO? unclear what makes sense here",
  generatorOptions:: error "not applicable",

  patchesStrategicMerge(o):: error "TODO(kubecfg): No s-m-p implementation exposed to jsonnet yet.",

  // FYI: Jsonnet's std.mergePatch does RFC7396 json-merge-patch,
  // which is not json-patch.
  patchesJson6902(target, patch):: error "TODO: No json-patch implementation for jsonnet yet.",

  crds: error "TODO(gus): think about how to merge this with above functions",

  vars(vars):: function(o) (
    error "FIXME: not yet implemented"
  ),

  // Modify image names/tags/digests.
  // `images` is an array of objects describing the desired modifications.
  images(images):: function(o) (
    local newImage(old, img) = (
      local nametag = std.split(old, ":");
      local name = nametag[0];
      local tag = if std.length(nametag) > 1 then nametag[1] else "latest";
      if name == img.name then (
        local newName = if std.objectHas(img, "newName") then img.newName else name;
        local newTag = if std.objectHas(img, "newTag") then img.newTag else tag;
        local newDigest = if std.objectHas(img, "digest") then img.digest else null;
        newName + if newDigest != null then ("@" + newDigest) else (":" + newTag)
      ) else old
    );

    // NB: Unlike other kustomize transformers, which act on specific
    // paths only, "images" walks the object looking for anything
    // matching "containers" or "initContainers".

    local visitAll(x, f) = (
      local recurse(o) = visitAll(f(o), f);
      if std.isArray(x) then [recurse(o) for o in x]
      else if std.isObject(x) then {[k]: recurse(x[k]) for k in std.objectFields(x)}
      else f(x)
    );
    local updateContainer(o) = (
      if std.isObject(o) then o + {
        [if std.objectHas(o, "containers") then "containers"]: [
          c + {image: std.foldl(newImage, images, super.image)} for c in super.containers
        ],
        [if std.objectHas(o, "initContainers") then "initContainers"]: [
          c + {image: std.foldl(newImage, images, super.image)} for c in super.initContainers
        ],
      } else o
    );

    visitAll(o, updateContainer)
  ),
}
