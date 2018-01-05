namespace Aimo;
class Tags {
    /**
     * 标签实例列表
     * @var array
     */
    protected static _instance = [];
    /**
     * 配置
     * @var array
     */
    protected static _config   = [];

    /**
     * 初始化标签组件
     * 
     *<code>
     *Tags::init([
     *    'tag_dir' => '',//标签库定义地址
     *]);
     *</code>
     */
    public static function init(array config)
    {
        if isset config["tag_dir"] {
            let self::_config["tag_dir"] = rtrim(config["tag_dir"],"\\/")."/";
        }else{
            throw "Tag dir must set";
        }
    }

    /**
     * 载入指定的标签库
     * 
     *<code>
     *$tag = Tags::get('news');
     *</code>
     */
    public static function get(string klass)
    {
        require self::_config["tag_dir"].klass.".php";
        if !isset(self::_instance[klass]) {
            let self::_instance[klass] = new {klass}();
        }
        return self::_instance[klass];
    }
}