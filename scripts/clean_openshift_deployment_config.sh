#!/bin/bash


for object in $(find . -name 'deployment-config*.yaml')
do
  yq write -i $object 'spec.template.spec.containers[0].image' ' '
  yq delete -i $object 'spec.triggers.(type==ImageChange).imageChangeParams.from.namespace'
  yq delete -i $object 'spec.triggers.(type==ImageChange).imageChangeParams.lastTriggeredImage'
done
