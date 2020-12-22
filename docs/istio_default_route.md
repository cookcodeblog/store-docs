[TOC]

# 测试Istio默认路由



将项目的Gateway和VirtualService的`host`都设置为`istio-ingressgateway-istio-system.apps.ocp4-grub.ocp.com`。

因为`customer`的根路径为`/`，所以需要根据URL prefix `/customer` 匹配后，需要rewrite URL为`/` 。

访问`customer` 服务：

- <http://istio-ingressgateway-istio-system.apps.ocp4-grub.ocp.com/customer>



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
            prefix: "/customer"
      rewrite:
        uri: /
      route:
        - destination:
            host: customer
            port:
              number: 8080
```

