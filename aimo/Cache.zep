namespace Aimo;
class Cache {
	/**
	 * @var Aimo\Cache\CacheInterface;
	 */
	protected static _instance;

	/**
	 * Factory
	 *
	 * @param string driver
	 * @param mixed config
	 * @return Aimo\Cache\CacheInterface
	 */
	public static function init(string driver,config)
	{
		if self::_instance === null {
			string klass;
			let klass = "Aimo\\Cache\\".driver;
			let self::_instance = new {klass}(config);
		}
		return self::_instance;
	}
}