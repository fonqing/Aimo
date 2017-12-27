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
     * 存储配置信息
     *
     * @param string name 设置项名称
     * @param mixed value 设置值
     * @return void
     *
     * <code>
     * Config::set('debug',true);
     * </code>
     */
    public static function set(string! name, value)->void
    {
        let self::_data[name]=value;
    }

    /**
     * Get config
     *
     * @param string name 设置项名称
     * @return mixed
     */
    public static function get(string! name)
    {
        if isset self::_data[name] {
            return self::_data[name];
        }
        return null;
    }

    /**
     * 删除配置项
     *
     * @param string name 设置项名称
     */
    public static function delete(string! name)->void
    {
        unset(self::_data[name]);
    }

    /**
     * 清空所有设置
     */
    public static function clear()->void
    {
        let self::_data = [];
    }

}