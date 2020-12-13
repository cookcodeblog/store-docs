#!/bin/bash


for object in $(find . -name 'build-config*.yaml')
do
  yq delete -i $object 'spec.triggers.(type==Generic)'
  yq delete -i $object 'spec.triggers.(type==GitHub)'
  yq delete -i $object 'spec.triggers.(type==ImageChange)'
done
