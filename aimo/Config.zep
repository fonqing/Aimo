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
        var k,v;
        for k,v in config {
            self::set(k, v);
        }
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
     * $dbUsername = Config::get('db.username');
     * </code>
     *
     * @param string name 设置项名称
     * @return mixed
     */
    public static function get(string! name)
    {
        let name = name->trim(".");
        if name->index(".") !== false {
            var parts,k1,k2;
            let parts = explode(".",name);
            let k1    = isset parts[0] ? parts[0] : "";
            let k2    = isset parts[1] ? parts[1] : "";
            if empty k1 || empty k2 {
                return null;
            }
            if isset self::_data[k1] {
                if isset self::_data[k1][k2] {
                    return self::_data[k1][k2];
                }
            }
        } else {
            if isset self::_data[name] {
                return self::_data[name];
            }
        }
        return null;
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