namespace Aimo\Cache;
use Aimo\Cache;
class Memcache extends Cache implements CacheInterface {
    /**
     * @var resource Memcache instance
     */
    private memcache;

    /**
     * @var boolean 是否连接
     */
    protected connected = false;

    /**
     * 构造函数
     *
     * <code>
     * $cache = new Aimo\Cache\Memcache([
     *     'host' => '127.0.0.1',
     *     'port' => '11211',
     * ]);
     * </code>
     *
     * @param array config
     */
    public function __construct(array! config)
    {
        if !extension_loaded("Memcache") {
            throw "Memcache extension required";
        }
        let this->memcache = new \Memcache();
        let this->connected = this->memcache->connect(config["host"], config["port"]);
    }

    /**
     * 获取缓存驱动连接状态
     *
     * <code>
     * $cache = new Aimo\Cache\Memcache([
     *     'host' => '127.0.0.1',
     *     'port' => '11211',
     * ]);
     * var_dump($cache->isConnected());
     * </code>
     */
    public function isConnected()
    {
        return this->connected;
    }

    /**
     * 从缓存读取数据
     *
     * <code>
     * $cache = new Aimo\Cache\Memcache([
     *     'host' => '127.0.0.1',
     *     'port' => '11211',
     * ]);
     * var_dump($cache->get('data'));
     * </code>
     *
     * @param string name
     * @return mixed
     */
    public function get(string! name)
    {
        return this->memcache->get(name);
    }

    /**
     * 向缓存写入数据
     *
     * <code>
     * $cache = new Aimo\Cache\Memcache([
     *     'host' => '127.0.0.1',
     *     'port' => '11211',
     * ]);
     * $cache->set('data',$data,1800);
     * </code>
     *
     * @param string name
     * @param mixed data
     * @param int ttl 
     */
    public function set(string! name, data, ttl = null)
    {
         return this->memcache->set(name, data, 0, ttl);
    }

    /**
     * 从缓存删除数据
     *
     * <code>
     * $cache = new Aimo\Cache\Memcache([
     *     'host' => '127.0.0.1',
     *     'port' => '11211',
     * ]);
     * $cache->delete('data');
     * </code>
     *
     * @param string name
     */
    public function delete(string! name)
    {
        return this->memcache->delete(name);
    }

    /**
     * 清空实例中所有缓存数据
     *
     * <code>
     * $cache = new Aimo\Cache\Memcache([
     *     'host' => '127.0.0.1',
     *     'port' => '11211',
     * ]);
     * $cache->clear();
     * </code>
     */
    public function clear()
    {
        return this->memcache->flush();
    }

}