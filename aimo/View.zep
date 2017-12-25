namespace Aimo;
/**
 * 视图类
 *
 * 包含模板语法与编译，视图模板缓存
 *
 * @package Aimo
 * @use Aimo\Config;
 * @author Eric,<wangyinglei@yeah.net>
 */
class View {
    /**
     * @var array 配置
     */
    private static _config;

    /**
     * @var string Taglib namespace
     */
    public static _namespace = "Aimo";

    /**
     * @var array 待解析变量
     */
    private static _data;

    /**
     * 引擎初始化
     *
     * @access public
     * @param array config 视图配置
     *
     * <code>
     * \Aimo\View::init([
     *      'view_path'=>'./_view/',
     *      'view_cache_path'=>'./_cache/',
     *      'view_file_ext'=>'.html'
     * ]);
     * </code>
     */
    public static function init(array config) -> void
    {
        let self::_config = config;
    }


    /**
     * 检查模板状态
     *
     * @access private
     * @param string tpl 视图文件路径
     * @param string cache 编译后的视图缓存路径
     * @return boolean
     */
    private static function check(string tpl,string cache) -> boolean
    {
        if !file_exists(cache) {
            return false;
        }
        if filemtime(tpl) > filemtime(cache) {
            return false;
        }else{
            return true;
        }
    }

    /**
     * 载入视图文件
     *
     * 载入视图后编译缓存，返回缓存文件路径
     *
     * @access public
     * @param string mca 视图描述
     * @return string

     * <code>
     * \Aimo\View::load('news/view');//默认module/controller/action
     * \Aimo\View::load('admin/news/view');//module/controller/action
     * </code>
     */
    public static function load(string mca) -> string
    {
        string viewPath,cachePath,viewExt,tplfile,compiledtplfile,tmp,content;
        var tmpa;
        int c;
        var defaultModule;

        let viewPath  = rtrim(self::_config["view_path"], "/\\");
        let cachePath = rtrim(self::_config["view_cache_path"], "/\\");
        let viewExt   = trim( self::_config["view_file_ext"], '.');
        let defaultModule = Config::get("default_module");
        let mca = trim(mca,"\\/");

        
        let tmpa      = explode("/", str_replace(["\\","/"],"/",mca));
        let c = count(tmpa);
        if c==3 {
            let tmp = implode("_", tmpa);
            let tplfile   = viewPath ."/". mca . "." . viewExt;
        } elseif c==2 {
            let tmp = defaultModule."_".implode("_", tmpa);
            let tplfile   = viewPath ."/".defaultModule."/". mca . "." . viewExt;
        } else{
            throw new \Exception("Error template params", 1);
        }
        let compiledtplfile = cachePath."/".tmp.".php";
        
        if self::check(tplfile, compiledtplfile) {
            return compiledtplfile;
        }
        
        if !file_exists(tplfile) {
            throw new \Exception("View file ".htmlspecialchars(tplfile)." dose't exists", 1);
        }

        let content = file_get_contents(tplfile);
        
        if !is_dir(cachePath) {
            mkdir (cachePath, 0777, true);
        }
    
        let content = self::parse( content );

        file_put_contents(compiledtplfile, content);
        chmod(compiledtplfile, 0777);
        return compiledtplfile;
    }

