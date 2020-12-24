[TOC]

# 在Istio上运行Zuul



## Zuul without Eureka

References：

- https://stackoverflow.com/questions/34036468/can-zuul-edge-server-be-used-without-eureka-ribbon

- https://cloud.spring.io/spring-cloud-netflix/multi/multi__router_and_filter_zuul.html

- https://cloud.spring.io/spring-cloud-netflix/multi/multi_spring-cloud-ribbon.html#spring-cloud-ribbon-without-eureka



去掉Eureka Client的依赖，和@EnableEurekaClient注解。

Disable Ribbon去查找Eureka。

配置Zuul的静态url路由。



```yaml
ribbon:
  eureka:
    enabled: false
    
    
zuul:
  prefix: /api
  ignored-services: '*' # 排除所有基于Eureka服务ID的路由的注册
  routes:
    customer:
      path: '/customer/**'
      url: http://customer:8080
  host:
    connect-timeout-millis: 5000
    socket-timeout-millis: 5000
```



## Istio with Zuul



将`gateway`部署到OpenShift中，注入sidecar。

配置`gateway`的DestinationRule。



```yaml
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: gateway
spec:
  host: gateway
  subsets:
    - labels:
        version: v1
      name: v1
```



修改服务入口地址从`customer`改为`gateway`。



```yaml
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: store-gateway
spec:
  selector:
    istio: ingressgateway # use istio default controller
  servers:
    - port:
        number: 80
        name: http
        protocol: HTTP
      hosts:
        - "istio-ingressgateway-istio-system.apps.ocp4-grub.ocp.com"
---
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: store
spec:
  hosts:
    - "istio-ingressgateway-istio-system.apps.ocp4-grub.ocp.com"
  gateways:
    - store-gateway
  http:
    - match:
        - uri:
            prefix: "/api/customer"
      route:
        - destination:
            host: gateway
            port:
              number: 8080
```







访问服务入口：

- <http://istio-ingressgateway-istio-system.apps.ocp4-grub.ocp.com/api/customer>



流量方向为：

```txt
istio-ingressgateway -> gateway(zuul) -> customer -> preference -> recommendation
```





## Istio vs API Gateway



流量方向一：

```txt
API Gateway -> Service Mesh (Ingress Gatway) -> Service
```

API Gateway作为网络边界。



流量方向二：

```txt
Route -> Service Mesh (Ingress Gateway) -> API Gateway -> Service
```



API Gateway作为Service Mesh的一个服务。





References：

- <https://dzone.com/articles/api-gateway-vs-service-mesh>

- <https://banzaicloud.com/blog/backyards-api-gateway/>

  

