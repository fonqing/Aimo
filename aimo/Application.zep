namespace Aimo;
/**
 * Application class
 *
 * Bootstrap class
 * @package Aimo
 * @copyright Aimosoft Studio 2017
 * @author <Eric,fonqing@gmail.com>
 */
class Application {
    
    /**
     * @var <\Aimo\Application> 
     */
    protected static _instance;

    protected _config  = [];

    protected _routers = [];
    /**
     * @var array
     */
    public params = [] {set,get};

    /**
     * @var boolean
     */
    public multipleModule = false;
    
    /**
     * @var string
     */
    public moduleName = "index" {set,get};
    
    /**
     * @var string
     */
    public controllerName = "index" {set,get};
    
    /**
     * @var string
     */
    public actionName = "index" {set,get};

    /**
     * 初始化应用
     *
     *<code>
     *use Aimo\Application;
     *Application::init(Config::get('app'))->run();
     *</code>
     * @return <Application>
     */
    public static function init(array! config)-><Application>
    {
        if self::_instance === null {
            let self::_instance = new self();
            self::_instance->loadConfig(config);
        }
        return self::_instance;
    }

    /**
     * 载入应用配置
     *
     *<code>
     *use Aimo\Application;
     *Application::init(Config::get('app'))->loadConfig(Config::get('otherConfig'))->run();
     *</code>
     * @return <Application>
     */
    public function loadConfig(array config=[])-><Application>
    {
        let config["app_path"] = rtrim(config["app_path"],"\\/")."/";
        let this->_config = config;
        if isset this->_config["multipleModule"] && this->_config["multipleModule"]===true {
            let this->multipleModule = true;
        } 
        return this;
    }

    /**
     * 委托路由解析回调
     *
     *<code>
     *use Aimo\Application;
     *Application::init(Config::get('app'))->setRouter(function($pathinfo){
     *    //your code here
     *    //must return
     *    return [
     *        'moduleName'=>'',
     *        'controllerName'=>'',
     *        'actionName'=>'',
     *        'params'=> array_merge($_GET,$_POST),
     *    ]; 
     *})->run();
     *</code>
     * @return <Application>
     */
    public function setRouter(string! name,callable func)-><Application>
    {
        let this->_routers[name]=func;
        return this;
    }

    public function route(string name="default")
    {
        var pathinfo,url_suffix,len;
        let url_suffix = isset this->_config["url_suffix"] ? this->_config["url_suffix"] : "";
        let len = strlen(url_suffix);
        let pathinfo   = isset _SERVER["PATH_INFO"] ? _SERVER["PATH_INFO"] : "";
        if empty pathinfo {
            let pathinfo = isset _GET["_url_"] ? _GET["_url_"] : "";
        }
        if !empty url_suffix && substr(pathinfo, 0-len) == url_suffix {
            let pathinfo = substr(pathinfo, 0, 0-len);
        }
        if name == "default" {
            var tmp,key;
            array params   = [];
            let pathinfo = trim(pathinfo, "\\/");
            if !empty pathinfo {
                let tmp    = explode('/', pathinfo);
                int offset = 3,t;
                if this->multipleModule {
                    if isset(tmp[0]) {
                        let this->moduleName = preg_replace("/[^0-9a-z_\-\.]+/i","",tmp[0]);
                    }
                    if isset(tmp[1]) {
                        let this->controllerName = preg_replace("/[^0-9a-z_\-\.]+/i","",tmp[1]);
                    }
                    if isset(tmp[2]) {
                        let this->actionName = preg_replace("/[^0-9a-z_\-\.]+/i","",tmp[2]);
                    }
                } else {
                    if isset(tmp[0]) {
                        let this->controllerName = preg_replace("/[^0-9a-z_\-\.]+/i","",tmp[0]);
                    }
                    if isset(tmp[1]) {
                        let this->actionName = preg_replace("/[^0-9a-z_\-\.]+/i","",tmp[1]);
                    }
                    let offset = 2;
                }
                while isset tmp[offset] {
                    let key = htmlspecialchars(tmp[offset]);
                    let t   = offset + 1;
                    if !isset tmp[t] {
                        break;
                    }
                    let params[key] = htmlspecialchars(tmp[t]);
                    let offset = offset + 2;
                }
                let this->params = params;
            }
            
        } else {
            if !isset this->_routers[name] {
                throw "Router dose not exists";
            }
            if !is_callable(this->_routers[name]) {
                throw "Router is invalid";
            }
            var res;
            let res = call_user_func(this->_routers[name],pathinfo);
            if typeof res != "array" {
                throw "Router must return an array";
            }
            if isset res["moduleName"] && 
                isset res["controllerName"] && 
                isset res["actionName"] && 
                isset res["params"] {
                let this->moduleName = preg_replace("/[^0-9a-z_\-\.]+/i","",res["moduleName"]);
                let this->controllerName = preg_replace("/[^0-9a-z_\-\.]+/i","",res["controllerName"]);
                let this->actionName = preg_replace("/[^0-9a-z_\-\.]+/i","",res["actionName"]);
                let this->params = res["params"];
            }else{
                throw "Router must return an array";
            }
        }

    }

    /**
     * 调度
     */
    private function dispacher()
    {
        var klass,ctl,action;
        let klass = this->getController(this->controllerName);
        if class_exists(klass) {
            let ctl = new {klass}();
            let action = this->actionName."Action";
            if method_exists(ctl, action) && is_callable([ctl,action]) {
                call_user_func([ctl,action]);
            } else {
                let action = "_empty";
                if method_exists(ctl, action) && is_callable([ctl,action]) {
                    call_user_func([ctl,action]);
                }else{
                    Controller::notFound();
                }
            }
        } else {
            let klass = this->getController("Error");
            if class_exists(klass) {
                let ctl = new {klass}();
                let action = this->actionName."Action";
                if method_exists(ctl, action) && is_callable([ctl,action]) {
                    call_user_func([ctl,action]);
                } else {
                    let action = "_empty";
                    if method_exists(ctl, action) && is_callable([ctl,action]) {
                        call_user_func([ctl,action]);
                    }else{
                        Controller::notFound();
                    }
                }
            } else {
                Controller::notFound();
            }
        }
    }

    /**
     * 获取控制器
     *
     * @return sting
     */
    private function getController(string! ctl)
    {
        var controllerName,klass,name;
        let name = this->_config["namespace"];
        let controllerName = ctl."Controller";
        if this->multipleModule {
            let klass = name."\\controller\\".this->moduleName."\\".controllerName;
        } else {
            let klass = name."\\controller\\".controllerName;
        }
        return klass;
    }

    /**
     * 启动运行 
     *
     * @return void
     */
    public function run()->void
    {
        var timezone;
        let timezone = isset this->_config["timezone"] ? this->_config["timezone"] : "Asia/Shanghai";
        date_default_timezone_set(timezone);
        if isset this->_config["debug"] && this->_config["debug"] === true {
            error_reporting(E_ALL);
            ini_set("display_errors","On");
        }else{
            error_reporting(0);
            ini_set("display_errors","off");
        }
        Loader::addNamespaces(Config::get("namespaces"));
        spl_autoload_register("Aimo\\Loader::autoload");
        this->route();
        this->dispacher();
        Request::instance()->setParams(array_merge(this->params, _REQUEST));
    }
}
