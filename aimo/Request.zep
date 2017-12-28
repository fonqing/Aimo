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
        let this->isGet    = strtoupper(_SERVER["REQUEST_METHOD"]) === "GET";
        let this->isPost   = strtoupper(_SERVER["REQUEST_METHOD"]) === "POST";
        let this->isPut    = strtoupper(_SERVER["REQUEST_METHOD"]) === "PUT";
        let this->isDelete = strtoupper(_SERVER["REQUEST_METHOD"]) === "DELETE";
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
            if isset(_SERVER["HTTP_X_FORWARDED_FOR"]) {
                let arr = explode(",", _SERVER["HTTP_X_FORWARDED_FOR"]);
                let pos = array_search("unknown", arr);
                if false !== pos {
                    unset(arr[pos]);
                }
                let ip = trim(current(arr));
            } elseif isset(_SERVER["HTTP_CLIENT_IP"]) {
                let ip = _SERVER["HTTP_CLIENT_IP"];
            } elseif isset(_SERVER["REMOTE_ADDR"]) {
                let ip = _SERVER["REMOTE_ADDR"];
            }
        } elseif isset(_SERVER["REMOTE_ADDR"]) {
            let ip = _SERVER["REMOTE_ADDR"];
        }
        return ip;
    }

}