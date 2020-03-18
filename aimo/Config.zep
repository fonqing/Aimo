namespace Aimo;
/**
 * 应用设置操作类
 *
 * 用于运行时存取设置项目
 *
 * @package Aimo
 *
 */
class Config {
    /**
     * @var array 
     */
    private static _data;

    /**
     * 批量装载配置
     *
     * <code>
     * Config::init([
            'debug' => true,
            'db' => [
                'dirver' => 'mysql'
            ],
            'view' => [
                'cache' => true
            ]
     * ]);
     * </code>
     *
     * @param string name 设置项名称
     * @param mixed value 设置值
     * @return void
     */
    public static function init(array! config)->void
    {
        let self::_data = config;
    }
    
    /**
     * Load configuration from a file
     * 
     * Support php file and ini file
     * 
     * <code>
     * $config = Config::load('config.php');
     * //or
     * $config = Config::load('config.ini');
     * </code>
     * 
     * @param string $file  Configuration file
     * @return array
     */
    public static function load(string! file)//->array
    {
        var ext,data;
        if file_exists(file) {
            let ext = strtolower(pathinfo(file, PATHINFO_EXTENSION));
            if "php" == ext {
                let data = require(file);
            } elseif "ini" == ext {
                let data = parse_ini_file(file, true);
            }else{
                let data = [];
            }
            if !is_array(data) {
                return [];
            }
            if !empty(data) {
                let self::_data = data;
                return data;
            }
        }
        return [];
    }

    /**
     * 存储设置
     *
     * <code>
     * Config::set('debug',true);
     * </code>
     *
     * @param string name 设置项名称
     * @param mixed value 设置值
     * @return void
     */
    public static function set(string! name, value)->void
    {
        let self::_data[name]=value;
    }

    /**
     * Get config
     *
     * <code>
     * $dbConfig   = Config::get('db');
     * $dbUsername = Config::get('db.username','default');
     * </code>
     *
     * @param string name 设置项名称
     * @return mixed
     */
    public static function get(string! name, default)
    {
        var configs;
        let name = name->trim(".");
        if name->index(".") !== false {
            var parts,k1,k2;
            let parts = explode(".",name);
            let configs = self::_data;
            for part in parts {
                if isset configs[part] {
                    let configs = configs[part];
                } else {
                    return is_null(default) ? null : default;
                }
            }
            return configs;
        } else {
            if isset self::_data[name] {
                return self::_data[name];
            } else {
                return is_null(default) ? null : default;
            }
        }
        return null;
    }
    
     /**
     * Get a config item if exists and Execute the callback function
     *
     * <code>
     * Config::fetch('name', function($value){
     *      echo "`name` exists and value is {$value} ";
     * });
     * </code>
     *
     * @param string $name
     * @param callable $callback
     * 
     * @return mixed
     */
    public static function fetch(string! name, callable callback)
    {
        var value;
        let value = self::get(name);
        if !is_null(value) {
            return call_user_func(callback, value);
        }
    }

    /**
     * 删除配置项
     *
     * <code>
     * Config::delete('cache');
     * </code>
     *
     * @param string name 设置项名称
     */
    public static function delete(string! name)->void
    {
        if isset self::_data[name] {
            unset(self::_data[name]);
        }
    }

    /**
     * 清空所有设置
     *
     **<code>
     * Config::clear();
     * </code>
     */
    public static function clear()->void
    {
        let self::_data = [];
    }

}
