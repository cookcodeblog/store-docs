# 部署Spring Boot应用到OpenShift Service Mesh



## Spring Boot应用

创建分支`istio-springboot`

去掉依赖：

- `spring-cloud-starter-netflix-eureka-client`
- `spring-cloud-starter-openfeign`
- `opentracing-spring-jaeger-cloud-starter`



添加依赖：

```xml
<dependency>
  <groupId>io.opentracing.contrib</groupId>
  <artifactId>opentracing-spring-jaeger-web-starter</artifactId>
  <version>3.2.2</version>
</dependency>
```

在`application.yaml`中配置OpenTracing信息。

参见：
- <https://github.com/opentracing-contrib/java-spring-jaeger>
- <https://github.com/opentracing-contrib/java-spring-cloud>
- <https://www.jaegertracing.io/docs/1.21/getting-started/>

示例：

```yaml
opentracing:
  jaeger:
    enable-b3-propagation: true
#    http-sender:
#      url: ${JAEGER_COLLECTOR_ENDPOINT:http://jaeger-collector.istio-system.svc:14268/api/traces}
    udp-sender:
      host: ${JAEGER_AGENT_HOST:jaeger-agent.istio-system.svc}
      port: ${JAEGER_AGENT_PORT:6831}
    service-name: customer

```



修改`application-local.yaml` ：

- 去掉`eureka` 的配置属性
- 指定`server.port` 为固定端口



修改`application.yaml` ：

- 去掉`eureka` 的配置属性



去掉EurekaClient和OpenFeign的代码，改为用RestTemplate调用。



固定端口：

- `custome`r: `8128`
- `preference`: `8228`
- `recommendation`: `8328`



测试：

* Customer服务：http://localhost:8128



## 部署Spring Boot应用到OpenShift



在`openshift-templates-springboot`目录下：

```bash
oc new-project william-store-springboot

oc apply -f ./static

oc apply -f ./config-server
oc apply -f ./customer
oc apply -f ./hystrix-ui
oc apply -f ./preference
oc apply -f ./recommendation

oc apply -f ./istio-networking

# Check istio ingress gateway route
oc get route -n istio-system | grep william-store-springboot
```



在Jaeger上查看服务间调用的调用链信息。



在Kiali上查看服务的网络拓扑和Istio配置。

