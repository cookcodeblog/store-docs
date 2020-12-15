@[toc]
# 在OpenShfit使用Jaeger对Spring Boot / Spring Cloud应用作分布式服务跟踪



## 前言

本文描述了在OpenShift中使用Jaeger对Spring Boot / Spring Cloud应用作分布式服务跟踪。



## 关于Jaeger

Jaeger是一个优秀的基于OpenTracing的分布式服务跟踪系统。



参见：

* [About Jaeger](https://www.jaegertracing.io/docs/1.21/)
* [Jaeger Architecture](https://www.jaegertracing.io/docs/1.21/architecture/)
* [OpenTracing标准](https://github.com/opentracing/specification/blob/master/specification.md)



## 在Spring Boot应用中用Jaeger作服务跟踪

如果服务间依赖只用了RestTemplate，可以只引入`opentracing-spring-jaeger-web-starter` 依赖。



> The `opentracing-spring-jaeger-web-starter` starter is convenience starter that includes both `opentracing-spring-jaeger-starter` and `opentracing-spring-web-starter` This means that by including it, simple web Spring Boot microservices include all the necessary dependencies to instrument Web requests / responses and send traces to Jaeger.



添加Maven依赖：

```xml
<dependency>
  <groupId>io.opentracing.contrib</groupId>
  <artifactId>opentracing-spring-jaeger-web-starter</artifactId>
  <version>3.2.2</version>
</dependency>
```



无需代码改动，已完成在应用添加OpenTracing Jaeger支持。



此时OpenTracing Jaeger的默认配置为：

```yaml
opentracing:
  jaeger:
    udp-sender:
      host: localhost
      port: 6831
```



说明：

* Jaeger Client将服务跟踪数据发送给Jaeger Agent（UDP协议，Agent Host: `localhost`, Agent Port: `6831`）



也可以选择直接发送服务跟踪数据给Jaeger Collector（不推荐，使用的是HTTP协议，性能比UDP协议差）：



```yaml
opentracing:
  jaeger:
    http-sender:
    url: http://localhost:14268/api/traces
```



说明：

* Jaeger Client直接将服务跟踪数据发送给Jaeger Collector，Jaeger Collector的端口为`14268`。



参见：

* [Jaeger Getting Started](https://www.jaegertracing.io/docs/1.21/getting-started/)



## 在Spring Cloud应用中用Jaeger作服务跟踪

参见上一节的描述，下面只描述不同的地方。



如果需要监控OpenFeign等Spring Cloud的服务间调用，则需要引入`opentracing-spring-jaeger-cloud-starter`依赖。



> The `opentracing-spring-jaeger-cloud-starter` starter is convenience starter that includes both `opentracing-spring-jaeger-starter` and `opentracing-spring-cloud-starter` This means that by including it, all parts of the Spring Cloud stack supported by Opentracing will be instrumented



添加Maven依赖：

```xml
<dependency>
  <groupId>io.opentracing.contrib</groupId>
  <artifactId>opentracing-spring-jaeger-cloud-starter</artifactId>
  <version>3.2.2</version>
</dependency>
```



无需代码改动，已完成在应用添加OpenTracing Jaeger支持。





## 发送服务跟踪数据到本地Jaeger



最简单的方法是在本地以docker方式运行Jaeger的all-in-one的Docker容器：



```bash
docker run -d --name jaeger \
  -e COLLECTOR_ZIPKIN_HTTP_PORT=9411 \
  -p 5775:5775/udp \
  -p 6831:6831/udp \
  -p 6832:6832/udp \
  -p 5778:5778 \
  -p 16686:16686 \
  -p 14268:14268 \
  -p 14250:14250 \
  -p 9411:9411 \
  jaegertracing/all-in-one:1.21
```



参见：

* [Jaeger Geetting Started](https://www.jaegertracing.io/docs/1.21/getting-started/)



启动应用后，测试服务间调用。



打开Jaeger UI：<http://localhost:16686> ，选择某个服务，就可以查看该服务的调用链和详细信息。



## 发送服务跟踪数据到服务端Jaeger

在服务端（ 服务器）测试时，需要修改应用配置`opentracing.jaeger.upd-sender.host` 为服务端Jaeger的地址。

Jaeger UI：<http://jaeger_host:16686>



## 发送服务跟踪数据到OpenShift的Jaeger

前置条件：

* OpenShift 4.6
* 已安装Service Mesh 2
* 已以Service Mesh方式安装Jaeger
* 项目已纳入OpenShift Service Mesh管理



修改应用配置：

```yaml
opentracing:
  jaeger:
    enable-b3-propagation: true
    udp-sender:
      host: jaeger-agent.istio-system.svc
      port: 6831
    service-name: myservice
```



说明：

* `enable-b3-propagation: true` : 兼容Zipkin collector。

  > Propagate headers in B3 format (for compatibility with Zipkin collectors)

* `jaeger-agent.istio-system.svc` 为Jaeger Agent的OpenShift Service名称，可通过`oc get svc -n istio-system ｜grep jaeger` 查看。

* `service-name` 为服务名称，和`spring.application.name`保持一致。 

  > `unknown-spring-boot` Will be used as the service-name if no value has been specified to the property `spring.application.name` or `opentracing.jaeger.service-name` (which has the highest priority).
  
  

也可以选择直接发送服务跟踪数据给Jaeger Collector（不推荐，使用的是HTTP协议，性能比UDP协议差）：



```yaml
opentracing:
  jaeger:
    http-sender:
    url: http://jaeger-collector.istio-system.svc:14268/api/traces
```



参见：

* <https://github.com/opentracing-contrib/java-spring-jaeger>



Jaeger UI: `https://jaeger-istio-system.apps.<openshift_domain>/` 。

可通过`oc get route -n istio-system | grep jaeger` 获得Jaeger UI地址。



## 使用限制



注意：截止本文发表时间，`opentracing-spring-jaeger-cloud-starter` 只支持Spring Boot 2.2.x，还未支持Spring Boot 2.3.x 和 2.4.x。



参见：

* <https://github.com/opentracing-contrib/java-spring-jaeger/issues/114>



## 参考文档

* <https://github.com/opentracing-contrib/java-spring-jaeger>
* <https://mvnrepository.com/artifact/io.opentracing.contrib/opentracing-spring-jaeger-cloud-starter>
* <https://mvnrepository.com/artifact/io.opentracing.contrib/opentracing-spring-jaeger-web-starter>



## 扩展阅读

* [Mastering-Distributed-Tracing](https://github.com/PacktPublishing/Mastering-Distributed-Tracing)


