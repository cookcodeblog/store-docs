[TOC]

# 迁移Spring Cloud应用到OpenShift ServiceMesh



## 微服务实现方式对比



下表对比了典型的Spring Cloud应用迁移到OpenShift ServiceMesh后实现微服务方式的区别：



| 分类               | SpringCloud                    | OpenShift ServiceMesh                         |
| ------------------ | ------------------------------ | --------------------------------------------- |
| 服务配置           | Spring Cloud Config Server     | ConfigMap, Secret                             |
| 服务注册与发现     | Eureka                         | Etcd + Service + 集群内DNS                    |
| 负载均衡           | Ribbon                         | Service, Istio的Envoy数据平面                 |
| 服务间调用         | OpenFeign 或 RestTemplate      | 任意HTTP client                               |
| 路由管理           | Zuul 或 Spring Cloud Gateway   | Istio的VirtualService和DetinationRule         |
| 对外API网关        | Zuul 或 Spring Cloud Gateway   | Route，Istio的Ingress gateway和Egress gateway |
| 限流和熔断         | Hystrix                        | Istio的Envoy数据平面                          |
| 服务跟踪和调用链   | Zipkin 或 OpenTracing + Jaeger | OpenTracing + Jager                           |
| 服务网络拓扑       | 无                             | Kiali                                         |
| 灰度发布和蓝绿部署 | 无                             | Istio的Envoy数据平面                          |



## 应用配置



### 应用改造

Spring Boot应用迁移到Istio，代码无需改动。

但是如果需要用OpenTracing Jaeger来做服务跟踪，则需要按照下面步骤配置。



Spring Cloud应用迁移到Istio，需要将基于Spring Cloud Eureka的服务注册发现，改为基于OpenShift Service的的服务注册发现，否则无法使用Istio的traffic management功能。



### 引入OpenTracing Jaeger

添加Maven依赖：

```xml
<dependency>
  <groupId>io.opentracing.contrib</groupId>
  <artifactId>opentracing-spring-jaeger-web-starter</artifactId>
  <version>3.2.2</version>
</dependency>
```



修改应用配置：

```yaml
opentracing:
  jaeger:
    enable-b3-propagation: true
    udp-sender:
      host: jaeger-agent.istio-system.svc
      port: 6831
```



### 去掉Eureka

1. 在Maven pom.xml中删除`spring-cloud-starter-netflix-eureka-client`依赖。

2. 在Spring Boot Application类中，删除`@EnableEurekaClient`或`@EnableDiscoveryClient`注解。

3. 项目中使用了RestTemplate调用服务，去掉`@LoadBalanced`注解。

4. 项目中使用了OpenFeign调用服务，在`@FeignClient`注解中指定`url`为服务地址。OpenFeign在有指定`url`时，不再根据`name`去Eureka查找服务地址。

5. 对Zuul Gateway，改为使用静态url配置和禁用Eureka。示例：

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

   



## OpenShift配置



### 将项目纳入Istio管理

以Cluster Admin登录，选择`istio-system`项目，打开Operators / Installed Operators，找到Red Hat OpenShift Service Mesh，点击打开Istio Service Member Roll。

打开`default`，在`spec.members`下添加要纳入Istio管理的项目名称。



注意，OpenShift不会自动将该项目下全部workload都纳入Istio管理，只有完成下面的OpenShift配置后，workload才会纳入Istio管理。



一般，只有业务服务需要纳入Istio管理，基础服务不需要纳入Istio管理。



### 配置Deployment

1. 如果原来使用OpenShift DeploymentConfig来部署，要改成用Deployment来部署。Istio只支持Deployment方式部署。

2. 需要在Deployment中增加注入Sidecar，在Deployment YAML加入annotation：

   ```yaml
   spec:
     template:
       metadata:
         annotations:
           sidecar.istio.io/inject: "true"
   ```

3. 确保在Deployment中用`containerPort`列出每个端口，Istio sidecar proxy将会忽略不列出来的端口。
4. 确保在Deployment中使用了`app`和`version` 的label和selector label：
   - `metadata.labels`
   - `spec.selector.matchLabels`
   - `spec.template.metadata.labels`

4. 建议以`<deployment-name>-<version>` 来区分不同版本的Deployment，比如`recommendation-v1`和`recommendation-v2`。



> **Pod ports**: Pods must include an explicit list of the ports each container listens on. Use a `containerPort` configuration in the container specification for each port. Any unlisted ports bypass the Istio proxy.



