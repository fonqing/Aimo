namespace Aimo;
/**
 * 视图类
 *
 * 包含模板语法与编译，视图模板缓存
 *<code>
 *Template syntax:
 * Variable output: {$name} {$data[name]} {$data.name} {$data->name} {PHP_VERSION}
 * Call global function: {print_r($data)}
 * Loop: {loop $items $item} {/loop} 
 *       {loop $items $k $item} {/loop}
 *       {foreach $items $item} {/foreach}
 *       {foreach $items $k $item} {/foreach}
 * For:  {for $i=0;$i<10;$i++} {/for}
 * Subtemplate: {template "index/public/header"}
 * Include: {include "vars.php"}
 * Taglib: 
 * {Aimo::news action="getlist" name="infos" ttl="3600"}
 *   {loop $infos $info} 
 *   {/loop} 
 * {/Aimo}
 * Condition:
 * {if isset($var)}
 * {elseif isset($var2)}
 * {else}
 * {/if}
 * OriPHP:
 * {php}{/php}
 *</code>
 *
 * @package Aimo
 * @author Eric,<fonqing@gmail.com>
 */
class View {
    /**
     * @var array 配置
     */
    private static _config = [];

    /**
     * @var string Taglib namespace
     */
    public static _namespace = "Aimo";

    /**
     * @var array 待解析变量
     */
    private static _data = [];

