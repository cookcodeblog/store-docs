#!/bin/bash

for object in $(find . -name '*.yaml')
do
  yq delete -i $object metadata.managedFields
  yq delete -i $object metadata.creationTimestamp
  yq delete -i $object metadata.resourceVersion
  yq delete -i $object metadata.selfLink
  yq delete -i $object metadata.uid
  yq delete -i $object metadata.generation
  yq delete -i $object 'metadata.annotations."app.openshift.io/vcs-ref"'
  yq delete -i $object 'metadata.annotations."app.openshift.io/vcs-uri"'
  yq delete -i $object 'metadata.annotations."openshift.io/generated-by"'
  yq delete -i $object 'metadata.annotations."openshift.io/host.generated"'
  yq delete -i $object 'metadata.labels."template.openshift.io/template-instance-owner"'
  yq delete -i $object 'metadata.annotations."template.openshift.io/expose-*"'
  yq delete -i $object metadata.namespace
  yq delete -i $object status
  yq delete -i $object spec.host
  yq delete -i $object spec.clusterIP
  yq delete -i $object 'subjects[0].namespace'
done
