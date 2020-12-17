[TOC]

# 迁移Spring Cloud应用到OpenShift ServiceMesh



## 微服务实现方式对比



下表对比了典型的Spring Cloud应用迁移到OpenShift ServiceMesh后实现微服务方式的区别：



| 分类               | SpringCloud                    | OpenShift ServiceMesh                         |
| ------------------ | ------------------------------ | --------------------------------------------- |
| 服务配置           | Spring Cloud Config Server     | ConfigMap, Secret                             |
| 服务注册与发现     | Eureka                         | Etcd + Service + 集群内DNS                    |
| 负载均衡           | Ribbon                         | Service, Istio的Envoy数据平面                 |
| 服务间调用         | OpenFeign 或 RestTemplate      | RestTemplate                                  |
| 路由管理           | Zuul 或 Spring Cloud Gateway   | Istio的VirtualService和DetinationRule         |
| 对外API网关        | Zuul 或 Spring Cloud Gateway   | Route，Istio的Ingress gateway和Egress gateway |
| 限流和熔断         | Hystrix                        | Istio的Envoy数据平面                          |
| 服务跟踪和调用链   | Zipkin 或 OpenTracing + Jaeger | OpenTracing + Jager                           |
| 服务网络拓扑       | 无                             | Kiali                                         |
| 灰度发布和蓝绿部署 | 无                             | Istio的Envoy数据平面                          |



## 应用配置

应用迁移到Istio，代码无需改动。

如果需要用OpenTracing Jaeger来做服务跟踪，则需要按照下面步骤配置。



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





## OpenShift配置



### 将项目纳入Istio管理

以Cluster Admin登录，选择`istio-system`项目，打开Operators / Installed Operators，找到Red Hat OpenShift Service Mesh，点击打开Istio Service Member Roll。

打开`default`，在`spec.members`下添加要纳入Istio管理的项目名称。



注意，OpenShift不会自动将该项目下全部workload都纳入Istio管理，只有完成下面的OpenShift配置后，workload才会纳入Istio管理。



一般，只有业务服务需要纳入Istio管理，基础服务不需要纳入Istio管理。



### 改造Deployment

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







### Service改造

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



### 流量监控

在Kiali中监控服务的流量。

可以在`istio-system`项目下查看Kiali的路由地址。



### 服务跟踪

在Jaeger中查看服务跟踪信息和服务调用链。

可以在`istio-system`项目下查看Jaeger的路由地址，也可以在Kiali中打开Jaeger。



## Troubleshooting



### Istio配置问题

* <https://kiali.io/documentation/v1.15/validations>





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

