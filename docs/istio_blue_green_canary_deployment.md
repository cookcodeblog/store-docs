@[toc]
# 用Istio实现蓝绿部署和金丝雀部署

## 前言

本文描述了用Istio对Spring Boot应用实现蓝绿部署和金丝雀部署。

环境：

- OpenShift 4.6
- Service Mesh 2.x (Istio 1.6.5)
- Spring Boot 2.2.11.RELEASE
- Java 8



本例的项目已纳入Istio管理，并注入了sidecar，并配置了原来版本(v1)的Istio config。

参见：

* [迁移Spring Cloud应用到OpenShift Service Mesh](https://cookcode.blog.csdn.net/article/details/111328930)

  

本例调用链：

```txt
customer -> preference -> recommendation (v1/v2)
```



## 蓝绿部署

**目的：**

- 如果发布失败，只影响部分用户，且不需要重新部署程序，可以快速回滚。



**过程：**

1. 线上原版本为v1。
2. 部署新版本v2，线上同时存在两个版本（蓝和绿版本）。
3. 切换50%路由到v2。
4. 验证通过后，切换100%路由到v2。如果验证失败，切换100%路由回v1（回滚）。



## 金丝雀部署

**目的：**

- 和蓝绿部署类似，更加谨慎地逐步切换到新版本。



**过程：**

1. 线上原版本为v1。
2. 部署新版本v2，线上同时存在两个版本（蓝和绿版本）。
3. 切换10%路由到v2。
4. 验证通过后，把更多的流量（比如20%），切换到v2。
5. 逐步增加分发给v2的流量，直到把100%的流量都分发给v2。
6. 如果验证失败，切换100%路由回v1（回滚）。


## Istio路由分发
下图列出了recommendation服务的路由分发架构。
简单起见，没有画出服务调用链上的其他服务。

![Istio路由分发](https://img-blog.csdnimg.cn/20201220111400118.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L25rbGluc2lydWk=,size_16,color_FFFFFF,t_70#pic_center)





## 部署新版本

创建一个新的Deployment来部署新版本v2。

该Deployment中的`labels`和`selector.matchLabels`需要包含 `version: v2` 标签。



以服务`recommendation`的Deployment为例。



- `recommendation-v1` :

```yaml
app: recommendation
version: v1
```



- `recommendation-v2` :

```yaml
app: recommendation
version: v2
```




## 配置DestinationRule

配置`recommendation`服务的Istio DestinationRule，定义了两个subset。其中`version-v1`为label为`version: v1`，`version-v2`为label为`version: v2`。



示例：

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



## 配置VirtualService



配置`recommendation`服务的Istio VirtualService，定义了两个destination。其中`version-v1` subset的路由权重为50%，`version-v2` subset的路由权重为50%。



示例：

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: recommendation
spec:
  hosts:
    - recommendation
  http:
  - route:
    - destination:
        host: recommendation
        port:
          number: 8080
        subset: version-v1
      weight: 50
    - destination:
        host: recommendation
        port:
          number: 8080
        subset: version-v2
      weight: 50

```



作金丝雀部署时，修改VirtualService，逐步增大`version-v2`的路由权重即可（需要保证两个subset的权重之和为100）。



## 测试



用JMeter模拟用户并发访问，或用curl命令来测试。



curl命令示例：

```bash
while true; do
  curl http://customer.example.com
done
```





再在Kiali上，选择项目，并选择"Versioned app graph"监控流量。

在Kiali Graph上，打开Disaplay，勾选Requests Percentage显示流量百分比，勾选Traffic Animation显示流量动画效果。



## Troubeshooting



### 根据路由权重分发流量不生效

**问题：**

- 根据路由权重分发流量不生效，流量还是“平均”地分发到v1和v2。

  

**解决方法：**

1. 检查项目是否已加入ServiceMeshMemberRoll。（OpenShift特性）
2. 检查Deployment是否已注入sidecar。（Istio不支持OpenShift DeploymentConfig，只支持Deployment）
3. 检查Deployment的`containerPort`中是否已包含指定端口。
4. 检查Deployment的`labels`和`selector.matchLabels`是否已包含`app`和`version`标签。
5. 检查Pod中是否已含有`sidecar-proxy`的container。
6. 检查Service是否正确关联了pod。
7. 检查Service中的port是否有命名，且port name为`<protocol>-<suffix>`或`<protocol>`，比如`http-8080`或`http`。
8. 检查Service的端口协议和Istio Config中的协议是否一致。
9. 在Kiali上检查是否配置了项目的Ingress Gateway和VirtualService，并配置了每个服务的DestinationRule，并配置了需要路由分发的服务的VirtualService。
10. 在Kiali上检查Istio Config是否有报错或警告。（注意是否与Istio的bookinfo示例程序冲突）
11. 在Kiali上检查Service详情是否有报错或警告。（注意Service的port没有命名或没有按照规范命名）
12. 在Kiali上检查，是否流量从`istio-ingressgateway`开始，是否正常显示了VirtualService和Service。



## 参考文档

* <https://istio.io/latest/docs/reference/config/networking/>

* [Kiali Valiation](<https://kiali.io/documentation/v1.15/validations>)

* [迁移Spring Cloud应用到OpenShift Service Mesh](https://cookcode.blog.csdn.net/article/details/111328930)


