# XMNStatistical
> 统计用户事件类库,将记录的event事件先写入sqlite数据库内

-----


###1. 功能

* 统计自定义的事件
* 统计崩溃日志信息
* 使用sqlite保存数据
* 可以上传服务器,可以选择是否使用GZIP压缩上传
* 查询统计事件,支持简单的sqlite查询条件

###2. 使用

####2.1初始化 
`[XMNStatistic setupServerURLString:@"http://127.0.0.1:8888/log?" channel:@"AppStore"];`
####2.2 记录普通事件

`[XMNStatistic event:@"button click" value:NSStringFromClass([self class])];`

####2.3 记录带有参数的事件
`[XMNStatistic event:@"button click" value:NSStringFromClass([self class]) params:@{@"detail info":LINE_INFO(@"this is detail info")}];`

####2.4 获取记录的事件
`[XMNStatistic getStatisticWithType:XMNStatisticEvent withCondition:@"order by id desc"];`


####2.5 上传至服务器
`[XMNStatistic uploadStatisticWithType:XMNStatisticAll UsingGZIP:YES];`