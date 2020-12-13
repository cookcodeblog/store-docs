[TOC]

# 部署demo项目到OpenShift



## 创建OpenShift项目

在OpenShift上创建名为`william-store`的项目。



## 部署Spring Boot应用到OpenShift

使用OpenShift 的 Red Hat OpenJDK S2I builder方式来部署Spring Boot应用。

所有Spring Boot应用都使用`8080`端口。

切换到Developer视图，点击Add，选择From Catalog，选择Builder Image。

选择“Read Hat OpenJDK“，点击“Create Application”：

- Builder Image Version：`openjdk-8-el7`
- Git Repo URL：应用的code repository url，比如`https://github.com/cookcodeblog/store-config-server.git`。
- Git Reference: `main`  ，默认分支。
- Application: `store`
- Name: 服务名称，比如`config-server`。
- Resources：`DeploymentConfig` 
- Create a route to the application: 对需要对集群外提供访问的勾选该项。



因为GitHub无法访问演示环境的OpenShift的，因此无法通过GitHub webhook来通知OpenShift自动构建和部署，在代码提交后，需要手工在演示环境的OpenShift构建，构建完成后会自动触发部署。



## 配置使用内部Nexus

为加快拉取Maven依赖速度，可以在BuildConfig中配置环境变量`MAVEN_MIRROR_URL`来指向内部Nexus的repo。



## Demo项目

**项目URL：**

- OpenShift拓扑图：<https://console-openshift-console.apps.ocp4-grub.ocp.com/topology/ns/william-store/graph>

- 配置中心: <http://config-server-william-store.apps.ocp4-grub.ocp.com/customer/default>

- 服务注册中心：<http://service-registry-william-store.apps.ocp4-grub.ocp.com/>

- Customer服务（Zuul）：<http://gateway-william-store.apps.ocp4-grub.ocp.com/api/customer>

- Hystrix Dashboard: <http://hystrix-ui-william-store.apps.ocp4-grub.ocp.com/hystrix/>

- Turbine Stream on Hystrix Dashboard: <http://hystrix-ui-william-store.apps.ocp4-grub.ocp.com/hystrix/monitor?stream=http%3A%2F%2Fhystrix-ui%3A8080%2Fturbine.stream%3Fcluster%3Ddefault>



**Hystrix stream:**

- Turbine Stream: `http://hystrix-ui:8080/turbine.stream?cluster=default`

- Hystrix Stream (Customer): `http://customer:8080/actuator/hystrix.stream`

- Hystrix Stream (Preference): `http://preference:8080/actuator/hystrix.stream`