> **Deployments with app and version labels**: We recommend adding an explicit `app` label and `version` label to deployments. Add the labels to the deployment specification of pods deployed using the Kubernetes `Deployment`. The `app` and `version` labels add contextual information to the metrics and telemetry Istio collects.
>
> - The `app` label: Each deployment specification should have a distinct `app` label with a meaningful value. The `app` label is used to add contextual information in distributed tracing.
> - The `version` label: This label indicates the version of the application corresponding to the particular deployment.



参见：

* <https://istio.io/latest/docs/ops/deployment/requirements/>



### 配置Service

1. 需要Istio sidecar proxy代理流量的Pod都必须归属到一个OpenShift Service。
2. 需要为Service的port命名，命名规则为`<protocol>-<suffix>`，其中`suffix`选填。port名称比如`http-8080`或`http`。如果没有在Service为port命名，或没有按规则来命名，Istio sidecar proxy将忽略这些端口。
3. Service中的端口用到的协议要和Istio配置中用到的协议一致，比如都是HTTP协议。
4. 检查Service所关联的pod是否符合预期。



> **Service association**: A pod must belong to at least one Kubernetes service even if the pod does NOT expose any port. If a pod belongs to multiple [Kubernetes services](https://kubernetes.io/docs/concepts/services-networking/service/), the services cannot use the same port number for different protocols, for instance HTTP and TCP.



参见：

* <https://kiali.io/documentation/v1.15/validations/#_kia0601_port_name_must_follow_protocol_suffix_form>



## Istio配置

为应用的流量入口配置Istio Ingress Gateway和VirtualService，Ingress Gateway和VirtualService的`host`为应用的域名，不要使用`*` 通配符，不然会有“More than one Gateway for the same hsot port combination"的错误。

在`istio-system`项目下，可查看OpenShift为Istio Ingress Gateway创建的路由。



为服务配置VirtualService和DestinationRule来实现路由管理，比如为不同版本分配不同的路由权重来实现灰度发布。



完成配置后，在Kiali上检查Istio Config、Deployment和Service是否报错。



参见：

* <https://istio.io/latest/docs/reference/config/networking/>
* <https://kiali.io/documentation/v1.15/validations/#_kia0301_more_than_one_gateway_for_the_same_host_port_combination>





### 配置Istio ingress gatway默认路由

如果不想采用自定义域名，也可以配置Istio ingress gateway默认路由。



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

## Demo



### 灰度发布

1. 发布版本v1。
2. 用JMeter模拟并发访问，在Kiali中监控服务的流量。此时流量全部发给v1。
3. 发布版本v2。
4. 继续在Kiali中监控服务的流量，此时流量仍然全部发给v1。
5. 配置Istio的VirtualService和DetinationRule，分配10%的流量给v2。
6. 继续在Kiali中监控服务的流量，此时90%的流量发给v1，10%的流量发给v2。
7. 配置Istio的VirtualService和DetinationRule，分配50%的流量给v2。
8. 继续在Kiali中监控服务的流量，此时50%的流量发给v1，50%的流量发给v2。
9. 配置Istio的VirtualService和DetinationRule，分配100%的流量给v2。
10. 继续在Kiali中监控服务的流量，此时100%的流量发给v2。



参见：

* <https://istio.io/latest/docs/tasks/traffic-management/traffic-shifting/>
* [Canary Deployments using Istio](https://istio.io/latest/blog/2017/0.1-canary/)



### 流量监控

在Kiali中监控服务的流量。

可以在`istio-system`项目下查看Kiali的路由地址。

也可以在OpenShift Typology的右上角打开Kiali。



SpringBoot应用的流量监控：



recomendation的v1占90%，v2占10%：

![image-20201217132300698](/Users/linsirui/Library/Application Support/typora-user-images/image-20201217132300698.png)



Recommendation的v1占80%，v2占20%。



![image-20201217132611733](/Users/linsirui/Library/Application Support/typora-user-images/image-20201217132611733.png)







### 服务跟踪

在Jaeger中查看服务跟踪信息和服务调用链。

可以在`istio-system`项目下查看Jaeger的路由地址，也可以在Kiali中打开Jaeger。



SpringBoot应用的服务跟踪信息：



![image-20201217134934473](/Users/linsirui/Library/Application Support/typora-user-images/image-20201217134934473.png)



![image-20201217135005161](/Users/linsirui/Library/Application Support/typora-user-images/image-20201217135005161.png)



## Spring Cloud Netflix与Istio



使用Eureka后，微服务间调用，不再通过OpenShift Service，而是直接访问Eureka返回的目标微服务的某个Pod IP。

由于不经过OpenShift Service，对该目标微服务，Istio的路由规则不生效，也就无法使用Istio的路由管理功能。



![image-20201217141854986](/Users/linsirui/Library/Application Support/typora-user-images/image-20201217141854986.png)



### Eureka和Istio的路由方式对比





![image-20201217140329144](/Users/linsirui/Library/Application Support/typora-user-images/image-20201217140329144.png)





### 典型的Spring Cloud Neflix架构



![image-20201217143933161](/Users/linsirui/Library/Application Support/typora-user-images/image-20201217143933161.png)





### Spring Cloud Netflix与Istio对比

采用Spring Cloud Netflix的微服务：



![img](https://dotnetvibes.files.wordpress.com/2019/05/netflix-oss-issues.png?w=700)



采用Service Mesh sidecar的微服务架构：



![Sidecar Design Pattern](https://dotnetvibes.files.wordpress.com/2019/05/sidecar-design-pattern.png?w=700)





两种方式对比：

![image-20201217153051097](/Users/linsirui/Library/Application Support/typora-user-images/image-20201217153051097.png)



小结：

* Spring Cloud Netflix: 

  - 优点：成熟
  - 缺点：
    - 每个微服务都要集成一些微服务基础组件功能。
    - 每个系统都要部署一些微服务基础组件。
    - 只支持Java。
    - 代码侵入。

* Istio：
  * 优点：
    * 由PaaS平台和Istio提供微服务基础组件功能，微服务只需要关注业务本身。
    * 语言无关，支持多语言。
    * 简化系统架构。
    * 功能更丰富，更强大。

  * 缺点：
    * Service Mesh 还在快速发展中
    * 额外的网络开销





## Troubleshooting



### Istio配置问题

* <https://kiali.io/documentation/v1.15/validations>



### bookinfo的Istio配置问题

bookinfo的Istio Ingress Gateway 和 VirtualServcie的`host`使用了`*`通配符，会影响其他应用。

在测试完bookinfo后，应将其Istio config删除。



### Kiali graph unkown

Kiali graph上的unkown节点，表示流量经过的节点Kiali未能识别出service或workload名称。

可能的情况：

* Health check
* Prometheus采集指标





参见：

* <https://kiali.io/documentation/latest/faq/#many-unknown>



### Kiali graph passthroughcluster

正常现象。



参见：

* <https://stackoverflow.com/questions/61633167/why-is-my-inter-service-traffic-showing-in-the-passthrough-cluster-in-kiali>
* <https://kiali.io/documentation/latest/faq/#passthrough-traffic>





## 参考文档

### Istio文档

* <https://istio.io/>

  

### OpenShift文档

* [Service Mesh 2 on OpenShift 4.6](https://access.redhat.com/documentation/en-us/openshift_container_platform/4.6/html/service_mesh/service-mesh-2-x)
* [istio-tutorial](https://github.com/redhat-scholars/istio-tutorial)



### Jaeger文档

* <https://github.com/opentracing-contrib/java-spring-jaeger>
* <https://mvnrepository.com/artifact/io.opentracing.contrib/opentracing-spring-jaeger-cloud-starter>
* <https://mvnrepository.com/artifact/io.opentracing.contrib/opentracing-spring-jaeger-web-starter>

* [Jaeger Intro - Yuri Shkuro, Ube](https://www.youtube.com/watch?v=UNqilb9_zwY)
* [Jaeger Intro - Yuri Shkuro, Uber Technologies & Pavol Loffay, Red Hat](https://www.youtube.com/watch?v=cXoTja7BvSA)
* [Jaeger Deep Dive - Yuri Shkuro, Uber Technologies & Pavol Loffay, Red Hat](https://www.youtube.com/watch?v=zb0fdU6c0KU)
* [Mastering-Distributed-Tracing](https://github.com/PacktPublishing/Mastering-Distributed-Tracing)



### Kiali 文档

* [Kiali Valiation](<https://kiali.io/documentation/v1.15/validations>)

* [Kiali FAQ](https://kiali.io/documentation/latest/faq/)



### 微服务相关文档

* [Microservices Journey from Netflix OSS to Istio Service Mesh](https://dzone.com/articles/microservices-journey-from-netflix-oss-to-istio-se)
* [Consul vs. Istio](https://www.consul.io/docs/intro/vs/istio)
* [Microservices.NOW: from Netflix OSS to Istio Service Mesh](https://www.youtube.com/watch?v=WaD0SBb13AU)
* [How to Get a Service Mesh Into Prod without Getting Fired - William Morgan, Buoyant, Inc](XA1aGpYzpYg)
* [Microservices in the Cloud with Kubernetes and Istio (Google I/O '18)](https://www.youtube.com/watch?v=gauOI0O9fRM)