    /**
     * 解析视图语法
     *
     * 解析视图语法
     *
     * @access private
     * @param string content 视图文件内容
     * @return string
     */
    private static function parse(string content) -> string
    {
        let content = preg_replace ( "/<template\s+(.+)>/", "<?php include \\Aimo\\View::load(\\1); ?>", content );
        let content = preg_replace ( "/<include\s+(.+)>/", "<?php include \\1; ?>", content );
        let content = preg_replace ( "/<php\s+(.+)>/", "<?php \\1?>", content );
        let content = preg_replace ( "/<if\s+(.+?)>/", "<?php if(\\1) { ?>", content );
        let content = preg_replace ( "/<else>/", "<?php } else { ?>", content );
        let content = preg_replace ( "/<elseif\s+(.+?)>/", "<?php } elseif (\\1) { ?>", content );
        let content = preg_replace ( "/<\/if>/", "<?php } ?>", content );
        let content = preg_replace ( "/<for\s+(.+?)>/", "<?php for(\\1) { ?>", content );
        let content = preg_replace ( "/<\/for>/", "<?php } ?>", content );
        let content = preg_replace ( "/<\+\+(.+?)>/", "<?php ++\\1; ?>", content );
        let content = preg_replace ( "/<\-\-(.+?)>/", "<?php ++\\1; ?>", content );
        let content = preg_replace ( "/<(.+?)\+\+>/", "<?php \\1++; ?>", content );
        let content = preg_replace ( "/<(.+?)\-\->/", "<?php \\1--; ?>", content );
        let content = preg_replace ( "/<loop\s+(\S+)\s+(\S+)>/", "<?php \$n=1;if(isset(\\1) && (is_array(\\1) || is_object(\\1))) foreach(\\1 AS \\2) { ?>", content );
        let content = preg_replace ( "/<loop\s+(\S+)\s+(\S+)\s+(\S+)>/", "<?php \$n=1; if(is_array(\\1) || is_object(\\1)) foreach(\\1 AS \\2 => \\3) { ?>", content );
        let content = preg_replace ( "/<foreach\s+(\S+)\s+(\S+)>/", "<?php \$n=1;if(isset(\\1) && (is_array(\\1) || is_object(\\1))) foreach(\\1 AS \\2) { ?>", content );
        let content = preg_replace ( "/<foreach\s+(\S+)\s+(\S+)\s+(\S+)>/", "<?php \$n=1; if(isset(\\1) && (is_array(\\1) || is_object(\\1))) foreach(\\1 AS \\2 => \\3) { ?>", content );
        let content = preg_replace ( "/<\/loop>/", "<?php \$n++;} unset(\$n); ?>", content );
        let content = preg_replace ( "/<\/foreach>/", "<?php \$n++;} unset(\$n); ?>", content );
        let content = preg_replace_callback("/\{\\$(\S+)\|(\S+)=(.+)\}/","\\Aimo\\View::fixfunction", content);
        let content = preg_replace ( "/\{([a-zA-Z_\-\>\.\x7f-\xff][a-zA-Z0-9_\-\>\.\x7f-\xff:]*\(([^\{\}]*)\))\}/", "<?php echo \\1;?>", content );
        let content = preg_replace ( "/\{\\$([a-zA-Z_\-\>\x7f-\xff][a-zA-Z0-9_\-\>\x7f-\xff:]*\(([^\{\}]*)\))\}/", "<?php echo \\1;?>", content );
        let content = preg_replace ( "/\{(\\$[a-zA-Z_\-\>\x7f-\xff][a-zA-Z0-9_\-\>\x7f-\xff]*)\}/", "<?php echo \\1;?>", content );
        let content = preg_replace_callback ( "/\{(\\$[a-zA-Z0-9_\-\>\[\]\'\"\$\x7f-\xff]+)\}/s","\\Aimo\\View::addquote",content );
        let content = preg_replace_callback( "/\{(\\$[a-zA-Z0-9_\.\'\"\$\x7f-\xff]+)\}/s","\\Aimo\\View::fixvar",content );
        let content = preg_replace( "/\{([A-Z_\x7f-\xff][A-Z0-9_\x7f-\xff]*)\}/s", "<?php echo \\1;?>", content );
        let content = preg_replace_callback( "/<".self::_namespace.":(\w+)\s+([^>]+)>/i","\\Aimo\\View::tag", content );
        let content = preg_replace( "/<\/".self::_namespace.">/i", "<?php } ?>", content );
        let content = "<?php defined('InAimo') or exit('Access Denied!');?>\r\n".content;
        return content;
    }

    /**
     * 注册数据变量到视图作用域
     *
     * 注册数据变量到视图作用域
     *
     * @access public
     * @param string key 数据键名
     * @param mixed value 数据
     * @return void
     *
     * <code>
     * \Aimo\View::assign('name','eric');
     * </code>
     */
    public static function assign(string key, value) -> void
    {
        let self::_data[key] = value;
    }

