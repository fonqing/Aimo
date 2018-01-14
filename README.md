# Aimo Framework
A lightweight PHP framework written in Zephir and build as C-extension.
### Why
Phalcon is powerfull and flexible,But the Volt is a stereotyped View Engine.Some times,when you wan't call customer functions in view file is soooooooo hard.   
Yaf is too shabby.There is NO ORM and also NO DB layer,And the View Engine is too shabby too.   
Now, In the dll directory,There are only dll extensions for php 7.0.   
The framework is being written, please wait for the release...

### Runtime Requirements
* PHP = 7.0
* openssl extension
* PDO extension

## Usage
[Documention](https://fonqing.github.io/Aimo/)
### Application structure
Recommended directory structure is as follows：
```
- .htaccess // Rewrite rules for Apache
+ public //Application WEB ROOT
  | - index.php // Application Entrance
  | + css
  | + js
  | + img
+ config
  | - config.php // 
+ controller
  | - Index.php //  Controller
+ model
  | - User.php // Model
+ view    
  | - index   
     | - index.html //View file
+ runtime //runtime cache etc.
+ vendor
  ... Other
```
### WEB ROOT
Bind the dir `public`.

### index.php 
`index.php` Code sample：

```php
<?php
use Aimo\Application;
use Aimo\Config;
define('APP_PATH', rtrim(realpath(__DIR__."/../"),"\\/")."/");
require(APP_PATH . 'config/config.php');
Application::init(Config::get('application'))->run();
```
### Rewrite rules

Implement your Rewrite rules for you web server    
index.php/module/controller/action/param/value/param1/value1.html //With URL suffix    

index.php?\_url\_=/module/controller/action/param/value/param1/value1.html //With URL suffix   

### config.php
All configuration items in `config.php` .
```php
<?php
use Aimo\Config;
Config::init([
    'application' => [
        'timezone'        => 'Asia/Shanghai',//时区设置
        'app_path'        => APP_PATH, //应用根目录
        'namespace'       => 'app',    //应用命名空间前缀
        'multiple_module' => false,    //多模块支持
        'url_suffix'      => '.html'   //URL地址后缀
        'debug'           => true,     //开启调试模式
        'error_log'       => APP_PATH.'runtime/log/php_error.log',//指定脚本错误日志文件
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
    ],
    //事件响应配置(钩子)
    'events' => [
        'app_init'        => "app\\event\\Handler::onAppInit",
        'before_dispatch' => '',
        'after_dispatch'  => '',
        'before_notfound' => '',
        'controller_init' => '',
        'view_init'       => '',
        'before_render'   => '',
        'after_render'    => '',
    ]
]);
```
### Default controller
Default controller  `IndexController`:

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
        $this->assign('name','eric');
        $this->render('index/index',[
          'list'   => ['a','b','c'],
          'number' => 6,
          'data'   => 'hello world'
        ]);
    }
}
```

### View

Sample code：

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
