[TOC]

# Istio 故障注入（混沌工程）



## 参考文档



- <https://istio.io/v1.6/docs/tasks/traffic-management/fault-injection/>
- <https://istio.io/v1.6/docs/reference/config/networking/virtual-service/#HTTPFaultInjection>
- <https://istio.io/v1.6/docs/concepts/traffic-management/>
- <https://github.com/redhat-scholars/istio-tutorial/blob/master/documentation/modules/ROOT/pages/6fault-injection.adoc>





## 注入延迟故障（模拟响应慢，网络延迟，负载过高）



### 注入超时7秒钟



在Kiali上观察，像被按下了慢动作键，响应很慢，并且引发了连锁反应。

在Kiali上选择注入超时的路由，查看HTTP request response time，查看P95（95%的请求）和P99（99%的请求）的响应时间。

在JMeter和PostMan中调用出现了“504 Gateway timeout”的错误。



注入超时主要是为了检查服务间调用有没有正确设置了timeout。





```yaml
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: recommendation
spec:
  hosts:
    - recommendation
  http:
    - fault:
        delay:
          fixedDelay: 7.000s
          percent: 5
      route:
        - destination:
            host: recommendation
            subset: version-v1
```



### 根据header注入超时7秒钟



根据`baggage-is-fault-injection` 头来注入

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: recommendation
spec:
  hosts:
    - recommendation
  http:
    - fault:
        delay:
          fixedDelay: 3.000s
          percent: 100
      match:
        - headers:
            baggage-is-fault-injection:
              exact: 'true'
      route:
      - destination:
          host: recommendation
          port:
            number: 8080
          subset: version-v1
    - route:
      - destination:
          host: recommendation
          port:
            number: 8080
          subset: version-v1

```





### Spring Boot设置timeout

[The Guide to RestTemplate](https://www.baeldung.com/rest-template)

<https://stackoverflow.com/questions/13837012/spring-resttemplate-timeout>



在Spring Boot Application中添加：

```java
@Bean
public RestTemplate restTemplate(RestTemplateBuilder restTemplateBuilder) {
  return restTemplateBuilder.setConnectTimeout(Duration.ofMillis(5000))
    .setReadTimeout(Duration.ofMillis(2000))
    .build();
}
```



### Istio retry



![image-20201223225751430](/Users/linsirui/Library/Application Support/typora-user-images/image-20201223225751430.png)

为什么设置timeout为2s，实际超时却为6s，且retry调用了3次 ？

https://istio.io/latest/docs/concepts/traffic-management/#retries

https://istio.io/latest/docs/reference/config/networking/virtual-service/#HTTPRetry

https://istio.io/latest/docs/reference/config/networking/virtual-service/#HTTPRoute



https://github.com/istio/istio/issues/14900

https://github.com/istio/istio/pull/14925

https://discuss.istio.io/t/disable-globally-the-default-retry-policy/9126







> The default retry behavior for HTTP requests is to retry twice before returning the error.



> you can adjust your retry settings on a **per-service** basis in [virtual services](https://istio.io/latest/docs/concepts/traffic-management/#virtual-services) without having to touch your service code



目前，故障注入时，retry和timeout不生效。

https://stackoverflow.com/questions/56152245/retries-not-working-with-fault-injection-in-istio

> Fault injection policy to apply on HTTP traffic at the client side. Note that timeouts or retries will not be enabled when faults are enabled on the client side.



```bash
curl -H "baggage-is-fault-injection:true" http://istio-ingressgateway-istio-system.apps.ocp4-grub.ocp.com/customer
```



```bash
date && curl -H "baggage-is-fault-injection:true" http://istio-ingressgateway-istio-system.apps.ocp4-grub.ocp.com/customer && date
```



不能全局地disable默认的retry。

只能为每个服务（被调用的服务）创建VirtualService，然后设置 ？？

```yaml
retries:
  attempts: 0
```





## 注入中断故障（模拟没有响应）



### 往路由中注入503错误



往路由中注入503错误，50%错误。

在Kiali上，选择recommendation服务，看错误率是否接近50%。

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: recommendation
spec:
  hosts:
    - recommendation
  http:
    - fault:
        abort:
          httpStatus: 503
          percentage:
            value: 50 # 100 means 100%
      route:
        - destination:
            host: recommendation
            subset: version-v1
    - route:
        - destination:
            host: recommendation
            subset: version-v1
          weight: 100

```













