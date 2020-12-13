
# Export OpenShift resources

## List resources

```bash
cd openshift-templates
oc project william-store
oc get all -o name

oc get all -o name | grep -v pod | grep -v replicationcontroller | grep -v "build.build"

oc get configmap
oc get secret
oc get pvc
oc get rolebinding

```

## Service

```bash
# list resources
oc get svc

# export resources
oc get svc config-server -o yaml > service-config-server.yaml
oc get svc customer -o yaml > service-customer.yaml
oc get svc gateway -o yaml > service-gateway.yaml
oc get svc hystrix-ui -o yaml > service-hystrix-ui.yaml
oc get svc preference -o yaml > service-preference.yaml
oc get svc recommendation -o yaml > service-recommendation.yaml
oc get svc service-registry -o yaml > service-service-registry.yaml

```


## Deployment Config
```bash
# list resources
oc get dc

# export resources
oc get dc config-server -o yaml > deployment-config-config-server.yaml
oc get dc customer -o yaml > deployment-config-customer.yaml
oc get dc gateway -o yaml > deployment-config-gateway.yaml
oc get dc hystrix-ui -o yaml > deployment-config-hystrix-ui.yaml
oc get dc preference -o yaml > deployment-config-preference.yaml
oc get dc recommendation -o yaml > deployment-config-recommendation.yaml
oc get dc service-registry -o yaml > deployment-config-service-registry.yaml

```

## Build Config

```bash
# list resources
oc get bc

# export resources
oc get bc config-server -o yaml > build-config-config-server.yaml
oc get bc customer -o yaml > build-config-customer.yaml
oc get bc gateway -o yaml > build-config-gateway.yaml
oc get bc hystrix-ui -o yaml > build-config-hystrix-ui.yaml
oc get bc preference -o yaml > build-config-preference.yaml
oc get bc recommendation -o yaml > build-config-recommendation.yaml
oc get bc service-registry -o yaml > build-config-service-registry.yaml

```

## Image Stream


```bash
# list resources
oc get imagestream

# export resources
oc get imagestream config-server -o yaml > image-stream-config-server.yaml
oc get imagestream customer -o yaml > image-stream-customer.yaml
oc get imagestream gateway -o yaml > image-stream-gateway.yaml
oc get imagestream hystrix-ui -o yaml > image-stream-hystrix-ui.yaml
oc get imagestream preference -o yaml > image-stream-preference.yaml
oc get imagestream recommendation -o yaml > image-stream-recommendation.yaml
oc get imagestream service-registry -o yaml > image-stream-service-registry.yaml

```


## Route

```bash
# list resources
oc get route

# export resources
oc get route config-server -o yaml > route-config-server.yaml
oc get route gateway -o yaml > route-gateway.yaml
oc get route hystrix-ui -o yaml > route-hystrix-ui.yaml
oc get route service-registry -o yaml > route-service-registry.yaml

```


## ConfigMap

```bash
# list resources
oc get configmap | grep store

# export resources
oc get configmap store-config -o yaml > configmap-store-config.yaml
```

## 删除导出yaml中多余的字段

```bash
bash ../scripts/clean_openshift_yaml.sh
bash ../scripts/clean_openshift_deployment_config.sh
bash ../scripts/clean_openshift_build_config.sh

```


## 每个微服务一个目录，方便独立部署

```bash

mkdir -p config-server 
mkdir -p customer      
mkdir -p gateway       
mkdir -p hystrix-ui    
mkdir -p preference    
mkdir -p recommendation
mkdir -p service-registry

mkdir -p static


mv *config-server.yaml ./config-server
mv *customer.yaml ./customer
mv *gateway.yaml ./gateway
mv *hystrix-ui.yaml ./hystrix-ui
mv *preference.yaml ./preference
mv *recommendation.yaml ./recommendation
mv *service-registry.yaml ./service-registry

mv configmap*.yaml ./static

```

# Import resources

## Create a new OpenShift project 

```bash
oc new-project william-store-istio
oc project

```

## Import resources

```bash
oc apply -f ./static/

oc apply -f ./config-server/
oc apply -f ./customer/
oc apply -f ./gateway/
oc apply -f ./hystrix-ui/
oc apply -f ./preference/
oc apply -f ./recommendation/
oc apply -f ./service-registry/

```


