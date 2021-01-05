[TOC]

# Istio功能验证

以Istio 1.6版本为例 （OCP4.6的Istio版本为1.6.5）。



## 参考文档

- <https://istio.io/>

- <https://access.redhat.com/documentation/en-us/openshift_container_platform/4.6/html/service_mesh/index>



## Istio架构

参见：

- <https://istio.io/v1.6/docs/ops/deployment/architecture/>



![Istio 1.6 架构图](https://istio.io/v1.6/docs/ops/deployment/architecture/arch.svg)





## 功能列表



| 分类               | 功能                                                         |
| ------------------ | ------------------------------------------------------------ |
| Traffic Management | 路由管理<br>蓝绿部署<br>金丝雀部署<br>A/B Testing<br>限流<br>断路器<br>超时<br>重试<br>流量镜像<br/>故障注入<br/>故障恢复 |
| Security           | mTLS<br>认证<br>鉴权<br>服务间通信管理                       |
| Policies           | Policy Enforcement                                           |
| Observability      | 网络拓扑<br>指标<br>日志<br>服务跟踪<br>服务调用链           |



## Traffic Management



参见：

- <https://istio.io/v1.6/docs/concepts/traffic-management/>



在Kubernetes上，Istio自动识别Kuberentes Service，并将其自动添加到Istio内部service registry中。



也就是说在Kubernetes上，Istio依靠Kubernetes Service来完成服务发现和负载均衡。默认使用Round-Robin负载均衡模式，可指定其他负载均衡模式。



核心概念：

- [VirtualService](https://istio.io/v1.6/docs/reference/config/networking/virtual-service/#VirtualService): 配置服务的流量路由规则
- [DestinationRule](https://istio.io/v1.6/docs/concepts/traffic-management/#destination-rules): 配置流量到达目标后做什么
- [Gateway](https://istio.io/v1.6/docs/reference/config/networking/gateway/#Gateway)：管理Service Mesh的进和出两个方向的流量
- [ServiceEntry](https://istio.io/v1.6/docs/reference/config/networking/service-entry/#ServiceEntry): 将外部服务作为一个Entry纳入Service Mesh管理



## Istio Example

参见：

- <https://istio.io/v1.6/docs/examples/bookinfo/>



## 功能验证任务



### Traffic Management



#### 请求路由分发（Request Routing）

参见：

- <https://istio.io/v1.6/docs/tasks/traffic-management/request-routing/>
- <https://istio.io/v1.6/docs/tasks/observability/distributed-tracing/overview/#trace-context-propagation>



前置条件：

- 需要在应用中引入OpenTracing Jaeger并开启B3 Propagation。



过程：

1. 将请求全部都路由到v1。
2. 根据指定的HTTP header路由到v2。



#### 故障注入（Fault Injection）



参见：

- <https://istio.io/v1.6/docs/tasks/traffic-management/fault-injection/>



过程：

1. 将请求全部都路由到v1。
2. 根据指定的HTTP header路由到v2。
3. 在v2路由上注入延时（delay）故障。
4. 在v2路由上注入中断（abort）故障。



#### 流量转移（Traffic Shifting)

参见：

- <https://istio.io/v1.6/docs/tasks/traffic-management/traffic-shifting/>
- <https://istio.io/v1.6/blog/2017/0.1-canary/>



利用Istio可以为不同subset（版本）来分发不同权重的路由，来作蓝绿部署和金丝雀部署。

利用Istio可以根据HTTP header来分发路由到subset（版本），来作A/B Testing。



蓝绿部署过程：

1. 开始时，100%流量全部分发给v1。
2. 转移其中50%的流量给v2。
3. 转移全部100%的流量给v2。



金丝雀部署过程：

1. 开始时，100%流量全部分发给v1。
2. 转移其中10%的流量给v2。
3. 转移其中20%的流量给v2。
4. 转移其中50%的流量给v2。
5. 转移其中80%的流量给v2。
6. 转移全部100%的流量给v2。



A/B Testing过程：

1. 开始时，100%流量全部分发给v1。
2. 将指定HTTP header的请求转发给v2。
3. 验证v2。





#### 请求超时（Request Timeouts）

参见：

- <https://istio.io/v1.6/docs/tasks/traffic-management/request-timeouts/>



除了可以在服务调用的代码中设置调用超时时间（timeout）外，还可以通过Istio来设置服务间调用的超时时间（Timeout）。



过程：

1. 设置服务调用超时时间（timeout）。
2. 通过故障注入的手段或其他方法，让服务提供方响应超时。
3. 验证服务调用方的行为。



#### 断路器(Circuit Breaker)

参见：

- <https://istio.io/v1.6/docs/tasks/traffic-management/circuit-breaking/>



Istio的断路器(Circuit Breaker)可以用来作熔断控制，实现故障隔离和防止雪崩效应。



过程

1. 设置断路器的断路发生条件。
2. 验证达到断路发生条件时，是否会熔断。



#### 流量镜像（Mirroring）

参见：

- <https://istio.io/v1.6/docs/tasks/traffic-management/mirroring/>



过程：

1. 将100%流量分发给v1。
2. 将流量镜像分发给v2。



#### Ingress Gateway

参见：

- <https://istio.io/v1.6/docs/tasks/traffic-management/ingress/ingress-control/>



Istio通过Ingress Gateway来控制外部请求访问Service Mesh中的服务。



过程：

1. 配置应用的Ingress Gateway。
2. 从集群外访问Service Mesh的应用。
3. 验证默认Ingress Gateway域名方式和自定义域名方式。



#### Egress Gateway

参见：

- <https://istio.io/v1.6/docs/tasks/traffic-management/egress/egress-control/>



Istio通过Egress Gateway来控制Service Mesh中的服务访问外部服务。



Istio的Egress Gateway的默认访问控制策略为`ALLOW_ANY`，也就是允许访问任意的外部服务。

如果将访问控制策略设置为`REGISTRY_ONLY`，则只有用ServiceEntry将外部服务注册到Istio internal registry后，才能访问这些外部服务。

用ServiceEntry将外部服务注册到Istio internal registry后，还可以使用Istio的VirtualService来对访问外部服务作路由管理。



### Security

参见：

- <https://istio.io/v1.6/docs/tasks/security/>



TODO



### Policies

参见：

- <https://istio.io/v1.6/docs/tasks/policy-enforcement/>



该章节下的功能已标注为过期（Deprecated），先忽略。



### Observability

参见：

- <https://istio.io/v1.6/docs/tasks/observability/>

  



TODO



#### Metrics



参见：

- <https://istio.io/v1.6/docs/tasks/observability/kiali/>
- <https://istio.io/v1.6/docs/tasks/observability/metrics/using-istio-dashboard/>



在Kiali上查看服务网络拓扑。

在Grafana上可视化查看Metrics。在istio-systems项目下查看Grafana的route。

打开Grafana，点击Dashboard / Manage，选择Istio Mesh Dashboard。



#### Logs

参见：

- <https://istio.io/v1.6/docs/tasks/observability/logs/access-log/>



查看Istio的Envoy access log。



#### 服务跟踪（Distributed Tracing)

参见：

- <https://istio.io/v1.6/docs/tasks/observability/distributed-tracing/>

  

在服务中即成OpenTracing Jaeger，并开启B3 Propagation。

在Jaeger中查看服务跟踪和服务调用链数据。















