[TOC]

# BookInfo Example



## References



- [Istio BookInfo application example](https://istio.io/latest/docs/examples/bookinfo/)

- [OpenShift Service Mesh BookInfo example application](https://access.redhat.com/documentation/en-us/openshift_container_platform/4.6/html/service_mesh/service-mesh-2-x#ossm-tutorial-bookinfo-overview_deploying-applications-ossm)

- <https://istio.io/latest/docs/reference/config/networking/>

- <https://github.com/Maistra/istio>

  



## Install



```bash
# create a new project
oc new-project bookinfo

# Add "bookinfo" project in ServiceMessMemberRoll

# Deploy application
oc apply -f bookinfo.yaml

# Configure Istio config
oc apply -f bookinfo-gateway.yaml
oc apply -f destination-rule-all.yaml

```



配置hosts文件。



访问：

- <http://bookinfo.com/productpage>







查看Istio配置：

```bash
# OpenShift auto create route for Istio ingress gateway
oc get route -n istio-system | grep istio-ingressgateway

# Check created Istio config
oc get gateway
oc get virtualservice
oc get destinationrule
```





## bookinfo



![Bookinfo Application without Istio](https://istio.io/latest/docs/examples/bookinfo/noistio.svg)





调用链：

- productpage -> reviews -> ratings
- productpage -> details



Reviews服务有3个版本：

* V1: 没有星号评级
* V2: 黑色星号评级
* V3: 红色星号评级



在浏览器上刷新，可以看到不同版本。

DestinationRule默认的负载均衡方式是"轮询"(Round Robin)。



## Istio功能测试

参见：

- <https://github.com/maistra/istio/tree/maistra-2.0/samples/bookinfo/networking>
- <https://access.redhat.com/documentation/en-us/openshift_container_platform/4.6/html/service_mesh/service-mesh-2-x#ossm-routing-bookinfo_routing-traffic>





### Kiali

在Developer / Typology中打开Kiali。

或

```bash
oc get route -n istio-system | grep kiali
```



在Kiali上，查看服务网络图和验证Istio配置。

用JMeter来模拟用户并发访问：<http://bookinfo.com/productpage> 。



在Kiali Graph上：

- 勾选Traffic Animation显示流量动画效果
- 勾选Service Nodes显示OpenShift Service节点在Kiali Graph上
- 勾选Request Percentage显示每条路由的流量百分比



### Jaeger

在Kiali上打开Distibuted Tracing，来打开Jaeger。

或

```bash
oc get route -n istio-system | grep jaeger
```



选择 `productpage.bookinfo`服务，来查看服务跟踪信息和服务调用链信息。





## Istio路由测试



参见：

- <https://github.com/maistra/istio/tree/maistra-2.0/samples/bookinfo/networking>
- <https://access.redhat.com/documentation/en-us/openshift_container_platform/4.6/html/service_mesh/service-mesh-2-x#ossm-routing-bookinfo_routing-traffic>



### 只分发流量到v1



```bash
oc apply -f virtual-service-all-v1.yaml
```



VirtualService 中只配置了`v1` 的subset。



用JMeter测试。

发现流量全部流转到V1，不会有流量流到reviews的v2和v3。



### 根据http header分发流量



```bash
oc apply -f virtual-service-reviews-test-v2.yaml 
```



在浏览器中访问 <http://bookinfo.com/productpage> ， signin，输入用户名为jason。

无论怎么刷新，都只会访问reviews v2（黑色星号评级）。



这是因为productpage模块的代码，从session中取得了`user`，然后再设置到HTTP header的`end-user`中。

Productpage.py

```python
# x-b3-*** headers can be populated using the opentracing span

# We handle other (non x-b3-***) headers manually
    if 'user' in session:
        headers['end-user'] = session['user']
```





但是为什么在浏览器的F12看不到`end-user`这个头 ？

Productpage 向reviews发送http请求时，才加上http header，所以浏览器上看不到。

























