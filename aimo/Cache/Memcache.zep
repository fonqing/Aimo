namespace Aimo\Cache;
use Aimo\Cache;
class Memcache extends Cache implements CacheInterface {
    private memcache;
    protected connected = false;
    public function __construct(array config){
        if !extension_loaded("Memcache") {
            throw "Memcache extension required";
        }
        let this->memcache = new \Memcache();
        let this->connected = this->memcache->connect(config["host"], config["port"]);
    }

    public function isConnected()
    {
        return this->connected;
    }

    public function get(string! name){
        return this->memcache->get(name);
    }

    public function set(string! name, data, ttl = null){
         return this->memcache->set(name, data, 0, ttl);
    }

    public function delete(string! name){
        return this->memcache->delete(name);
    }

    public function clear()
    {
        return this->memcache->flush();
    }

}