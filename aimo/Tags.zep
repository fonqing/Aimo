namespace Aimo;
class Tags {
    protected static _instance = [];
    protected static _config   = [];
    public static function init(array config)
    {
        if isset config["tag_dir"] {
            let self::_config["tag_dir"] = rtrim(config["tag_dir"],"\\/")."/";
        }else{
            throw new \Exception("Tag dir must config");
        }
    }
    public static function get(string klass)
    {
        require self::_config["tag_dir"].klass.".php";
        if !isset(self::_instance[klass]) {
            let self::_instance[klass] = new {klass}();
        }
        return self::_instance[klass];
    }
}