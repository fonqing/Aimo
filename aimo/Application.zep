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

    protected _namespaces = [];

    protected _dirs = [];
    
    /**
     * @var array
     */
    public params = [] {set,get};
    
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
     * Initilize Application Instance
     *
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

    public function loadConfig(array config=[])-><Application>
    {
        let config["app_path"] = rtrim(config["app_path"],"\\/")."/";
        let this->_config = config;
        return this;
    }

    public function setRouter(string! name,callable func)-><Application>
    {
        let this->_routers[name]=func;
        return this;
    }

    public function registerNamespaces(array! namespaces)-><Application>
    {
        let this->_namespaces = namespaces;
        return this;
    }

    public function registerDir(array dirs= [])-><Application>
    {
        var dir;
        for dir in dirs {
            if is_dir(dir) {
                let this->_dirs[]=dir;
            }
        }
        return this;
    }

    public function autoload(klassName)
    {
        var klassFile = str_replace("\\","/", trim(klassName,"\\/"));
        let klassFile.=".php";
        if file_exists(klassFile) {
            require klassFile;
            return true;
        }
        var dir;
        for dir in this->_dirs {
            let dir = rtrim(dir,"\\/")."/";
            let klassFile = dir.klassFile;
            if file_exists(klassFile) {
                require klassFile;
                return true;
            }
        }
        /**
         * app\\controller => APP_PATH."controller"
         */
        var prefix,path,len;
        for prefix,path in this->_namespaces {
            let len = strlen(prefix);
            let path = rtrim(path,"\\/")."\\";
            if substr(klassName,0,len) == prefix {
                let klassFile = path.trim(substr(klassFile,len),"\\/").".php";
                if file_exists(klassFile) {
                    require klassFile;
                    return true;
                }
            }
        }
        throw "Can't locate class:".klassName;
    }

    public function route(string name="default")
    {
        if name == "default" {
            var pathinfo,tmp,key;
            array params   = [];
            var moduleName = "index",
                controllerName ="index",
                actionName = "index";
            let pathinfo   = trim(isset _SERVER["PATH_INFO"] ? _SERVER["PATH_INFO"] : "", "\\/");
            if empty pathinfo {
                let pathinfo = isset _GET["_url_"] ? _GET["_url_"] : "";
            }
            if !empty pathinfo {
                let tmp    = explode("/", pathinfo);
                int offset = 3,t;
                if this->_config["multipleModule"] {
                    if isset(tmp[0]) {
                        let moduleName = preg_replace("/[^0-9a-z_\-\.]+/i","",tmp[0]);
                    }
                    if isset(tmp[1]) {
                        let controllerName = preg_replace("/[^0-9a-z_\-\.]+/i","",tmp[1]);
                    }
                    if isset(tmp[2]) {
                        let actionName = preg_replace("/[^0-9a-z_\-\.]+/i","",tmp[2]);
                    }
                } else {
                    if isset(tmp[0]) {
                        let controllerName = preg_replace("/[^0-9a-z_\-\.]+/i","",tmp[0]);
                    }
                    if isset(tmp[1]) {
                        let actionName = preg_replace("/[^0-9a-z_\-\.]+/i","",tmp[1]);
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
            }
            return [
                "moduleName":moduleName,
                "controllerName":controllerName,
                "actionName":actionName,
                "params":params
            ];

        } else {

            if !isset this->_routers[name] {
                throw "Router dose not exists";
            }
            if !is_callable(this->_routers[name]) {
                throw "Router is invalid";
            }
            var res;
            let res = call_user_func(this->_routers[name]);
            if typeof res != "array" {
                throw "Router must return an array";
            }
            if isset res["moduleName"] && 
                isset res["controllerName"] && 
                isset res["actionName"] && 
                isset res["params"] {
                return res;
            }else{
                throw "Router must return an array";
            }
        }

    }
    /**
     * Bootstrap method 
     *
     * @return void
     */
    public function run()->void
    {
        //spl_autoload_register([this,"autoload"]);
        var routerResult;
        let routerResult = this->route();
        if typeof routerResult != "array" {
            throw "Router dispacher Error";
        }
        if isset routerResult["moduleName"] {
            let this->moduleName = routerResult["moduleName"];
        }
        if isset routerResult["controllerName"] {
            let this->controllerName = routerResult["controllerName"];
        }
        if isset routerResult["actionName"] {
            let this->actionName = routerResult["actionName"];
        }
        if isset routerResult["params"] {
            let this->params = routerResult["params"];
        }
        var controllerPath,controller,controllerName,controllerClass,actionMethod;
        let controllerName = ucfirst(this->controllerName)."Controller";
        if this->_config["multipleModule"] {
            let controllerPath = this->_config["app_path"].strtolower(this->moduleName)."/controller/";
        }else{
            let controllerPath = this->_config["app_path"]."controller/";
        }
        let controllerClass = controllerPath.controllerName.".php";
        let actionMethod = this->actionName."Action";
        if file_exists (controllerClass) {
            require controllerClass;
            let controller = new {controllerName}();
            if method_exists(controller,"setup") {
                call_user_func([controller,"setup"]);
            }
            if method_exists(controller,"init") {
                call_user_func([controller,"init"]);
            }
            if method_exists(controller,actionMethod) {
                call_user_func([controller,actionMethod]);
            } elseif (method_exists(controller,"_empty")) {
                call_user_func([controller,"_empty"]);
            } else {
                die("404");
            }
        } else {
            let controllerClass = controllerPath."ErrorController.php";
            let controllerName = "ErrorController";
            if file_exists (controllerClass) {
                require controllerClass;
                let controller = new {controllerName}();
                if method_exists(controller,actionMethod) {
                    call_user_func([controller,actionMethod]);
                } elseif (method_exists(controller,"_empty")) {
                    call_user_func([controller,"_empty"]);
                } else {
                    die("404");
                }
            }
        }
        
        Request::instance()->setParams(array_merge(this->params, _REQUEST));
        View::init(Config::get("view"));
    }
}