    /**
     * 引擎初始化
     *
     * 初始化模板引擎
     *
     * <code>
     * \Aimo\View::init([
     *      'view_path'       => './_view/',  //模板文件目录
     *      'view_cache_path' => './_cache/', //模板编译缓存目录
     *      'view_file_ext'   => '.html',     //模板文件扩展名
     *      'delimiter_begin' => '{',         //模板标记开始定界符
     *      'delimiter_end'   => '}'          //模板标记结束定界符
     * ]);
     * </code>
     *<code>
     *
     *Template syntax:
     * Variable output: {$name} {$data[name]} {$data.name} {$data->name} {PHP_VERSION}
     * Call global function: {print_r($data)}
     * Loop: {loop $items $item} {/loop} 
     *       {loop $items $k $item} {/loop}
     *       {foreach $items $item} {/foreach}
     *       {foreach $items $k $item} {/foreach}
     * For:  {for $i=0;$i<10;$i++} {/for}
     * Subtemplate: {template "index/public/header"}
     * Include: {include "vars.php"}
     * Taglib: 
     * {Aimo::news action="getlist" name="infos" ttl="3600"}
     *   {loop $infos $info} 
     *   {/loop} 
     * {/Aimo}
     * Condition:
     * {if isset($var)}
     * {elseif isset($var2)}
     * {else}
     * {/if}
     * OriPHP:
     * {php}{/php}
     *</code>
     *
     * @access public
     * @param array config 视图配置
     */
    public static function init(array! config) -> void
    {
        if typeof config != "array" {
            throw "View::init invalid params";
        }
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
     * <code>
     * \Aimo\View::load('news/view');//默认module/controller/action
     * \Aimo\View::load('admin/news/view');//module/controller/action
     * </code>
     *
     * @access public
     * @param string mca 视图描述
     * @return string
     */
    public static function load(string mca) -> string
    {
        string viewPath,cachePath,viewExt,tplfile,compiledtplfile,tmp,content;
        var tmpa;

        let viewPath  = isset self::_config["view_path"]       ? rtrim(self::_config["view_path"], "/\\") : "";
        let cachePath = isset self::_config["view_cache_path"] ? rtrim(self::_config["view_cache_path"], "/\\") : "";
        let viewExt   = isset self::_config["view_file_ext"]   ? ltrim(self::_config["view_file_ext"], '.') : "html";
        let mca       = (string) preg_replace("/[\\/]+/","/", trim(mca,"\\/"));
        let tmpa      = explode("/", mca);
        let tmp       = implode("_", tmpa);
        let tplfile   = viewPath ."/". mca . "." . viewExt;
        let compiledtplfile = cachePath."/".tmp.".php";
        if self::check(tplfile, compiledtplfile) {
            return compiledtplfile;
        }
        
        if !file_exists(tplfile) {
            throw "View file ".htmlspecialchars(tplfile)." dose't exists";
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
        var db,de;
        let db = (isset self::_config["delimiter_begin"]) ? self::_config["delimiter_begin"] : "{";
        let de = (isset self::_config["delimiter_end"])   ? self::_config["delimiter_end"]   : "}";

        let content = preg_replace ( "/".db."template\s+(.+)".de."/", "<?php include \\Aimo\\View::load(\\1); ?>", content );
        let content = preg_replace ( "/".db."include\s+(.+)".de."/", "<?php include \\1; ?>", content );
        let content = preg_replace ( "/".db."php\s+(.+)".de."/", "<?php \\1?>", content );
        let content = preg_replace ( "/".db."if\s+(.+?)".de."/", "<?php if(\\1) { ?>", content );
        let content = preg_replace ( "/".db."else".de."/", "<?php } else { ?>", content );
        let content = preg_replace ( "/".db."elseif\s+(.+?)".de."/", "<?php } elseif (\\1) { ?>", content );
        let content = preg_replace ( "/".db."\/if".de."/", "<?php } ?>", content );
        let content = preg_replace ( "/".db."for\s+(.+?)".de."/", "<?php for(\\1) { ?>", content );
        let content = preg_replace ( "/".db."\/for".de."/", "<?php } ?>", content );
        let content = preg_replace ( "/".db."\+\+(.+?)".de."/", "<?php ++\\1; ?>", content );
        let content = preg_replace ( "/".db."\-\-(.+?)".de."/", "<?php ++\\1; ?>", content );
        let content = preg_replace ( "/".db."(.+?)\+\+".de."/", "<?php \\1++; ?>", content );
        let content = preg_replace ( "/".db."(.+?)\-\-".de."/", "<?php \\1--; ?>", content );
        let content = preg_replace ( "/".db."loop\s+(\S+)\s+(\S+)".de."/", "<?php \$n=1;if(isset(\\1) && (is_array(\\1) || is_object(\\1))) foreach(\\1 AS \\2) { ?>", content );
        let content = preg_replace ( "/".db."loop\s+(\S+)\s+(\S+)\s+(\S+)".de."/", "<?php \$n=1; if(is_array(\\1) || is_object(\\1)) foreach(\\1 AS \\2 => \\3) { ?>", content );
        let content = preg_replace ( "/".db."foreach\s+(\S+)\s+(\S+)".de."/", "<?php \$n=1;if(isset(\\1) && (is_array(\\1) || is_object(\\1))) foreach(\\1 AS \\2) { ?>", content );
        let content = preg_replace ( "/".db."foreach\s+(\S+)\s+(\S+)\s+(\S+)".de."/", "<?php \$n=1; if(isset(\\1) && (is_array(\\1) || is_object(\\1))) foreach(\\1 AS \\2 => \\3) { ?>", content );
        let content = preg_replace ( "/".db."\/loop".de."/", "<?php \$n++;} unset(\$n); ?>", content );
        let content = preg_replace ( "/".db."\/foreach".de."/", "<?php \$n++;} unset(\$n); ?>", content );
        let content = preg_replace_callback("/".db."\\$(\S+)\|(\S+)=(.+)".de."/","\\Aimo\\View::fixfunction", content);
        let content = preg_replace ( "/".db."([a-zA-Z_\-\>\.\x7f-\xff][a-zA-Z0-9_\-\>\.\x7f-\xff:]*\(([^\{\}]*)\))".de."/", "<?php echo \\1;?>", content );
        let content = preg_replace ( "/".db."\\$([a-zA-Z_\-\>\x7f-\xff][a-zA-Z0-9_\-\>\x7f-\xff:]*\(([^\{\}]*)\))".de."/", "<?php echo \\1;?>", content );
        let content = preg_replace ( "/".db."(\\$[a-zA-Z_\-\>\x7f-\xff][a-zA-Z0-9_\-\>\x7f-\xff]*)".de."/", "<?php echo \\1;?>", content );
        let content = preg_replace_callback ( "/".db."(\\$[a-zA-Z0-9_\-\>\[\]\'\"\$\x7f-\xff]+)".de."/s","\\Aimo\\View::addquote",content );
        let content = preg_replace_callback( "/".db."(\\$[a-zA-Z0-9_\.\'\"\$\x7f-\xff]+)".de."/s","\\Aimo\\View::fixvar",content );
        let content = preg_replace( "/".db."([A-Z_\x7f-\xff][A-Z0-9_\x7f-\xff]*)".de."/s", "<?php echo \\1;?>", content );
        let content = preg_replace_callback( "/".db."".self::_namespace.":(\w+)\s+([^>]+)".de."/i","\\Aimo\\View::tag", content );
        let content = preg_replace( "/".db."\/".self::_namespace."".de."/i", "<?php } ?>", content );
        //let content = "<?php defined('InAimo') or exit('Access Denied!');?>\r\n".content;
        return content;
    }

    /**
     * 注册数据变量到视图作用域
     *
     * <code>
     * \Aimo\View::assign('name','eric');
     * </code>
     *
     * @access public
     * @param string key 数据键名
     * @param mixed value 数据
     * @return void
     */
    public static function assign(string key, value) -> void
    {
        let self::_data[key] = value;
    }

    /**
     * 渲染视图
     *
     * <code>
     * \Aimo\View::render('news/list',[
     *      'news' => [['title'=>'title','content'=>'content']]
     * ]);
     * </code>
     *
     * @access public
     * @param string tplPath 模板名
     * @param array data 数据
     * @param callable func
     * @return void
     */
    public static function render(string! tplPath="", array! data = []) -> void
    {
        var app,isMultipleModule;
        if empty tplPath{
            let app = Application::_instance;
            let isMultipleModule = app->multipleModule;
            if !!isMultipleModule {
                let tplPath = app->getModuleName()."/".app->getControllerName()."/".app->getActionName();
            } else {
                let tplPath = app->getControllerName()."/".app->getActionName();
            }
        }
        //if func != null {
        //    ob_start(func);
        //}
        var k,v;//,content;
        if !empty data {
            for k,v in data {
                let self::_data[k]=v;
            }
        }
        extract(self::_data);
        require self::load(tplPath);
        //if func != null {
        //    ob_get_flush();
        //}
    }

    /**
     * 转义 // 为 /
     *
     * @param array m
     * @return string 转义后的字符
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
     * @param array m 语法元素
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
     * @param array m 语法元素
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

        let num    = isset attr["num"]    ? intval(attr["num"])  : 20;
        let name   = isset attr["name"]   ? trim(attr["name"])   : "data";
        let action = isset attr["action"] ? trim(attr["action"]) : "";
        if empty action {
            return "";
        }

        let str.= " $".op."_tag = \\Aimo\\Tags::get('" . op . "'); ";
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
     *
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
