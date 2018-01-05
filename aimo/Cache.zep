namespace Aimo;
/**
 * A simple Cache Factory
 *
 * A Cache Factory can manage more instance in runtime
 *
 * @package Aimo
 * @author <Eric,fonqing@qq.com>
 */
abstract class Cache {
    /**
     * @var array cache instances;
     */
    protected static _instance = [];

	/**
	 * 缓存工厂
     *
     * <code>
     * Cache::init('Memcache', [
     *     'host' => '127.0.0.1',
     *     'port' => '11211',
     * ],'dbCache');
     * //or
     * Cache::init('File', [
     *     'cache_path' => './runtime/',
     *     'cache_ttl' => 1800,         //默认缓存时间
     *     'cache_path_level' => 3,     //缓存目录深度
     *     'cache_subdir' => true,      //启用子目录
     *     'cache_check' => false,      //是否开启数据校检，开启后影响性能，默认关闭
     *     'cache_compress' => false,   //是否开启数据压缩，开启后影响性能，默认关闭
     * ],'htmlCache');
     * </code>
	 *
	 * @param string driver
	 * @param mixed config
     * @param string name
	 * @return Aimo\Cache\CacheInterface
	 */
	public static function init(string! driver,array config=[],string key="default")
	{
		if !isset self::_instance[key] {
			string klass;
            let driver = ucfirst(driver);
			let klass = "Aimo\\Cache\\".driver;
            if !class_exists(klass){
                throw "Cache Driver:".klass."dose not exists!";
            }
			let self::_instance[key] = new {klass}(config);
		}
		return self::_instance[key];
	}

    /**
     * 使用名称获取缓存实例 
     *
     *<code>
     *$htmlCache = Cache::get('htmlCache');
     *</code>
     *
     * @param string 实例名称
     * @return string
     */
    public static function getInstance(string! name)
    {
        if isset self::_instance[name] {
            return self::_instance[name];
        }
        throw "Cache Instance '".name."' not exists";
    }

    /**
     * Generate GUID string 
     *
     * @param array
     * @return string
     */
    private static function guid(array param)->string
    {
        return md5(serialize(param));
    }
}
