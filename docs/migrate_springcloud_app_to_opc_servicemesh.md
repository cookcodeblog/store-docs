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



## 应用改造

