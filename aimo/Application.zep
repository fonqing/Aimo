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
    
    /**
     * @var array Request params
     */
    public params = [] {set,get};
    
    /**
     * @var string Module name
     */
    public moduleName = "index" {set,get};
    
    /**
     * @var string Controller name
     */
    public controllerName = "index" {set,get};
    
    /**
     * @var string Action name
     */
    public actionName = "index" {set,get};

    /**
     * Initilize Application Instance
     *
     * @return <Application>
     */
    public static function init()-><Application>
    {
        if self::_instance === null {
            let self::_instance = new self();
        }
        return self::_instance;
    }
    /**
     * Bootstrap method 
     *
     * @param bool multipleModule
     * @return void
     */
    public function run(boolean multipleModule = false)->void
    {
        var pathinfo,tmp,key;
        array params   = [];
        let pathinfo   = trim(_SERVER["PATH_INFO"], "\\/");
        if !empty pathinfo {
            let tmp    = explode("/", pathinfo);
            int offset = 3,t;
            if multipleModule {
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
        }
        let this->params = params;
        Request::instance()->setParams(array_merge(this->params, _REQUEST));
        View::init([]);
    }
}
