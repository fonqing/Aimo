namespace Aimo;
class Cache {
	/**
	 * @var Cinso\Cache\CacheInterface;
	 */
	protected static _instance;

	/**
	 * Factory
	 *
	 * @param string driver
	 * @param mixed config
	 * @return Cinso\Cache\CacheInterface
	 */
	public static function init(string driver,config)
	{
		if self::_instance === null {
			string klass;
			let klass = "Cinso\\Cache\\".driver;
			let self::_instance = new {klass}(config);
		}
		return self::_instance;
	}
}