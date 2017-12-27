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
	 * Factory
	 *
	 * @param string driver
	 * @param mixed config
	 * @return Aimo\Cache\CacheInterface
	 */
	public static function init(string! driver,array config)
	{
        var key;
        let key = self::guid(func_get_args());
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
