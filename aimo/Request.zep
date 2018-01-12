namespace Aimo;
class Request {
    private static instance;
    public params = [] {set,get};
    /**
     * 实例化Request对象
     *
     * <code>
     * $request = Request::instance();
     * var_dump($request->isPost());
     * var_dump($request->isPut());
     * var_dump($request->isDelete());
     * var_dump($request->isAjax());
     * var_dump($request->isMobile());
     * </code>
     *
     * @param boolean adv 是否进行高级模式获取（有可能被伪装）
     * @return string | long
     */
    public function __construct()
    {
    }

    /**
     * 单例模式
     *
     * <code>
     * $request = Request::instance();
     * var_dump($request);
     * </code>
     *
     * @return Aimo\Request
     */
    public static function instance() -> <Request>
    {
        if self::instance === null {
            let self::instance = new self();
        }
        return self::instance;
    }

    /**
     * 判断请求类型模式
     *
     * <code>
     * $request = Request::instance();
     * var_dump($request->isPost());
     * </code>
     *
     * @return boolean
     */
    public function isPost()->boolean
    {
        return this->getMethod()==="POST";
    }

    /**
     * 判断请求类型模式
     *
     * <code>
     * $request = Request::instance();
     * var_dump($request->isPut());
     * </code>
     *
     * @return boolean
     */
    public function isPut()->boolean
    {
        return this->getMethod()==="PUT";
    }

    /**
     * 判断请求类型模式
     *
     * <code>
     * $request = Request::instance();
     * var_dump($request->isDelete());
     * </code>
     *
     * @return boolean
     */
    public function isDelete()->boolean
    {
        return this->getMethod()==="DELETE";
    }

    /**
     * 简单判断是否手机访问
     *
     * <code>
     * $request = Request::instance();
     * var_dump($request->isMobile());
     * </code>
     *
     * @return boolean
     */
    public function isMobile()->boolean
    {
        return !!preg_match("/android|iphone/i", _SERVER["HTTP_USER_AGENT"]);
    }

    /**
     * 判断是否Ajax请求
     *
     * <code>
     * $request = Request::instance();
     * var_dump($request->isAjax());
     * </code>
     *
     * @return boolean
     */
    public function isAjax()->boolean
    {
        return strtoupper(isset _SERVER["HTTP_X_REQUESTED_WITH"] ? _SERVER["HTTP_X_REQUESTED_WITH"] : "") === "XMLHTTPREQUEST";
    }

    /**
     * 获取GET数据
     *
     * <code>
     * $request = Request::instance();
     * var_dump($request->get('page',1,'int'));
     * var_dump($request->get('email','','email'));
     * var_dump($request->get('url','','url'));
     * var_dump($request->get('float',0.0,'float'));
     * var_dump($request->get('chars','','alpha'));//a-zA-Z
     * var_dump($request->get('aphnum','','alphanum'));//a-zA-Z0-9
     * </code>
     *
     * @param string name 索引名
     * @param mixed def  默认值
     * @param mixed filter 过滤器
     * @return mixed
     */
    public function get(string! name,var def=null,var filter="text")
    {
        if !isset _GET[name] {
            return def;
        }
        if empty filter {
            return isset _GET[name] ? _GET[name] : def;
        }
        var method;
        let method = "f_".filter;
        if method_exists(this, method){
            return (typeof _GET[name] == "array") ?
                array_map([this, method], _GET[name]) :
                this->{method}(_GET[name]);
        } elseif function_exists(filter) {
            return (typeof _GET[name] == "array") ?
                array_map(filter, _GET[name]) : {filter}(_GET[name]);
        }
    }

    /**
     * 获取POST数据
     *
     * <code>
     * $request = Request::instance();
     * var_dump($request->post('page',1,'int'));
     * var_dump($request->post('email','','email'));
     * var_dump($request->post('url','','url'));
     * var_dump($request->post('float',0.0,'float'));
     * var_dump($request->post('chars','','alpha'));//a-zA-Z
     * var_dump($request->post('aphnum','','alphanum'));//a-zA-Z0-9
     * </code>
     *
     * @param string name 索引名
     * @param mixed def  默认值
     * @param mixed filter 过滤器
     * @return mixed
     */
    public function post(string! name,var def=null,var filter="text")
    {
        if !isset _POST[name] {
            return def;
        }
        if empty filter {
            return isset _POST[name] ? _POST[name] : def;
        }
        var method;
        let method = "f_".filter;
        if method_exists(this, method){
            return (typeof _POST[name] == "array") ?
                array_map([this, method], _POST[name]) :
                this->{method}(_POST[name]);
        } elseif function_exists(filter) {
            return (typeof _POST[name] == "array") ?
                array_map(filter, _POST[name]) : {filter}(_POST[name]);
        }
    }

    /**
     * 获取REQUEST以及URL中的数据数据
     *
     * <code>
     * $request = Request::instance();
     * var_dump($request->param('page',1,'int'));
     * var_dump($request->param('email','','email'));
     * var_dump($request->param('url','','url'));
     * var_dump($request->param('float',0.0,'float'));
     * var_dump($request->param('chars','','alpha'));//a-zA-Z
     * var_dump($request->param('aphnum','','alphanum'));//a-zA-Z0-9
     * </code>
     *
     * @param string name 索引名
     * @param mixed def  默认值
     * @param mixed filter 过滤器
     * @return mixed
     */
    public function param(string! name,var def=null,var filter="text")
    {
        var params;
        let params = Request::instance()->getParams();
        if !isset params[name] {
            return def;
        }
        if empty filter {
            return isset params[name] ? params[name] : def;
        }

        var method;
        let method = "f_".filter;
        if method_exists(this, method){
            return (typeof params[name] == "array") ?
                array_map([this, method], params[name]) :
                this->{method}(params[name]);
        } elseif function_exists(filter) {
            return (typeof params[name] == "array") ?
                array_map(filter, params[name]) : {filter}(params[name]);
        }
    }

