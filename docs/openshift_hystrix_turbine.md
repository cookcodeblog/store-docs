@[toc]
# 在OpenShift上使用Hystrix Dashboard和Turbine来汇聚和可视化展示Hystrix指标



## 前言



在一个Spring Boot / Spring Cloud项目中使用Hystrix来作熔断机制，并采用Turbine来汇聚Hystrix指标，再通过Hystrix Dashboard来可视化展示Hystrix指标。



## 为服务采用Hystrix机制

创建了两个服务：`customer`和`preference` 服务。将这两个服务注册到Eureka上，并启用Hystrix。

下面只说明和Hystrix相关部分。



引入依赖：

```xml
<dependency>
	<groupId>org.springframework.cloud</groupId>
	<artifactId>spring-cloud-starter-netflix-hystrix</artifactId>
</dependency>
<dependency>
  <groupId>org.springframework.boot</groupId>
  <artifactId>spring-boot-starter-actuator</artifactId>
</dependency>
```



在Application类上添加`@EnableCircuitBreaker` 注解，表示启用熔断机制。


在需要熔断控制的方法上`@HystrixCommand` 注解。可以指定熔断发生后的fallback方法和超时时间。示例：
```java
@HystrixCommand(fallbackMethod = "defaultMethod",
            commandProperties = {@HystrixProperty(name = "execution.isolation.thread.timeoutInMilliseconds", value = "5000")})
```



在`bootstrap.yaml`中配置暴露`hystrix.stream`的endpoint：

```yaml
management:
  endpoints:
    web:
      exposure:
        include: "hystrix.stream" 
```



Turbine或Hystrix Dashboad可以采集该endpoint的Hystrix指标。



## Hystrix Dashboard应用说明



创建一个名为`hystrix-ui`的服务来作为Hystrix Dashboard，通过Turbine汇聚和采集上面两个服务的Hystrix指标。



### 引入依赖

引入依赖：

```xml
<dependency>
  <groupId>org.springframework.cloud</groupId>
  <artifactId>spring-cloud-starter-netflix-hystrix-dashboard</artifactId>
</dependency>
<dependency>
  <groupId>org.springframework.cloud</groupId>
  <artifactId>spring-cloud-starter-netflix-turbine</artifactId>
</dependency>
```



### Application 类



Application类：

```java
@EnableTurbine
@EnableHystrixDashboard
@EnableEurekaClient
@SpringBootApplication
public class HystrixUiApplication {
    public static void main(String[] args) {
        SpringApplication.run(StoreHystrixUiApplication.class, args);
    }
}
```



说明：

- `@EnableEurekaClient` 作为Eureka客户端注册到Eureka中。
- `@EnableHystrixDashboard` 作为Hystrix Dashboard。
- `@EnableTurbine` 启用Turbine汇聚Hystrix指标。



### bootstrap 配置

`bootstrap.yaml` 如下：

```yaml
spring:
  application:
    name: hystirx-ui
```



说明：

* 定义服务名为`hystirx-ui`



### application 配置



#### OpenShift使用的application配置

不指定profile时，OpenShift使用`application.yaml`。

`application.yaml` 如下：

```yaml
eureka:
  client:
    serviceUrl:
      defaultZone: http://service-registry:8080/eureka/
  instance:
    prefer-ip-address: true

turbine:
  appConfig: "customer,preference"
  clusterNameExpression: new String("default")

hystrix:
  dashboard:
    proxyStreamAllowList: '*'

server:
  port: 8080

```



说明：

* 将Hystrix Dahboard注册到Eureka上。
* `service-registry` 为Eureka server在OpenShift的service名称。
* 设置 `prefer-ip-address: true` ，避免在云环境中根据Hostname无法路由的问题。
* `turbine.appConfig` 配置了采集`customer`和`preference` 两个服务的Hystrix指标。
* `turbine.clusterNameExpression` 定义了Turbine cluster名称为`default`。
* `proxyStreamAllowList: '*'` 允许采集任意的Hytrix stream。



#### 本地调试使用的application配置

本地调试用`application-local.yaml`。

和`application.yaml`类似，只是Eureka server和端口的值不同。

```yaml
eureka:
  client:
    serviceUrl:
      defaultZone: http://localhost:8761/eureka/

server:
  port: 9090
```



## 本地使用Hystrix Dashboard



Hystrix Dashboard：<http://localhost:9090/hystrix/>

Turbine Stream: <http://localhost:9090/turbine.stream?cluster=default>

Hystrix Stream:

- `customer`服务的Hystrix stream： `http://localhost:<port>/actuator/hystrix.stream`

* `preference`服务的Hystrix stream：` http://localhost:<port>/actuator/hystrix.stream`

  

打开Hystirx Dashboard，输入Turbine Stream，点击Monitor来监控`customer`和`preference`服务的Hystrix指标。

也可以单独输入某一个服务的Hystrix stream来单独查看该服务的Hystrix指标。



可用Postman或JMeter调用服务的API来测试熔断机制。



## OpenShift上使用Hystrix Dashboard



在OpenShift上部署`hystrix-ui`服务后，为该服务创建路由。

`hystix-ui`路由URL：`http://hystrix-ui-<project>.apps.<openshift-domain>/`

此时打开该路由，页面显示“Whitelabel Error Page”是正常的，在浏览器URL后添加`/hystrix/`就可以打开Hystrix Dashboard。

Hystrix Dashboard：`http://<hystrix-ui-route-url>/hystrix/`

Turbine Stream: <http://hystrix-ui:8080/turbine.stream?cluster=default>

Hystrix Stream:

- `customer`服务的Hystrix stream： <http://customer:8080/actuator/hystrix.stream>

* `preference`服务的Hystrix stream： <http://preference:8080/actuator/hystrix.stream>



打开Hystirx Dashboard，输入Turbine Stream，点击Monitor来监控`customer`和`preference`服务的Hystrix指标。

也可以单独输入某一个服务的Hystrix stream来单独查看该服务的Hystrix指标。



**注意：不要修改`hystrix-ui`的route，来添加`/hystrix/`的`path`，不然会导致Hystrix Dashboard的页面的JavaScript报错。**





## 参考文档

* <https://stackabuse.com/spring-cloud-turbine/>
* <https://stackabuse.com/spring-cloud-hystrix/>
* [Hystrix Timeouts And Ribbon Clients](https://cloud.spring.io/spring-cloud-netflix/multi/multi__hystrix_timeouts_and_ribbon_clients.html)
* [Circuit Breaker: Hystrix Dashboard](https://cloud.spring.io/spring-cloud-netflix/multi/multi__circuit_breaker_hystrix_dashboard.html)
* [Circuit Breaker: Hystrix Clients](https://cloud.spring.io/spring-cloud-netflix/multi/multi__circuit_breaker_hystrix_clients.html)
* <https://spring.io/guides/gs/circuit-breaker/>
* <https://cloud.spring.io/spring-cloud-netflix/2.0.x/single/spring-cloud-netflix.html>
* <https://github.com/Netflix/Hystrix>
* [Hystrix Configuration](https://github.com/Netflix/Hystrix/wiki/Configuration)
* [Full analysis of hystrix configuration parameters](https://developpaper.com/full-analysis-of-hystrix-configuration-parameters/)




