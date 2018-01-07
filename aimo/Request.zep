namespace Aimo;
class Request {
    private static instance;
    public params   = [] {set,get};
    public isPost   = false;
    public isGet    = false;
    public isAjax   = false;
    public isPut    = false;
    public isDelete = false;
    public isMobile = false;

    /**
     * 实例化Request对象
     *
     * <code>
     * $request = Request::instance();
     * var_dump($request->isGet);
     * var_dump($request->isPost);
     * var_dump($request->isPut);
     * var_dump($request->isDelete);
     * var_dump($request->isAjax);
     * var_dump($request->isMobile);
     * </code>
     *
     * @param boolean adv 是否进行高级模式获取（有可能被伪装）
     * @return string | long
     */
    public function __construct()
    {
        let this->isGet    = this->getMethod() === "GET";
        let this->isPost   = this->getMethod() === "POST";
        let this->isPut    = this->getMethod() === "PUT";
        let this->isDelete = this->getMethod() === "DELETE";
        let this->isAjax   = strtoupper(isset _SERVER["HTTP_X_REQUESTED_WITH"] ? _SERVER["HTTP_X_REQUESTED_WITH"] : "") === "XMLHTTPREQUEST";
        let this->isMobile = !!preg_match("/android|iphone/i", _SERVER["HTTP_USER_AGENT"]);
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

}