    /**
     * 判断是否有上传的文件
     *
     * <code>
     * $request = Request::instance();
     * var_dump($request->hasFiles());
     * </code>
     *
     * @return boolean
     */
    public function hasFiles(string key="") -> boolean
    {
        if empty _FILES {
            return false;
        }
        if !isset _FILES[key] {
            return false;
        }
        if empty _FILES[key] {
            return false;
        }
        return true;
    }

    /**
     * 获取上传的文件
     *
     * <code>
     * $request = Request::instance();
     * if($request->hasFiles(){
     *     try {
     *        $request->savefile('formvar','./path/',2048000,'doc,docx,xls,xlsx');
     *     } catch (\Exception $e) {
     *        echo $e->getMessage();
     *     }
     * }
     * </code>
     *
     * @param string name 索引名
     * @param mixed def  默认值
     * @param mixed filter 过滤器
     * @return mixed
     */
    public function files()
    {

    }

    /**
     * Gets HTTP method which request has been made
     *
     * If the X-HTTP-Method-Override header is set, and if the method is a POST,
     * then it is used to determine the "real" intended HTTP method.
     *
     * The _method request parameter can also be used to determine the HTTP method,
     * but only if setHttpMethodParameterOverride(true) has been called.
     *
     * The method is always an uppercased string.
     */
    public final function getMethod() -> string
    {
        var overridedMethod, requestMethod;
        string returnMethod = "";

        if likely fetch requestMethod, _SERVER["REQUEST_METHOD"] {
            let returnMethod = strtoupper(requestMethod);
        } else {
            return "GET";
        }

        if "POST" === returnMethod {
            let overridedMethod = this->getHeader("X-HTTP-METHOD-OVERRIDE");
            if !empty overridedMethod {
                let returnMethod = strtoupper(overridedMethod);
            }
        }

        if !this->isValidHttpMethod(returnMethod) {
            return "GET";
        }

        return returnMethod;
    }

    /**
     * Checks if a method is a valid HTTP method
     */
    public function isValidHttpMethod(string method) -> boolean
    {
        switch strtoupper(method) {
            case "GET":
            case "POST":
            case "PUT":
            case "DELETE":
            case "HEAD":
            case "OPTIONS":
            case "PATCH":
            case "PURGE":
            case "TRACE":
            case "CONNECT":
                return true;
        }
        return false;
    }

    /**
     * Gets HTTP header from request data
     */
    public final function getHeader(string! header) -> string
    {
        var value, name;

        let name = strtoupper(strtr(header, "-", "_"));

        if fetch value, _SERVER[name] {
            return value;
        }

        if fetch value, _SERVER["HTTP_" . name] {
            return value;
        }

        return "";
    }


    /**
     * 获取客户端IP地址
     *
     * <code>
     * $ip = Request::instance()->ip();
     * var_dump($ip);
     * </code>
     *
     * @param boolean adv 是否进行高级模式获取（有可能被伪装）
     * @return string | long
     */
    public function ip(boolean adv = false) -> string
    {
        var arr, pos,ip;
        if adv {
            if isset _SERVER["HTTP_X_FORWARDED_FOR"]  {
                let arr = explode(",", _SERVER["HTTP_X_FORWARDED_FOR"]);
                let pos = array_search("unknown", arr);
                if false !== pos {
                    unset arr[pos] ;
                }
                let ip = trim(current(arr));
            } elseif isset _SERVER["HTTP_CLIENT_IP"]  {
                let ip = _SERVER["HTTP_CLIENT_IP"];
            } elseif isset _SERVER["REMOTE_ADDR"] {
                let ip = _SERVER["REMOTE_ADDR"];
            }
        } elseif isset _SERVER["REMOTE_ADDR"] {
            let ip = _SERVER["REMOTE_ADDR"];
        }
        return (string) ip;
    }

    /**
     * Data filters
     */
    public function f_text(var str)
    {
        return filter_var(str, FILTER_SANITIZE_SPECIAL_CHARS);
    }

    public function f_int(var val)
    {
        return filter_var(val, FILTER_SANITIZE_NUMBER_INT);
    }

    public function f_float(var val)
    {
        return filter_var(val, FILTER_SANITIZE_NUMBER_FLOAT);
    }

    public function f_url(var val)
    {
        return filter_var(val, FILTER_SANITIZE_URL);
    }

    public function f_email(var val)
    {
        return filter_var(val, FILTER_SANITIZE_EMAIL);
    }

    public function f_alpha(var str)
    {
        return preg_replace("/[^a-z]+/i", "", str);
    }

    public function f_alphanum(var str)
    {
        return preg_replace("/[^a-z0-9]+/i", "", str);
    }

    public function f_number(var str)
    {
        return preg_replace("/[^0-9\.\-\+]+/i", "", str);
    }

}