    /**
     * 渲染视图
     *
     * 渲染视图
     *
     * @access public
     * @param string tplPath 模板名
     * @param array data 数据
     * @return void
     
     * <code>
     * \Aimo\View::render('news/list',[
     *      'news' => [['title'=>'title','content'=>'content']]
     * ]);
     * </code>
     */
    public static function render(string tplPath, array data = []) -> void
    {
        var k,v;
        if !empty(data) {
            for k,v in data {
                let self::_data[k]=v;
            }
        }
        extract(self::_data);
        require self::load(tplPath);
    }

    /**
     * 转义 // 为 /
     *
     * @param array $m
     * @return 转义后的字符
     */
    public static function addquote(array m) -> string
    {
        var str;
        let str = m[1];
        return str_replace ( "\\\"", "\"", preg_replace ( "/\[([a-zA-Z0-9_\-\.\x7f-\xff]+)\]/s", "['\\1']", str ) );
    }
    
    /**
     * 修复语法特殊用法
     */
    public static function fixvar(array m) -> string
    {
        var str;
        let str = m[1];
        let str = preg_replace("/(\.)(\w+)/i","['\\2']", str);
        return "<?php echo ".str.";?>";
    }
    
    /**
     * 解析function标签
     * @param array $m 语法元素
     */
     
    public static function fixfunction(array m) -> string
    {
        var obj,func,args,str;
        let obj  = "$".m[1],func=m[2],args=m[3];
        let str  = preg_replace("/(\.|->)(\w+)/i","['\\2']", obj);
        let args = str_replace("this", str, args);
        return sprintf("<?php echo %s(%s);?>", func, args);
    }
    
    /**
     * 解析标签Taglib
     *
     * @param array $m 语法元素
     * @return string
     */
    public static function tag(array m) -> string
    {
        var op,data,html;
        let op = m[1],data=m[2],html=m[0];
        array arr,attr,datas,matches;
        string str,tag_id,action,name;
        var v,v1,num;
        int i;
        preg_match_all( "/([a-z]+)\=[\"]?([^\"]+)[\"]?/i", stripslashes ( data ), matches, PREG_SET_ORDER );
        let arr    = ["action", "num", "ttl", "name"];
        let attr   = ["action":"","num":20,"ttl":0,"name":""];
        let datas  = [];
        let tag_id = md5(stripslashes( html ));
        int c = count(matches);
        let c--;
        
        for i in range(0, c) {
            let v = matches[i];
            let v1 = v[1];
            if in_array(v1, arr) {
                let attr[v1]=v[2];
                continue;
            }
            let datas[v1] = v[2];
        }

        let num    = isset(attr["num"]) ? intval(attr["num"]) : 20;
        let name   = isset(attr["name"]) ? trim(attr["name"]) : "data";
        let action = isset(attr["action"]) ? trim(attr["action"]) : "";
        if  empty ( action ) {
            return "";
        }

        let str.= " $".op."_tag = \\Cinso\\Tags::get('" . op . "'); ";
        let str.= " if (method_exists($" . op . "_tag, '" . action . "')) {";
        let str.= " $" . name . " = $" . op . "_tag->" . action . "(" . self::arr_to_html ( datas ) . ");";

        return "<?php " .str . "?>";
    }
    
    /**
     * 标签结束
     */
    private static function end_tag()->string
    {
        return "<?php } ?>";
    }
    
    /**
     * 转换数据为HTML代码
     * @param array data 数组
     */
    private static function arr_to_html(array data)->string
    {
        string str;
        var key,val;
        let str = "[";
        for key,val in data {
            if is_array( val ) {
                let str .= "'".key."'=>" . self::arr_to_html ( val ) . ",";
            } else {
                if strpos(val, '$' ) === 0 {
                    let str .= "'".key."'=>".val.",";
                } else {
                    let str .= "'".key."'=>'".addslashes( val ) . "',";
                }
            }
        }
        return str."]";
    }
}
