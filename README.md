# Aimo Framework
使用Zephir实现的超轻量级PHP框架扩展。
### 说明
dll目录目前只编译了PHP7.0版本，
框架正在编写阶段....
### 运行环境
* PHP = 7.0

## 使用指引
[Documention](https://fonqing.github.io/Aimo/)
### 程序架构
常见并推荐的目录结构如下：
```
- .htaccess // Rewrite rules for Apache
+ public //应用WEB根目录
  | - index.php // 应用入口
  | + css
  | + js
  | + img
+ config
  | - config.php // 配置文件
+ controller
  | - Index.php // 默认控制器
+ model
  | - User.php // 模型
+ view    
  | - index   
     | - index.html //模板文件
+ runtime //缓存目录
+ vendor
  ... 其他自定义目录
```
### WEB根目录
绑定上面目录结构的`public`目录.

### index.php
`index.php` 入口文件代码大致如下：

```php
<?php
use Aimo\Application;
use Aimo\Config;
define('APP_PATH', rtrim(realpath(__DIR__."/../"),"\\/")."/");
require(APP_PATH . 'config/config.php');
Application::init(Config::get('application'))->run();
```
### Rewrite rules

Aimo框架重写支持
index.php/module/controller/action/param/value/param1/value1.html //包含URL后缀    

index.php?\_url\_=/module/controller/action/param/value/param1/value1.html //包含URL后缀

### config.php
`config.php` 包含应用全部组件配置
```php
<?php
use Aimo\Config;
Config::init([
    'application' => [
        'timezone'        => 'Asia/Shanghai',//时区设置
        'debug'           => true,     //调试模式
        'app_path'        => APP_PATH, //应用根目录
        'namespace'       => 'app',    //应用命名空间前缀
        'multiple_module' => false,    //多模块支持
        'url_suffix'      => '.html'   //URL地址后缀
    ],
    'namespaces' => [
        'app' => APP_PATH,             //命名空间注册
    ],
    //数据库连接配置
    'db' => [
        'dsn'  => 'mysql:host=localhost;dbname=database',
        'username'  => 'username',
        'password'  => 'password',
        'prefix'    => 'pre_',
        'identifier_case' => 'lower',//表名字段大小写状态 default,lower,upper
        'options'   => [
            \PDO::MYSQL_ATTR_INIT_COMMAND => 'SET NAMES utf8'
        ]
    ],
    //默认缓存配置
    'cache' => [
        'cache_path'=> APP_PATH.'runtime/cache/data/',
    ],
    //视图配置
    'view' => [
        'view_path' => APP_PATH.'view/',
        'view_cache_path' => APP_PATH.'runtime/cache/tpl/',
        'view_file_ext' => 'html'
    ]
]);
```
### 默认控制器
默认控制器 `IndexController`:

```php
<?php
namespace app\controller;
use Aimo\Controller;
use Aimo\View;
class IndexController extends Controller {
    public function indexAction()
    {
        View::assign('list',['a','b','c']);
        View::assign('number',6);
        View::render('index/index',['data' => 'hello world']);
        //Or you can render like bellow line;
        //Attention: The View in Controller has only one method "render"
        $this->render('index/index',[
          'list'   => ['a','b','c'],
          'number' => 6,
          'data'   => 'hello world'
        ]);
    }
}
```

### 视图脚本

模板代码如下：

```html
<!doctype html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Aimo Hello World</title>
</head>
<body>
{$data}
<ul>
  {loop $list $v}
  <li>{$n}:{$v}</li>
  {/loop}
</ul>
{var_dump($number)}
{$number++}
</body>
</html>
```
