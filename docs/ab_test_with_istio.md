@[toc]
# 在Istio上根据HTTP header对Spring Boot应用作路由分发实现AB testing



## 前言

本文描述了在Istio上根据HTTP header对Spring Boot应用作路由分发实现AB testing的过程。

环境：

* OpenShift 4.6
* Service Mesh 2.x (Istio 1.6.5)
* Spring Boot 2.2.11.RELEASE
* Java 8



## AB testing

在Istio中配置一个特殊的HTTP header，如何调用该服务时传入了该header，则将路由分发到新版本v2，否则将路由分发到原版本v1。



## 配置OpenTracing Jaeger

参见：

* [在OpenShift使用Jaeger对Spring Boot / Spring Cloud应用作分布式服务跟踪](https://cookcode.blog.csdn.net/article/details/111226154)



**注意，一定要开启`enable-b3-propagation` ，因为Istio默认使用“B3 progration"，否则Istio无法根据HTTP header来实现路由分发。**



示例：

```yaml
opentracing:
  jaeger:
    enable-b3-propagation: true
    udp-sender:
      host: jaeger-agent.istio-system.svc
      port: 6831
```





这里，容易受Istio官方的bookinfo示例程序误导，以为提供任意的HTTP header，Istio都可以支持。

实际上，bookinfo程序在各个服务都自己实现了“b3 propagation"，才使得可以支持"end-user"这个看似普通，但是写死在代码里面的HTTP header。



而Spring Boot应用中依赖的是`opentracing-spring-jaeger-web-starter` 来作为Jaeger Client，该Jaeger Client传播的HTTP header格式为`baggage-key:value`。也就是**用于控制路由分发的HTTP header一定要以`baggage-`开头。**



参见：

* [Istio Trace context progagation](https://istio.io/latest/docs/tasks/observability/distributed-tracing/overview/#trace-context-propagation)
* [Istio Routing using OpenTracing Baggage/Distributed Context Propagation](https://medium.com/jaegertracing/istio-routing-using-opentracing-baggage-distributed-context-propagation-ed8d787a4bef)



## 配置服务的Istio VirtualService和DestinationRule



本例的服务调用链：

```txt
customer -> preference -> recommendation
```



下面只说明与recommendation相关的Istio配置。



其中recommendation有两个版本v1和v2。

DestinationRule示例：

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: recommendation
spec:
  host: recommendation
  subsets:
    - labels:
        version: v1
      name: version-v1
    - labels:
        version: v2
      name: version-v2
```



配置在调用recommendation时，传入HTTP header `baggage-is-ab-test`为`true` 时路由分发到新版本v2，否则都分发到原版本v1。



 VirtualServcie示例：

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: recommendation
spec:
  hosts:
    - recommendation
  http:
    - match:
        - headers:
            baggage-is-ab-test:
              exact: "true"
      route:
        - destination:
            host: recommendation
            subset: version-v2
    - route:
        - destination:
            host: recommendation
            subset: version-v1

```



参见：

* <https://istio.io/latest/docs/reference/config/networking/>
* <https://istio.io/latest/docs/reference/config/networking/virtual-service/#HTTPMatchRequest>



## 测试



### Postman测试

在Postman上测试:

- 测试不传入HTTP header时，返回结果都是v1。
- 测试传入HTTP header为`baggage-is-ab-test`为`true`时，返回结果都是v2。
- 测试传入HTTP header为`baggage-is-ab-test`为`false`时，返回结果都是v1。
- 测试传入HTTP header为其他字段时，返回结果都是v1。



### Curl测试

说明：`http://customer.store-springboot.com`   为本例的Isito Ingress Gateway地址。



测试不传入HTTP header时，返回结果都是v1:

```bash
while true; do
  curl http://customer.store-springboot.com
done
```



测试传入HTTP header为`baggage-is-ab-test`为`true`时，返回结果都是v2:

```bash
while true; do
  curl -H "baggage-is-ab-test:true" http://customer.store-springboot.com
done
```



测试传入HTTP header为`baggage-is-ab-test`为`false`时，返回结果都是v1:

```bash
while true; do
  curl -H "baggage-is-ab-test:false" http://customer.store-springboot.com
done
```



测试传入HTTP header为其他字段时，返回结果都是v1:

```bash
while true; do
  curl -H "is-ab-test:true" http://customer.store-springboot.com
done
```



```bash
while true; do
  curl -H "baggage-test:true" http://customer.store-springboot.com
done
```



### JMeter测试

1. 在Test Plan下创建Thread Group：
   - Number of Threads (users): 50
   - Ramp-up period (seconds): 2
   - Loop Count: 1000
2. 在Thread Group下添加Sample为HTTP request，输入HTTP request的Path。
3. 在HTTP request下添加Config Element为HTTP Header Manager，添加Header名称为`baggage-is-ab-test`，值为`true`来测试。
4. 在Kiali上查看服务流量。